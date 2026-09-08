# Run the machine event producer in the foreground (Ctrl+C to stop).
# Windows replacement for scripts/run_producer_60s.sh, which hardcodes
# .venv/bin/python. Defaults match that script: one batch of 10 events per
# minute.
#
#   .\scripts\Start-Producer.ps1
#   .\scripts\Start-Producer.ps1 -EventIntervalSeconds 5 -EventsPerBatch 50

[CmdletBinding()]
param(
    [int]$EventIntervalSeconds = 60,
    [int]$EventsPerBatch = 10
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Import-DotEnv
$python = Get-VenvPython

$env:PRODUCER_EVENT_INTERVAL_SECONDS = "$EventIntervalSeconds"
$env:PRODUCER_EVENTS_PER_BATCH = "$EventsPerBatch"

Push-Location (Get-ProjectRoot)
try {
    & $python producer/machine_event_producer.py
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
