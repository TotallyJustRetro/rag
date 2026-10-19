param([string]$IntegrationPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "reference/mlss"))
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
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
if (-not $c.Contains('options.builtin_game_name = "RAG Edition: Superstar Saga";')) {
    throw "Could not apply the RAG Edition launcher identity."
}
Write-Utf8NoBom -Path $main -Text $c

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

Write-Host "RAG Edition overlay applied: custom identity, isolated settings/saves, FPS default and optional assist tools."
