#include "rag/gba_rom.hpp"

#include <fstream>
#include <iterator>
#include <stdexcept>

namespace rag {
namespace {

std::string read_ascii_field(std::span<const std::uint8_t> rom, std::size_t offset, std::size_t length) {
    std::string result;
    result.reserve(length);
    for (std::size_t i = 0; i < length; ++i) {
        const char ch = static_cast<char>(rom[offset + i]);
        if (ch == '\0') break;
        result.push_back(ch);
    }
    while (!result.empty() && result.back() == ' ') result.pop_back();
    return result;
}

std::uint8_t calculate_header_checksum(std::span<const std::uint8_t> rom) {
    unsigned sum = 0;
    for (std::size_t i = 0xA0; i <= 0xBC; ++i) sum += rom[i];
    return static_cast<std::uint8_t>((0x100u - ((sum + 0x19u) & 0xFFu)) & 0xFFu);
}

} // namespace

std::vector<std::uint8_t> load_rom(const std::filesystem::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) throw std::runtime_error("could not open ROM file: " + path.string());

    std::vector<std::uint8_t> bytes;
    for (std::istreambuf_iterator<char> it(input), end; it != end; ++it) {
        bytes.push_back(static_cast<std::uint8_t>(static_cast<unsigned char>(*it)));
    }
    if (input.bad()) throw std::runtime_error("error while reading ROM file: " + path.string());
    return bytes;
}

std::uint32_t read_u32_le(std::span<const std::uint8_t> bytes, std::size_t offset) {
    if (offset > bytes.size() || bytes.size() - offset < 4) {
        throw std::out_of_range("read_u32_le: offset is outside the byte buffer");
    }
    return static_cast<std::uint32_t>(bytes[offset])
        | (static_cast<std::uint32_t>(bytes[offset + 1]) << 8)
        | (static_cast<std::uint32_t>(bytes[offset + 2]) << 16)
        | (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
}

bool is_arm_branch(std::uint32_t instruction) noexcept {
    // ARM B/BL: bits 27..25 are 101. Condition bits are intentionally ignored here.
    return (instruction & 0x0E000000u) == 0x0A000000u;
}

std::uint32_t arm_branch_target(std::uint32_t instruction, std::uint32_t instruction_address) noexcept {
    std::int32_t immediate = static_cast<std::int32_t>(instruction & 0x00FFFFFFu);
    if ((immediate & 0x00800000) != 0) immediate -= 0x01000000;
    // ARM PC reads as the address of this instruction plus 8 bytes.
    const auto displacement = static_cast<std::int64_t>(immediate) * 4;
    return static_cast<std::uint32_t>(static_cast<std::int64_t>(instruction_address) + 8 + displacement);
}

GbaRomHeader parse_gba_header(std::span<const std::uint8_t> rom) {
    if (rom.size() < 0xC0) {
        throw std::invalid_argument("file is too small to contain a complete GBA header (need at least 0xC0 bytes)");
    }

    GbaRomHeader header;
    header.entry_instruction = read_u32_le(rom, 0);
    header.entry_is_branch = is_arm_branch(header.entry_instruction);
    if (header.entry_is_branch) header.entry_branch_target = arm_branch_target(header.entry_instruction, 0x08000000u);
    header.title = read_ascii_field(rom, 0xA0, 12);
    header.game_code = read_ascii_field(rom, 0xAC, 4);
    header.maker_code = read_ascii_field(rom, 0xB0, 2);
    header.fixed_value = rom[0xB2];
    header.version = rom[0xBC];
    header.stored_checksum = rom[0xBD];
    header.computed_checksum = calculate_header_checksum(rom);
    return header;
}

} // namespace rag
