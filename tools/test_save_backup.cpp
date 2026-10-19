#include "rag_save_backup.hpp"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <stdexcept>
#include <system_error>

namespace {
int failures = 0;

void check(bool condition, const char* name) {
    if (!condition) {
        std::cerr << "FAIL: " << name << '\n';
        ++failures;
    }
}

void write_text(const std::filesystem::path& path, const std::string& text) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    output << text;
    if (!output) {
        throw std::runtime_error("could not write test save file");
    }
}

std::string read_text(const std::filesystem::path& path) {
    std::ifstream input(path, std::ios::binary);
    return std::string(std::istreambuf_iterator<char>(input), {});
}

void test_rotation() {
    const auto nonce = std::chrono::steady_clock::now().time_since_epoch().count();
    const auto root = std::filesystem::temp_directory_path() /
        ("rag-save-backup-test-" + std::to_string(nonce));
    const auto save = root / "saves" / "rag_mlss_usa.sav";
    auto backup = save;
    backup += ".bak";
    auto previous = save;
    previous += ".bak.1";

    std::error_code cleanup_error;
    std::filesystem::remove_all(root, cleanup_error);

    // A first run with no save should remain a harmless no-op.
    const auto first_empty = rag::rotate_save_backups(save);
    check(first_empty.ok, "missing save does not fail");
    check(!first_empty.save_found, "missing save is reported as absent");
    check(!std::filesystem::exists(backup), "missing save creates no .bak");

    write_text(save, "save-A");
    const auto first = rag::rotate_save_backups(save);
    check(first.ok, "first save backup succeeds");
    check(first.save_found, "existing save is found");
    check(read_text(backup) == "save-A", "first rotation copies current save to .bak");
    check(!std::filesystem::exists(previous), "first rotation has no previous .bak.1");

    write_text(save, "save-B");
    const auto second = rag::rotate_save_backups(save);
    check(second.ok, "second save backup succeeds");
    check(read_text(backup) == "save-B", "second rotation writes newer .bak");
    check(read_text(previous) == "save-A", "second rotation preserves prior .bak as .bak.1");

    write_text(save, "save-C");
    const auto third = rag::rotate_save_backups(save);
    check(third.ok, "third save backup succeeds");
    check(read_text(backup) == "save-C", "third rotation writes newest .bak");
    check(read_text(previous) == "save-B", "third rotation rolls .bak.1 forward");
    check(read_text(save) == "save-C", "rotation never modifies the live save");

    std::filesystem::remove_all(root, cleanup_error);
    check(!cleanup_error, "temporary save test directory cleans up");
}
} // namespace

int main() {
    try {
        test_rotation();
    } catch (const std::exception& exception) {
        std::cerr << "UNEXPECTED TEST ERROR: " << exception.what() << '\n';
        return 2;
    }

    if (failures != 0) {
        std::cerr << failures << " save-backup test(s) failed\n";
        return 1;
    }
    std::cout << "All RAG save-backup tests passed.\n";
    return 0;
}
