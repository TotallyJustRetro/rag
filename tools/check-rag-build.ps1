[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Rom,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Bios,

    [string]$Toolchain = "C:/msys64/mingw64",
    [string]$SdlRoot = "C:/msys64/mingw64",
    [string]$OutputDir = "C:/RAG-private/RAG-Edition"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ExpectedIntegrationCommit = "5c742186b131b88e48a4ba9b033ce0a480f23ccd"
$ExpectedRomSha1 = "7c303cdde5061ee329296948060b875cb50ba410"
$ExpectedRomMd5 = "4b1a5897d89d9e74ec7f630eefdfd435"
$ExpectedBiosSha1 = "300c20df6731a33952ded8c436f7f186d25d3492"
$ExpectedRomSize = 16777216
$ExpectedBiosSize = 16384

if ($env:OS -ne "Windows_NT") {
    throw "The RAG native build preflight must run on Windows."
}
if (-not [Environment]::Is64BitOperatingSystem) {
    throw "RAG Edition requires 64-bit Windows."
}
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Use PowerShell 7 (pwsh) to match the build workflow."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found on PATH. Install Git for Windows."
}

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$Integration = Join-Path $RepoRoot "reference/mlss"
$separator = [string][System.IO.Path]::DirectorySeparatorChar
$trimChars = [char[]]@([char]92, [char]47)
$workspacePrefix = $RepoRoot.TrimEnd($trimChars) + $separator

function Resolve-ExistingFile {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file not found: $Path"
    }
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
}

function Assert-FileIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][long]$ExpectedSize,
        [Parameter(Mandatory = $true)][string]$ExpectedSha1,
        [string]$ExpectedMd5
    )

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ne $ExpectedSize) {
        throw "Unexpected size for '$Path': $($item.Length) bytes; expected $ExpectedSize."
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

$romFull = Resolve-ExistingFile -Path $Rom -Label "ROM"
$biosFull = Resolve-ExistingFile -Path $Bios -Label "BIOS"

foreach ($inputFile in @(@{ Label = "ROM"; Path = $romFull }, @{ Label = "BIOS"; Path = $biosFull })) {
    if ($inputFile.Path.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$($inputFile.Label) must remain outside the Git checkout: $($inputFile.Path)"
    }
}
Assert-FileIdentity -Path $romFull -ExpectedSize $ExpectedRomSize -ExpectedSha1 $ExpectedRomSha1 -ExpectedMd5 $ExpectedRomMd5
Assert-FileIdentity -Path $biosFull -ExpectedSize $ExpectedBiosSize -ExpectedSha1 $ExpectedBiosSha1

if (-not (Test-Path -LiteralPath (Join-Path $Integration "tools/regen.ps1") -PathType Leaf)) {
    throw "Pinned integration is not initialized. Run: git submodule update --init --recursive"
}
$integrationHead = (& git -C $Integration rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the pinned integration revision. Initialize reference/mlss and retry."
}
if ($integrationHead -ne $ExpectedIntegrationCommit) {
    throw "Unexpected integration commit '$integrationHead'; expected '$ExpectedIntegrationCommit'."
}

$toolchainFull = [System.IO.Path]::GetFullPath($Toolchain)
$sdlFull = [System.IO.Path]::GetFullPath($SdlRoot)
foreach ($relative in @("bin/gcc.exe", "bin/g++.exe", "bin/cmake.exe", "bin/ninja.exe")) {
    $path = Join-Path $toolchainFull $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required MinGW build tool not found: $path"
    }
}
foreach ($relative in @("include/SDL2/SDL.h", "lib/libSDL2.dll.a", "bin/SDL2.dll")) {
    $path = Join-Path $sdlFull $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required SDL2 development/runtime file not found: $path"
    }
}

$output = [System.IO.Path]::GetFullPath($OutputDir)
if ($output.Equals([System.IO.Path]::GetPathRoot($output), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "A drive root cannot be used as the package output directory."
}
$outputPrefix = $output.TrimEnd($trimChars) + $separator
if ($output.Equals($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    $RepoRoot.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Choose a package output directory outside the Git checkout and not one of its parent folders."
}
foreach ($inputFile in @($romFull, $biosFull)) {
    if ($inputFile.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "The package output directory would contain a ROM/BIOS input: $inputFile"
    }
}
$marker = Join-Path $output ".rag-package-managed"
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw "The build workflow refuses to delete an existing unmarked folder: $output"
    }
    Write-Host "Existing managed output folder will be replaced after a successful build: $output"
}

Write-Host "PASS: Windows x64 and PowerShell 7"
Write-Host "PASS: ROM identity verified ($romFull)"
Write-Host "PASS: retail BIOS identity verified ($biosFull)"
Write-Host "PASS: pinned integration revision $integrationHead"
Write-Host "PASS: MinGW and SDL2 development/runtime files found"
Write-Host "PASS: output path is outside the checkout and does not contain input files ($output)"
Write-Host "Preflight passed. This check does not build the game or create an executable."
