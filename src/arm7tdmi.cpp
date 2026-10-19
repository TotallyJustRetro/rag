#include "rag/arm7tdmi.hpp"

#include "rag/gba_rom.hpp"

namespace rag {

DecodedArmInstruction decode_arm(std::uint32_t word, std::uint32_t address) noexcept {
    DecodedArmInstruction decoded;
    decoded.address = address;
    decoded.word = word;
    decoded.condition = static_cast<std::uint8_t>((word >> 28) & 0xFu);

    if ((word & 0x0FFFFFF0u) == 0x012FFF10u) {
        decoded.kind = ArmInstructionKind::BranchExchange;
    } else if ((word & 0x0F000000u) == 0x0F000000u) {
        decoded.kind = ArmInstructionKind::SoftwareInterrupt;
    } else if ((word & 0x0FC000F0u) == 0x00000090u) {
        decoded.kind = ArmInstructionKind::Multiply;
    } else if ((word & 0x0E000090u) == 0x00000090u) {
        decoded.kind = ArmInstructionKind::HalfwordTransfer;
    } else if (is_arm_branch(word)) {
        decoded.kind = (word & 0x01000000u) != 0
            ? ArmInstructionKind::BranchLink
            : ArmInstructionKind::Branch;
        decoded.branch_target = arm_branch_target(word, address);
    } else if ((word & 0x0E000000u) == 0x08000000u) {
        decoded.kind = ArmInstructionKind::BlockDataTransfer;
    } else if ((word & 0x0C000000u) == 0x04000000u) {
        decoded.kind = ArmInstructionKind::SingleDataTransfer;
    } else if ((word & 0x0C000000u) == 0x00000000u) {
        decoded.kind = ArmInstructionKind::DataProcessing;
    } else if ((word & 0x0C000000u) == 0x0C000000u) {
        decoded.kind = ArmInstructionKind::CoprocessorOrOther;
    } else {
        decoded.kind = ArmInstructionKind::Unknown;
    }

    return decoded;
}

std::string_view instruction_kind_name(ArmInstructionKind kind) noexcept {
    switch (kind) {
    case ArmInstructionKind::Branch: return "B";
    case ArmInstructionKind::BranchLink: return "BL";
    case ArmInstructionKind::BranchExchange: return "BX";
    case ArmInstructionKind::SoftwareInterrupt: return "SWI";
    case ArmInstructionKind::DataProcessing: return "data-processing";
    case ArmInstructionKind::SingleDataTransfer: return "single-data-transfer";
    case ArmInstructionKind::BlockDataTransfer: return "block-data-transfer";
    case ArmInstructionKind::Multiply: return "multiply";
    case ArmInstructionKind::HalfwordTransfer: return "halfword-transfer";
    case ArmInstructionKind::CoprocessorOrOther: return "coprocessor/other";
    case ArmInstructionKind::Unknown: return "unknown";
    }
    return "unknown";
}

} // namespace rag
