[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Rom,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Bios,

    [string]$Toolchain = "C:/msys64/mingw64",
    [string]$SdlRoot = $env:SDL2_ROOT,
    [ValidateRange(1, 128)]
    [int]$Jobs = 4,
    [switch]$RunAfterBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Integration = Join-Path $RepoRoot "reference/mlss"
$ExpectedIntegrationCommit = "5c742186b131b88e48a4ba9b033ce0a480f23ccd"
$ExpectedRomSha1 = "7c303cdde5061ee329296948060b875cb50ba410"
$ExpectedRomMd5 = "4b1a5897d89d9e74ec7f630eefdfd435"
$ExpectedBiosSha1 = "300c20df6731a33952ded8c436f7f186d25d3492"
$ExpectedRomSize = 16777216
$ExpectedBiosSize = 16384
$ExpectedLocalRomName = "Mario Luigi - Superstar Saga (USA).gba"

function Assert-FileIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][long]$ExpectedSize,
        [Parameter(Mandatory = $true)][string]$ExpectedSha1,
        [string]$ExpectedMd5
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    $file = Get-Item -LiteralPath $Path
    if ($file.Length -ne $ExpectedSize) {
        throw "Unexpected size for '$Path': $($file.Length) bytes; expected $ExpectedSize."
    }

    $actualSha1 = (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actualSha1 -ne $ExpectedSha1) {
        throw "SHA-1 mismatch for '$Path': $actualSha1"
    }

    if ($ExpectedMd5) {
        $actualMd5 = (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant()
        if ($actualMd5 -ne $ExpectedMd5) {
            throw "MD5 mismatch for '$Path': $actualMd5"
        }
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host "`n==> $Description" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

$Rom = (Resolve-Path -LiteralPath $Rom).Path
$Bios = (Resolve-Path -LiteralPath $Bios).Path
Assert-FileIdentity -Path $Rom -ExpectedSize $ExpectedRomSize -ExpectedSha1 $ExpectedRomSha1 -ExpectedMd5 $ExpectedRomMd5
Assert-FileIdentity -Path $Bios -ExpectedSize $ExpectedBiosSize -ExpectedSha1 $ExpectedBiosSha1

Write-Host "ROM identity verified: $Rom"
Write-Host "Retail BIOS identity verified: $Bios"
Write-Host "The ROM and BIOS will remain local and will not be committed."

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    throw "Run this script from a git clone of RAG, not from a ZIP-only source tree."
}

$rootGit = & git -C $RepoRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or -not $rootGit) {
    throw "Could not locate the RAG Git working tree. Ensure Git is installed."
}

if (-not (Test-Path -LiteralPath (Join-Path $Integration "tools/regen.ps1"))) {
    Invoke-Checked -Description "Initialize the pinned Superstar Saga integration submodule" -Action {
        git -C $RepoRoot submodule update --init --recursive reference/mlss
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $Integration "tools/regen.ps1"))) {
    throw "reference/mlss did not initialize correctly. Run: git submodule update --init --recursive"
}

$integrationHead = (& git -C $Integration rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the pinned integration revision."
}
if ($integrationHead -ne $ExpectedIntegrationCommit) {
    throw "Unexpected integration commit $integrationHead; this wrapper expects pinned revision $ExpectedIntegrationCommit. Check out the repository's recorded submodule revision before building."
}

# regen.ps1 requires exactly one .gba in the integration root, with this exact filename.
$romInIntegration = Join-Path $Integration $ExpectedLocalRomName
$existingRoms = @(Get-ChildItem -LiteralPath $Integration -Filter "*.gba" -File -ErrorAction SilentlyContinue)
if ($existingRoms.Count -gt 1) {
    throw "Found multiple .gba files in $Integration. Keep only the verified USA Rev 0 ROM there."
}
if ($existingRoms.Count -eq 1) {
    Assert-FileIdentity -Path $existingRoms[0].FullName -ExpectedSize $ExpectedRomSize -ExpectedSha1 $ExpectedRomSha1 -ExpectedMd5 $ExpectedRomMd5
    if ($existingRoms[0].Name -ne $ExpectedLocalRomName) {
        throw "The local ROM in the integration folder must be named '$ExpectedLocalRomName'. Move or rename it, then rerun."
    }
} else {
    Copy-Item -LiteralPath $Rom -Destination $romInIntegration
    Write-Host "Placed the verified ROM in the local, gitignored integration folder."
}

Push-Location $Integration
try {
    Invoke-Checked -Description "Initialize pinned GBARecomp dependencies" -Action {
        & ".\tools\setup-deps.ps1"
    }

    if ([string]::IsNullOrWhiteSpace($SdlRoot)) {
        throw "SDL2_ROOT is not set. Pass -SdlRoot 'C:/path/to/SDL2/x86_64-w64-mingw32' or set the SDL2_ROOT environment variable."
    }

    Invoke-Checked -Description "Build the static-recompilation generator" -Action {
        & ".\tools\build-host.ps1" -Jobs $Jobs -Toolchain $Toolchain -SdlRoot $SdlRoot -GeneratorOnly
    }

    $generators = @(Get-ChildItem -LiteralPath ".\build\host" -Filter "gba_recompile.exe" -File -Recurse -ErrorAction SilentlyContinue)
    if ($generators.Count -ne 1) {
        throw "Expected one gba_recompile.exe under build\host; found $($generators.Count). Inspect logs\host-build.log."
    }

    $FrameworkBiosConfig = Join-Path $Integration "gbarecomp/bios/gba_bios.toml"
    $ExpectedBiosConfig = Join-Path $Integration "reference/gbarecomp/bios/gba_bios.toml"
    if ((Test-Path -LiteralPath $FrameworkBiosConfig) -and -not (Test-Path -LiteralPath $ExpectedBiosConfig)) {
        # Compatibility shim for this pinned integration revision: regen.ps1
        # still looks under reference/gbarecomp, while setup-deps.ps1 checks out
        # the framework under gbarecomp/. This ignored copy supplies only config
        # metadata; the authoritative framework remains the pinned submodule.
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ExpectedBiosConfig) | Out-Null
        Copy-Item -LiteralPath $FrameworkBiosConfig -Destination $ExpectedBiosConfig
        Write-Host "Prepared the ignored BIOS-config compatibility path for regen.ps1."
    }

    Invoke-Checked -Description "Generate native cartridge and BIOS C++ from verified local files" -Action {
        & ".\tools\regen.ps1" -Bios $Bios -Generator $generators[0].FullName
    }

    Invoke-Checked -Description "Compile the native Windows x64 game executable" -Action {
        & ".\tools\build-host.ps1" -Jobs $Jobs -Toolchain $Toolchain -SdlRoot $SdlRoot
    }

    $Executable = Join-Path $Integration "build/host/MarioLuigiSuperstarSagaRecomp.exe"
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "Build command completed but executable was not found at $Executable."
    }

    Write-Host "`nBUILD SUCCEEDED: $Executable" -ForegroundColor Green
    Write-Host "Run command: `"$Executable`" --rom `"$romInIntegration`" --bios `"$Bios`""
    if ($RunAfterBuild) {
        & $Executable --rom $romInIntegration --bios $Bios
        if ($LASTEXITCODE -ne 0) {
            throw "The executable exited with code $LASTEXITCODE."
        }
    }
} finally {
    Pop-Location
}
