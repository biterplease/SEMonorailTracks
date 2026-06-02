<#
.SYNOPSIS
Creates a mod.io-ready zip package under releases/modio/.

.DESCRIPTION
- Reads the current version from Monorail Tracks/modinfo.sbmi
- Produces: releases/modio/MonorailTracks-<Version>.zip
- Packs mod contents at zip root (no parent folder)
- Writes modinfo.sbm inside the package from modinfo.sbmi for compatibility
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$modName = 'Monorail Tracks'
$modDir = Join-Path $repoRoot $modName
$modInfoSbmi = Join-Path $modDir 'modinfo.sbmi'
$releaseDir = Join-Path $repoRoot 'releases\modio'

if (-not (Test-Path -LiteralPath $modDir)) {
    throw "Mod directory not found: $modDir"
}

if (-not (Test-Path -LiteralPath $modInfoSbmi)) {
    throw "modinfo.sbmi not found: $modInfoSbmi"
}

[xml]$modInfo = Get-Content -LiteralPath $modInfoSbmi -Encoding UTF8
$version = $modInfo.MyObjectBuilder_ModInfo.Version
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "No <Version> element found in $modInfoSbmi"
}
$version = $version.Trim()

if (-not (Test-Path -LiteralPath $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

$zipName = "MonorailTracks-$version.zip"
$zipPath = Join-Path $releaseDir $zipName

if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw "Package already exists: $zipPath (use -Force to overwrite)"
}

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("MonorailTracks_modio_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

try {
    # Copy all mod content into staging.
    Get-ChildItem -LiteralPath $modDir -Force | Copy-Item -Destination $stagingRoot -Recurse -Force

    # Ensure modinfo.sbm exists in package (based on current modinfo.sbmi).
    Copy-Item -LiteralPath $modInfoSbmi -Destination (Join-Path $stagingRoot 'modinfo.sbm') -Force

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

Write-Host "Created mod.io package: $zipPath" -ForegroundColor Green
