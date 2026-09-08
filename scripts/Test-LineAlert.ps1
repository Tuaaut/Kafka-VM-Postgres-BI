# Send one sample critical alert through the LINE bridge.
# Windows replacement for scripts/test_line_alert.sh, which piped an inline
# heredoc into `python3`. Both entry points now run
# scripts/send_test_line_alert.py.
#
#   .\scripts\Test-LineAlert.ps1
#
# This sends a real LINE message when LINE_CHANNEL_ACCESS_TOKEN is set.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Import-DotEnv
$python = Get-VenvPython

if (-not $env:LINE_CHANNEL_ACCESS_TOKEN) {
    Write-Warning 'LINE_CHANNEL_ACCESS_TOKEN is not set in .env; the bridge will report the token as missing instead of sending.'
}

Push-Location (Get-ProjectRoot)
try {
    & $python scripts/send_test_line_alert.py
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
