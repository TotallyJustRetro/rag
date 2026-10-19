#include "rag/arm7tdmi.hpp"
#include "rag/gba_rom.hpp"

#include <array>
#include <cstdint>
#include <exception>
#include <iostream>
#include <span>
#include <string>

namespace {
int failures = 0;

void check(bool condition, const char* name) {
    if (!condition) {
        std::cerr << "FAIL: " << name << '\n';
        ++failures;
    }
}

void write_u32_le(std::span<std::uint8_t> bytes, std::size_t offset, std::uint32_t value) {
    bytes[offset] = static_cast<std::uint8_t>(value);
    bytes[offset + 1] = static_cast<std::uint8_t>(value >> 8);
    bytes[offset + 2] = static_cast<std::uint8_t>(value >> 16);
    bytes[offset + 3] = static_cast<std::uint8_t>(value >> 24);
}

void test_gba_header() {
    std::array<std::uint8_t, 0xC0> bytes{};
    write_u32_le(bytes, 0, 0xEA00002Eu); // branch from 0x08000000 to 0x080000C0
    const char title[] = "TEST GAME";
    for (std::size_t i = 0; i < sizeof(title) - 1; ++i) bytes[0xA0 + i] = static_cast<std::uint8_t>(title[i]);
    bytes[0xAC] = 'T'; bytes[0xAD] = 'E'; bytes[0xAE] = 'S'; bytes[0xAF] = 'T';
    bytes[0xB0] = '0'; bytes[0xB1] = '1';
    bytes[0xB2] = 0x96;
    bytes[0xBC] = 0;
    unsigned sum = 0;
    for (std::size_t i = 0xA0; i <= 0xBC; ++i) sum += bytes[i];
    bytes[0xBD] = static_cast<std::uint8_t>((0x100u - ((sum + 0x19u) & 0xFFu)) & 0xFFu);

    const auto header = rag::parse_gba_header(bytes);
    check(header.title == "TEST GAME", "header title");
    check(header.game_code == "TEST", "header game code");
    check(header.maker_code == "01", "header maker code");
    check(header.checksum_valid(), "header checksum");
    check(header.entry_is_branch, "entry detected as branch");
    check(header.entry_branch_target == 0x080000C0u, "entry branch target");
}

void test_arm_decode() {
    const auto branch = rag::decode_arm(0xEA00002Eu, 0x08000000u);
    check(branch.kind == rag::ArmInstructionKind::Branch, "ARM B classification");
    check(branch.branch_target && *branch.branch_target == 0x080000C0u, "ARM B target");

    const auto branch_link = rag::decode_arm(0xEB000001u, 0x08000100u);
    check(branch_link.kind == rag::ArmInstructionKind::BranchLink, "ARM BL classification");
    check(branch_link.branch_target && *branch_link.branch_target == 0x0800010Cu, "ARM BL target");

    const auto bx_lr = rag::decode_arm(0xE12FFF1Eu, 0x080000C0u);
    check(bx_lr.kind == rag::ArmInstructionKind::BranchExchange, "BX LR classification");

    const auto mov_r0_r0 = rag::decode_arm(0xE1A00000u, 0x080000C4u);
    check(mov_r0_r0.kind == rag::ArmInstructionKind::DataProcessing, "data processing classification");
}

void test_bounds() {
    bool threw = false;
    try {
        const std::array<std::uint8_t, 3> bytes{};
        (void)rag::read_u32_le(bytes, 0);
    } catch (const std::out_of_range&) {
        threw = true;
    }
    check(threw, "little-endian read bounds checking");
}
} // namespace

int main() {
    test_gba_header();
    test_arm_decode();
    test_bounds();
    if (failures != 0) {
        std::cerr << failures << " test(s) failed\n";
        return 1;
    }
    std::cout << "All RAG core tests passed.\n";
    return 0;
}
