#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <string>
#include <vector>

namespace rag {

struct GbaRomHeader {
    std::string title;
    std::string game_code;
    std::string maker_code;
    std::uint8_t fixed_value{};
    std::uint8_t version{};
    std::uint8_t stored_checksum{};
    std::uint8_t computed_checksum{};
    std::uint32_t entry_instruction{};
    std::uint32_t entry_branch_target{};
    bool entry_is_branch{};

    [[nodiscard]] bool checksum_valid() const noexcept {
        return stored_checksum == computed_checksum;
    }
};

[[nodiscard]] std::vector<std::uint8_t> load_rom(const std::filesystem::path& path);
[[nodiscard]] GbaRomHeader parse_gba_header(std::span<const std::uint8_t> rom);
[[nodiscard]] std::uint32_t read_u32_le(std::span<const std::uint8_t> bytes, std::size_t offset);
[[nodiscard]] bool is_arm_branch(std::uint32_t instruction) noexcept;
[[nodiscard]] std::uint32_t arm_branch_target(std::uint32_t instruction, std::uint32_t instruction_address) noexcept;

} // namespace rag
