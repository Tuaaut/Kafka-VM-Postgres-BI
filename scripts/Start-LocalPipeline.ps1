# Start the local producer and consumer in the background.
# Windows replacement for scripts/start_local_pipeline.sh, which relies on
# .venv/bin/python, nohup and POSIX PID semantics.
#
#   .\scripts\Start-LocalPipeline.ps1
#
# Requires the Docker stack to be up first (scripts/Start-Services.ps1 or
# `docker compose up -d`), because both processes connect to Kafka and Postgres.

[CmdletBinding()]
param(
    [int]$EventIntervalSeconds = 60,
    [int]$EventsPerBatch = 10
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Import-DotEnv
$python = Get-VenvPython

if (-not $env:PRODUCER_EVENT_INTERVAL_SECONDS) {
    $env:PRODUCER_EVENT_INTERVAL_SECONDS = "$EventIntervalSeconds"
}
if (-not $env:PRODUCER_EVENTS_PER_BATCH) {
    $env:PRODUCER_EVENTS_PER_BATCH = "$EventsPerBatch"
}

Start-TrackedProcess -Name 'consumer' -FilePath $python `
    -Arguments @('-u', 'consumer/postgres_event_consumer.py') | Out-Null

Start-TrackedProcess -Name 'producer' -FilePath $python `
    -Arguments @('-u', 'producer/machine_event_producer.py') | Out-Null

Write-Output ''
& "$PSScriptRoot\Get-PipelineStatus.ps1"
