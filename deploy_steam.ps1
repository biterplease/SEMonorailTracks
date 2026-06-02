# Publish Monorail Tracks to Steam Workshop via SEWorkshopTool.
# Requires modinfo.sbmi with WorkshopId, and SEWorkshopTool next to Space Engineers.
#
# Usage:
#   .\deploy_steam.ps1
#   .\deploy_steam.ps1 -Bump minor -Message "Fixed ramp collisions"
#   .\deploy_steam.ps1 -DryRun
#
# Changelog: uses SEWorkshopTool push --message (Steam change notes; requires content upload).

[CmdletBinding()]
param(
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump = 'patch',

    [switch]$SkipVersionBump,
    [switch]$DryRun,
    [switch]$Force,
    [string]$Message
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\deploy_common.ps1"

Invoke-MonorailDeploy -Platform Steam @PSBoundParameters
