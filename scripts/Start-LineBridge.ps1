# Run the LINE alert bridge locally in the foreground (Ctrl+C to stop).
# Windows replacement for scripts/run_line_bridge_local.sh, which calls
# `python3` - a name that does not exist on Windows.
#
#   .\scripts\Start-LineBridge.ps1
#
# Grafana posts alerts to this bridge, which forwards them to LINE. It needs
# LINE_CHANNEL_ACCESS_TOKEN in .env; without it the bridge starts but reports
# that the token is not set.

[CmdletBinding()]
param(
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Import-DotEnv
$python = Get-VenvPython

if (-not $env:PORT) { $env:PORT = "$Port" }

if (-not $env:LINE_CHANNEL_ACCESS_TOKEN) {
    Write-Warning 'LINE_CHANNEL_ACCESS_TOKEN is not set in .env; the bridge will refuse to send messages.'
}

Push-Location (Get-ProjectRoot)
try {
    & $python alerting/line_alert_bridge.py
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
