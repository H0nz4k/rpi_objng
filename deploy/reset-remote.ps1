# Rychly reset firstbootu na RPi (bez nahravani baliku).
# Stejne jako: .\deploy.ps1 -Reset
#
#   .\reset-remote.ps1
#   .\reset-remote.ps1 -Factory    # smaze i /opt/objednavka-ng
#   .\reset-remote.ps1 -NoReboot

[CmdletBinding()]
param(
    [switch]$Factory,
    [switch]$NoReboot,
    [string]$RemoteHost,
    [string]$User
)

$params = @{ Reset = $true }
if ($Factory) { $params.Factory = $true }
if ($NoReboot) { $params.NoReboot = $true }
if ($RemoteHost) { $params.RemoteHost = $RemoteHost }
if ($User) { $params.User = $User }

& (Join-Path $PSScriptRoot 'deploy.ps1') @params
