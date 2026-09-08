# Stop the background producer and consumer.
# Windows replacement for scripts/stop_local_pipeline.sh.
#
#   .\scripts\Stop-LocalPipeline.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

Stop-TrackedProcess -Name 'producer'
Stop-TrackedProcess -Name 'consumer'
