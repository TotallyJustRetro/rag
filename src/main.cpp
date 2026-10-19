#include "rag/arm7tdmi.hpp"
#include "rag/gba_rom.hpp"

#include <cstdlib>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>

namespace {
constexpr std::uint32_t kRomBase = 0x08000000u;

void print_usage() {
    std::cerr << "RAG — GBA static recompilation tools\n"
              << "Usage:\n"
              << "  rag inspect-rom <file.gba>\n"
              << "  rag disassemble-entry <file.gba> [instruction-count]\n";
}

std::uint32_t find_entry_offset(const std::vector<std::uint8_t>& rom, const rag::GbaRomHeader& header) {
    if (header.entry_is_branch && header.entry_branch_target >= kRomBase) {
        const std::uint64_t offset = static_cast<std::uint64_t>(header.entry_branch_target) - kRomBase;
        if (offset < rom.size() && (offset % 4u) == 0u) return static_cast<std::uint32_t>(offset);
    }
    return 0;
}

void inspect_rom(const std::filesystem::path& path) {
    const auto rom = rag::load_rom(path);
    const auto header = rag::parse_gba_header(rom);
    std::cout << "ROM: " << path.string() << '\n'
              << "Size: " << rom.size() << " bytes (" << std::fixed << std::setprecision(2)
              << (static_cast<double>(rom.size()) / (1024.0 * 1024.0)) << " MiB)\n"
              << "Title: " << header.title << '\n'
              << "Game code: " << header.game_code << '\n'
              << "Maker code: " << header.maker_code << '\n'
              << "Fixed header byte: 0x" << std::hex << std::uppercase
              << std::setw(2) << std::setfill('0') << static_cast<unsigned>(header.fixed_value) << '\n'
              << "ROM version: 0x" << std::setw(2) << static_cast<unsigned>(header.version) << '\n'
              << "Entry instruction: 0x" << std::setw(8) << header.entry_instruction << std::dec << '\n';

    if (header.entry_is_branch) {
        std::cout << "Entry branch target: 0x" << std::hex << std::uppercase << std::setw(8)
                  << header.entry_branch_target << std::dec << '\n';
    } else {
        std::cout << "Entry instruction is not recognized as an ARM B/BL branch.\n";
    }
    std::cout << "Header checksum: stored=0x" << std::hex << std::uppercase << std::setw(2)
              << static_cast<unsigned>(header.stored_checksum) << ", computed=0x" << std::setw(2)
              << static_cast<unsigned>(header.computed_checksum) << std::dec << " — "
              << (header.checksum_valid() ? "PASS" : "FAIL") << '\n';
    if (rom.size() == 0) std::cout << "Warning: ROM file is empty.\n";
    if (header.fixed_value != 0x96) std::cout << "Warning: conventional GBA fixed header byte is 0x96.\n";
}

void disassemble_entry(const std::filesystem::path& path, std::size_t count) {
    const auto rom = rag::load_rom(path);
    const auto header = rag::parse_gba_header(rom);
    const std::uint32_t offset = find_entry_offset(rom, header);
    std::cout << "Entry diagnostic (ARM-state classification only; not a full disassembler)\n";
    if (!header.entry_is_branch) std::cout << "Note: no conventional initial ARM branch was recognized; starting at ROM offset 0.\n";

    for (std::size_t i = 0; i < count; ++i) {
        const std::size_t byte_offset = static_cast<std::size_t>(offset) + i * 4;
        if (byte_offset > rom.size() || rom.size() - byte_offset < 4) {
            std::cout << "<end of ROM>\n";
            break;
        }
        const std::uint32_t address = kRomBase + static_cast<std::uint32_t>(byte_offset);
        const auto word = rag::read_u32_le(rom, byte_offset);
        const auto decoded = rag::decode_arm(word, address);
        std::cout << "0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << address
                  << "  " << std::setw(8) << word << "  " << rag::instruction_kind_name(decoded.kind);
        if (decoded.branch_target) std::cout << " -> 0x" << std::setw(8) << *decoded.branch_target;
        std::cout << " (cond=" << std::setw(1) << static_cast<unsigned>(decoded.condition) << ")\n";
    }
    std::cout << std::dec << "\nDecoder note: unknown classifications and undecoded instruction semantics are expected at this stage.\n";
}

} // namespace

int main(int argc, char** argv) {
    if (argc < 3) {
        print_usage();
        return 2;
    }

    try {
        const std::string command = argv[1];
        const std::filesystem::path path = argv[2];
        if (command == "inspect-rom") {
            inspect_rom(path);
            return 0;
        }
        if (command == "disassemble-entry") {
            std::size_t count = 32;
            if (argc >= 4) {
                const long parsed = std::stol(argv[3]);
                if (parsed < 1 || parsed > 4096) throw std::invalid_argument("instruction-count must be between 1 and 4096");
                count = static_cast<std::size_t>(parsed);
            }
            disassemble_entry(path, count);
            return 0;
        }
        print_usage();
        return 2;
    } catch (const std::exception& exception) {
        std::cerr << "rag: error: " << exception.what() << '\n';
        return 1;
    }
}
