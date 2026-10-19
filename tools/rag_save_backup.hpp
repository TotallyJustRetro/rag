#pragma once

#include <filesystem>
#include <string>
#include <system_error>

namespace rag {

struct SaveBackupResult {
    bool save_found = false;
    bool ok = true;
    std::filesystem::path backup_path;
    std::string error;
};

// Rotate the previous cartridge save into two recovery generations:
//
//   <save>.bak.1 <- previous <save>.bak
//   <save>.bak   <- current <save>
//
// The current save is never moved or modified. Missing saves are not errors,
// so first-launch behavior remains unchanged. Callers may warn and continue if
// a backup fails; this function does not throw filesystem errors.
inline SaveBackupResult rotate_save_backups(const std::filesystem::path& save_path) {
    SaveBackupResult result;
    result.backup_path = save_path;
    result.backup_path += ".bak";

    std::error_code ec;
    if (!save_path.parent_path().empty()) {
        std::filesystem::create_directories(save_path.parent_path(), ec);
        if (ec) {
            result.ok = false;
            result.error = ec.message();
            return result;
        }
    }

    const auto save_status = std::filesystem::status(save_path, ec);
    if (ec == std::errc::no_such_file_or_directory ||
        ec == std::errc::not_a_directory) {
        // First-launch path: a missing save is expected, not a failure.
        ec.clear();
        return result;
    }
    if (ec) {
        result.ok = false;
        result.error = ec.message();
        return result;
    }
    if (!std::filesystem::is_regular_file(save_status)) {
        return result;
    }
    result.save_found = true;

    std::filesystem::path previous_backup = save_path;
    previous_backup += ".bak.1";

    ec.clear();
    const bool has_backup = std::filesystem::exists(result.backup_path, ec);
    if (ec) {
        result.ok = false;
        result.error = ec.message();
        return result;
    }

    if (has_backup) {
        std::filesystem::copy_file(
            result.backup_path,
            previous_backup,
            std::filesystem::copy_options::overwrite_existing,
            ec);
        if (ec) {
            result.ok = false;
            result.error = ec.message();
            return result;
        }
    }

    std::filesystem::copy_file(
        save_path,
        result.backup_path,
        std::filesystem::copy_options::overwrite_existing,
        ec);
    if (ec) {
        result.ok = false;
        result.error = ec.message();
    }
    return result;
}

} // namespace rag
