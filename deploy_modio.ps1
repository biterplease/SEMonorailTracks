# Publish Monorail Tracks to mod.io via SEWorkshopTool (--modio).
# Requires mod.io authentication in SEWorkshopTool.exe.config (see SEWorkshopTool README).
#
# Usage:
#   .\deploy_modio.ps1
#   .\deploy_modio.ps1 -Bump patch -Message "Xbox crossplay update"
#   .\deploy_modio.ps1 -DryRun
#
# Limitations (SEWorkshopTool): mod.io support is experimental; tag/thumbnail tooling is limited.
# --message changelog support is documented for Steam Workshop only; it may not apply on mod.io.

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

Invoke-MonorailDeploy -Platform Modio @PSBoundParameters
