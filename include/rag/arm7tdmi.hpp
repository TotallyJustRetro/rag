#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace rag {

enum class ArmInstructionKind {
    Branch,
    BranchLink,
    BranchExchange,
    SoftwareInterrupt,
    DataProcessing,
    SingleDataTransfer,
    BlockDataTransfer,
    Multiply,
    HalfwordTransfer,
    CoprocessorOrOther,
    Unknown,
};

struct DecodedArmInstruction {
    std::uint32_t address{};
    std::uint32_t word{};
    std::uint8_t condition{};
    ArmInstructionKind kind{ArmInstructionKind::Unknown};
    std::optional<std::uint32_t> branch_target;
};

[[nodiscard]] DecodedArmInstruction decode_arm(std::uint32_t word, std::uint32_t address) noexcept;
[[nodiscard]] std::string_view instruction_kind_name(ArmInstructionKind kind) noexcept;

} // namespace rag
