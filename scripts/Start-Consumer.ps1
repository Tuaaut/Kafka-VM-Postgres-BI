# Run the Postgres event consumer in the foreground (Ctrl+C to stop).
# Windows replacement for scripts/run_consumer.sh, which hardcodes
# .venv/bin/python.
#
#   .\scripts\Start-Consumer.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Import-DotEnv
$python = Get-VenvPython

Push-Location (Get-ProjectRoot)
try {
    & $python -u consumer/postgres_event_consumer.py
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
