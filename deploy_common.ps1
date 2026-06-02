# Shared helpers for deploy_steam.ps1 and deploy_modio.ps1

$script:ModName = 'Monorail Tracks'
$script:ModDir = Join-Path $PSScriptRoot $script:ModName
$script:ModInfoPath = Join-Path $script:ModDir 'modinfo.sbmi'
$script:DeployDir = Join-Path $PSScriptRoot '.deploy'
$script:ChangelogPath = Join-Path $script:DeployDir 'changelog.txt'

function Find-SEWorkshopTool {
    if ($env:SEWORKSHOPTOOL_PATH -and (Test-Path -LiteralPath $env:SEWORKSHOPTOOL_PATH)) {
        return (Resolve-Path -LiteralPath $env:SEWORKSHOPTOOL_PATH).Path
    }

    $candidates = @(
        'C:\Steam\steamapps\common\SpaceEngineers\SEWorkshopTool.exe',
        'C:\Steam\steamapps\common\SpaceEngineers\Bin64\SEWorkshopTool.exe'
    )

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    throw @"
SEWorkshopTool.exe not found.
Install from https://github.com/Gwindalmir/SEWorkshopTool/releases
or set SEWORKSHOPTOOL_PATH to the full path of SEWorkshopTool.exe.
"@
}

function Get-ModVersion {
    param([string]$Path = $script:ModInfoPath)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "modinfo.sbmi not found: $Path"
    }

    [xml]$doc = Get-Content -LiteralPath $Path -Encoding UTF8
    $version = $doc.MyObjectBuilder_ModInfo.Version
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "No <Version> element in $Path"
    }

    return $version.Trim()
}

function Get-NextSemVer {
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [ValidateSet('patch', 'minor', 'major')]
        [string]$Bump = 'patch'
    )

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$') {
        throw "Version '$Version' is not semver x.y.z (got from modinfo.sbmi)."
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    switch ($Bump) {
        'major' { return '{0}.0.0' -f ($major + 1) }
        'minor' { return '{0}.{1}.0' -f $major, ($minor + 1) }
        'patch' { return '{0}.{1}.{2}' -f $major, $minor, ($patch + 1) }
    }
}

function Set-ModVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [string]$Path = $script:ModInfoPath
    )

    [xml]$doc = Get-Content -LiteralPath $Path -Encoding UTF8
    $doc.MyObjectBuilder_ModInfo.Version = $Version
    $doc.Save($Path)
}

function Read-ChangelogMessage {
    param([string]$PresetMessage)

    if (-not [string]::IsNullOrWhiteSpace($PresetMessage)) {
        return $PresetMessage.Trim()
    }

    Write-Host ''
    Write-Host 'Changelog / change note (required for this deploy):' -ForegroundColor Cyan
    $message = Read-Host 'Message'
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'Deploy cancelled: changelog message cannot be empty.'
    }

    return $message.Trim()
}

function Write-DeployChangelogFile {
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $script:DeployDir)) {
        New-Item -ItemType Directory -Path $script:DeployDir | Out-Null
    }

    $body = @(
        "v$Version"
        ''
        $Message
    ) -join [Environment]::NewLine

    Set-Content -LiteralPath $script:ChangelogPath -Value $body -Encoding UTF8
    return $script:ChangelogPath
}

function Invoke-MonorailDeploy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Steam', 'Modio')]
        [string]$Platform,

        [ValidateSet('patch', 'minor', 'major')]
        [string]$Bump = 'patch',

        [switch]$SkipVersionBump,
        [switch]$DryRun,
        [switch]$Force,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $script:ModDir)) {
        throw "Mod folder not found: $($script:ModDir)"
    }

    if (-not (Test-Path -LiteralPath $script:ModInfoPath)) {
        throw "modinfo.sbmi not found. SEWorkshopTool needs this file with a published Workshop/mod.io id."
    }

    $tool = Find-SEWorkshopTool
    $currentVersion = Get-ModVersion
    $newVersion = $currentVersion

    if (-not $SkipVersionBump) {
        $newVersion = Get-NextSemVer -Version $currentVersion -Bump $Bump
    }

    $changelogMessage = Read-ChangelogMessage -PresetMessage $Message
    $changelogFile = Write-DeployChangelogFile -Version $newVersion -Message $changelogMessage

    Write-Host ''
    Write-Host "Platform:   $Platform"
    Write-Host "Mod:        $($script:ModDir)"
    Write-Host "Version:    $currentVersion -> $newVersion$(if ($SkipVersionBump) { ' (skipped bump)' })"
    Write-Host "Changelog:  $changelogFile"
    Write-Host "Tool:       $tool"
    if ($Platform -eq 'Modio') {
        Write-Host ''
        Write-Host 'mod.io via SEWorkshopTool is experimental. Changelog (--message) is documented for Steam;' -ForegroundColor Yellow
        Write-Host 'it may not appear on mod.io. Configure mod.io auth in SEWorkshopTool.exe.config if needed.' -ForegroundColor Yellow
    }

    if (-not $Force) {
        $confirm = Read-Host 'Deploy now? [Y/n]'
        if ($confirm -match '^[Nn]') {
            throw 'Deploy cancelled by user.'
        }
    }

    if (-not $SkipVersionBump -and -not $DryRun -and $newVersion -ne $currentVersion) {
        Set-ModVersion -Version $newVersion
        Write-Host "Updated modinfo.sbmi version to $newVersion"
    }

    $toolArgs = @(
        'push',
        '--mods', $script:ModDir,
        '--update-only',
        '--no-compile',
        '--message', $changelogFile
    )

    if ($Platform -eq 'Modio') {
        $toolArgs += '--modio'
    }

    if ($DryRun) {
        $toolArgs += '--dry-run'
    }

    Write-Host ''
    Write-Host "Running: $tool $($toolArgs -join ' ')"
    Write-Host ''

    & $tool @toolArgs
    if ($LASTEXITCODE -ne 0) {
        if (-not $SkipVersionBump -and -not $DryRun -and $newVersion -ne $currentVersion) {
            Write-Warning "Deploy failed; reverting modinfo version $newVersion -> $currentVersion"
            Set-ModVersion -Version $currentVersion
        }
        throw "SEWorkshopTool exited with code $LASTEXITCODE. Check the log under %AppData%\SpaceEngineers\."
    }

    Write-Host ''
    Write-Host 'Deploy finished successfully.' -ForegroundColor Green
}
