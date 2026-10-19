param([string]$IntegrationPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "reference/mlss"))
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Replace-ExpectedText {
    param(
        [string]$Path,
        [string]$OldText,
        [string]$NewText,
        [string]$Description,
        [int]$ExpectedCount = 1
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "RAG overlay target missing for '$Description': $Path"
    }

    $content = [System.IO.File]::ReadAllText($Path)
    $crlf = ([char]13).ToString() + ([char]10).ToString()
    $lf = ([char]10).ToString()
    $content = $content.Replace($crlf, $lf)
    $normalizedOld = $OldText.Replace($crlf, $lf)
    $normalizedNew = $NewText.Replace($crlf, $lf)
    $oldCount = [regex]::Matches($content, [regex]::Escape($normalizedOld)).Count
    if ($oldCount -eq 0) {
        $newCount = [regex]::Matches($content, [regex]::Escape($normalizedNew)).Count
        if ($newCount -eq $ExpectedCount) {
            Write-Host "Already applied: $Description"
            return
        }
        throw "Expected source anchor for '$Description' not found in $Path."
    }
    if ($oldCount -ne $ExpectedCount) {
        throw "Expected $ExpectedCount source anchor(s) for '$Description' in $Path, found $oldCount."
    }

    $content = $content.Replace($normalizedOld, $normalizedNew)
    Write-Utf8NoBom -Path $Path -Text $content
    Write-Host "Applied: $Description"
}

$main = Join-Path $IntegrationPath "src/main.cpp"
$config = Join-Path $IntegrationPath "game.toml"
$cmake = Join-Path $IntegrationPath "CMakeLists.txt"
$build = Join-Path $IntegrationPath "tools/build-host.ps1"
foreach ($p in @($main,$config,$cmake,$build)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Missing RAG patch target: $p" }
}

$c = [System.IO.File]::ReadAllText($main)
$c = $c.Replace('options.builtin_game_name = "Mario & Luigi: Superstar Saga";','options.builtin_game_name = "RAG Edition: Superstar Saga";')
$oldSave = 'options.launcher_save_path = "saves/mlss_usa.sav";'
$newSave = 'options.launcher_save_path = "saves/rag_mlss_usa.sav";'
if ($c.Contains($oldSave)) {
    $newOptions = @'
    // RAG Edition quality-of-life defaults. Keep sidecar files distinct from
    // the upstream preview so both builds can coexist without sharing settings.
    options.launcher_config_filename = "rag-config.ini";
    options.launcher_keybinds_filename = "rag-keybinds.ini";
    options.launcher_rom_cache_filename = "rag-rom.cfg";
    options.launcher_bios_cache_filename = "rag-bios.cfg";
    options.launcher_save_path = "saves/rag_mlss_usa.sav";
    options.show_fps_by_default = true;
    options.freely_resizable_window = true;
    options.launcher_expose_sharp_filter = true;
    options.launcher_default_sharp_filter = false;
    options.launcher_expose_affine_filter = true;
    options.launcher_default_affine_filter = false;
    options.expose_assist_tools = true;
    options.assist_tools_enabled_by_default = true;
    options.assist_fast_forward_multiplier_default = 4;
    options.save_state_slot_count = 9;
    options.rewind_history_seconds = 5;
'@
    $c = $c.Replace($oldSave, $newOptions)
} elseif (-not $c.Contains($newSave)) {
    throw "Could not find the expected save-path anchor in src/main.cpp."
}

# Keep later overlay additions applied even when this submodule was already
# modified by an earlier RAG build.
$displayOptions = @(
    'options.launcher_expose_sharp_filter = true;',
    'options.launcher_default_sharp_filter = false;',
    'options.launcher_expose_affine_filter = true;',
    'options.launcher_default_affine_filter = false;'
)
$displayAnchor = 'options.freely_resizable_window = true;'
foreach ($option in $displayOptions) {
    if (-not $c.Contains($option)) {
        if (-not $c.Contains($displayAnchor)) {
            throw "Could not add RAG display option '$option' to src/main.cpp."
        }
        $c = $c.Replace($displayAnchor, $displayAnchor + [Environment]::NewLine + "    " + $option)
    }
    $displayAnchor = $option
}

if (-not $c.Contains('options.builtin_game_name = "RAG Edition: Superstar Saga";')) {
    throw "Could not apply the RAG Edition launcher identity."
}
Write-Utf8NoBom -Path $main -Text $c

$backupOld = @'
    if (game_validate_inputs(args, options)) return 1;
    if (player_launch) {
        args.emplace_back("--save");
'@
$backupNew = @'
    if (game_validate_inputs(args, options)) return 1;

    // RAG save safety: preserve the last session's cartridge save before
    // starting a new interactive session. Keep two generations outside the
    // game runtime so an interrupted write can be recovered manually.
    if (player_launch && options.launcher_save_path &&
        options.launcher_save_path[0]) {
        std::filesystem::path save_path(options.launcher_save_path);
        if (save_path.is_relative())
            save_path = std::filesystem::current_path() / save_path;
        std::error_code save_error;
        if (!save_path.parent_path().empty())
            std::filesystem::create_directories(save_path.parent_path(), save_error);
        if (save_error) {
            std::fprintf(stderr, "[RAG] Save backup warning: %s\n",
                         save_error.message().c_str());
        } else if (std::filesystem::is_regular_file(save_path, save_error) &&
                   !save_error) {
            std::filesystem::path backup = save_path;
            backup += ".bak";
            std::filesystem::path previous_backup = save_path;
            previous_backup += ".bak.1";
            save_error.clear();
            if (std::filesystem::exists(backup, save_error) && !save_error) {
                std::filesystem::copy_file(
                    backup, previous_backup,
                    std::filesystem::copy_options::overwrite_existing,
                    save_error);
            }
            if (!save_error) {
                std::filesystem::copy_file(
                    save_path, backup,
                    std::filesystem::copy_options::overwrite_existing,
                    save_error);
            }
            if (save_error) {
                std::fprintf(stderr, "[RAG] Save backup warning: %s\n",
                             save_error.message().c_str());
            } else {
                std::fprintf(stderr, "[RAG] Save backup written to %s\n",
                             backup.string().c_str());
            }
        }
    }

    if (player_launch) {
        args.emplace_back("--save");
'@
Replace-ExpectedText -Path $main -OldText $backupOld -NewText $backupNew -Description "two-generation automatic cartridge-save backup"

$c = [System.IO.File]::ReadAllText($config)
$c = $c.Replace('window_title = "MarioLuigiSuperstarSagaRecomp"','window_title = "RAG Edition: Superstar Saga"')
$c = $c.Replace('path = "saves/mlss_usa.sav"', 'path = "saves/rag_mlss_usa.sav"')
if (-not $c.Contains('path = "saves/rag_mlss_usa.sav"')) { throw "Could not isolate the RAG Edition cartridge save path." }
Write-Utf8NoBom -Path $config -Text $c

$c = [System.IO.File]::ReadAllText($cmake)
if (-not $c.Contains('OUTPUT_NAME "RAGSuperstarSaga"')) {
    $anchor = '    target_link_gbarecomp_runtime_stack(MarioLuigiSuperstarSagaRecomp)'
    if (-not $c.Contains($anchor)) { throw "Could not find the executable target link anchor in CMakeLists.txt." }
    $c = $c.Replace($anchor, '    set_target_properties(MarioLuigiSuperstarSagaRecomp PROPERTIES OUTPUT_NAME "RAGSuperstarSaga")' + [Environment]::NewLine + $anchor)
}
Write-Utf8NoBom -Path $cmake -Text $c

$c = [System.IO.File]::ReadAllText($build)
$c = $c.Replace('MarioLuigiSuperstarSagaRecomp.exe','RAGSuperstarSaga.exe')
if (-not $c.Contains('RAGSuperstarSaga.exe')) { throw "Could not set the expected RAG executable output in tools/build-host.ps1." }
Write-Utf8NoBom -Path $build -Text $c

# Keep the runtime's keyboard/hotkey/touch persistence pointed at the same
# per-variant config files that the pre-boot launcher uses.
$runtimeHeader = Join-Path $IntegrationPath "gbarecomp/src/runtime/host_window.h"
$runtimeWindow = Join-Path $IntegrationPath "gbarecomp/src/runtime/host_window.cpp"
$runtimeCore = Join-Path $IntegrationPath "gbarecomp/src/runtime/runtime.cpp"
$launcherBoot = Join-Path $IntegrationPath "src/game_launcher_boot.cpp"

Replace-ExpectedText -Path $launcherBoot -OldText '"bios.cfg"' -NewText '"rag-bios.cfg"' -Description "RAG BIOS cache fallback path"
Replace-ExpectedText -Path $launcherBoot -OldText '"rom.cfg"' -NewText '"rag-rom.cfg"' -Description "RAG ROM cache fallback path"

Replace-ExpectedText -Path $runtimeHeader -OldText 'int fast_forward_multiplier_default = 4);' -NewText 'int fast_forward_multiplier_default = 4,
                           const char* config_filename = nullptr,
                           const char* keybinds_filename = nullptr);' -Description "runtime config filename API"

Replace-ExpectedText -Path $runtimeCore -OldText 'opts.assist_fast_forward_multiplier_default);' -NewText 'opts.assist_fast_forward_multiplier_default,
                                  opts.launcher_config_filename,
                                  opts.launcher_keybinds_filename);' -Description "runtime uses RAG launcher config filenames"

Replace-ExpectedText -Path $runtimeWindow -OldText '    std::string touch_config_dir;' -NewText '    std::string touch_config_dir;
    std::string input_config_filename = "config.ini";' -Description "host stores active config filename"

Replace-ExpectedText -Path $runtimeWindow -OldText 'int fast_forward_multiplier_default) {' -NewText 'int fast_forward_multiplier_default,
                                   const char* config_filename,
                                   const char* keybinds_filename) {' -Description "runtime input config implementation API"

Replace-ExpectedText -Path $runtimeWindow -OldText '    const std::string base = std::string(dir) + "/";' -NewText '    const std::string base = std::string(dir) + "/";
    b->input_config_filename = (config_filename && *config_filename)
        ? config_filename : "config.ini";
    const std::string keybinds_name = (keybinds_filename && *keybinds_filename)
        ? keybinds_filename : "keybinds.ini";' -Description "runtime filename selection"

Replace-ExpectedText -Path $runtimeWindow -OldText '(base + "keybinds.ini").c_str()' -NewText '(base + keybinds_name).c_str()' -Description "runtime reads variant keybindings"
Replace-ExpectedText -Path $runtimeWindow -OldText '(base + "config.ini").c_str()' -NewText '(base + b->input_config_filename).c_str()' -Description "runtime reads variant config" -ExpectedCount 2

Replace-ExpectedText -Path $runtimeWindow -OldText 'const std::string path = b->touch_config_dir + "/config.ini";' -NewText 'const std::string path = b->touch_config_dir + "/" + b->input_config_filename;' -Description "touch settings persist to variant config"
Replace-ExpectedText -Path $runtimeWindow -OldText 'ini_scan_section((b->touch_config_dir + "/config.ini").c_str(), "Touch",' -NewText 'ini_scan_section((b->touch_config_dir + "/" + b->input_config_filename).c_str(), "Touch",' -Description "touch settings read from variant config"
Replace-ExpectedText -Path $runtimeWindow -OldText 'int /*fast_forward_multiplier_default*/) {}' -NewText 'int /*fast_forward_multiplier_default*/,
                                   const char* /*config_filename*/,
                                   const char* /*keybinds_filename*/) {}' -Description "non-SDL stub API"

Write-Host "RAG Edition overlay applied: independent settings/saves, FPS display, aspect-correct resizing, fast-forward, save states and rewind."
