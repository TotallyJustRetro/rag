param([string]$IntegrationPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "reference/mlss"))
$ErrorActionPreference = "Stop"

$main = Join-Path $IntegrationPath "src/main.cpp"
$config = Join-Path $IntegrationPath "game.toml"
$cmake = Join-Path $IntegrationPath "CMakeLists.txt"
$build = Join-Path $IntegrationPath "tools/build-host.ps1"
foreach ($p in @($main,$config,$cmake,$build)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Missing RAG patch target: $p" }
}

$c = Get-Content -LiteralPath $main -Raw
$c = $c.Replace('options.builtin_game_name = "Mario & Luigi: Superstar Saga";','options.builtin_game_name = "RAG Edition: Superstar Saga";')
$c = $c.Replace('options.launcher_save_path = "saves/mlss_usa.sav";', @'
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
'@)
Set-Content -LiteralPath $main -Value $c -Encoding utf8NoBOM

$c = Get-Content -LiteralPath $config -Raw
$c = $c.Replace('window_title = "MarioLuigiSuperstarSagaRecomp"','window_title = "RAG Edition: Superstar Saga"')
Set-Content -LiteralPath $config -Value $c -Encoding utf8NoBOM

$c = Get-Content -LiteralPath $cmake -Raw
$c = $c.Replace('    target_link_gbarecomp_runtime_stack(MarioLuigiSuperstarSagaRecomp)', '    set_target_properties(MarioLuigiSuperstarSagaRecomp PROPERTIES OUTPUT_NAME "RAGSuperstarSaga")' + [Environment]::NewLine + '    target_link_gbarecomp_runtime_stack(MarioLuigiSuperstarSagaRecomp)')
Set-Content -LiteralPath $cmake -Value $c -Encoding utf8NoBOM

$c = Get-Content -LiteralPath $build -Raw
$c = $c.Replace('MarioLuigiSuperstarSagaRecomp.exe','RAGSuperstarSaga.exe')
Set-Content -LiteralPath $build -Value $c -Encoding utf8NoBOM

Write-Host "RAG Edition overlay applied: branding, isolated settings/saves, FPS default and optional assist tools."
