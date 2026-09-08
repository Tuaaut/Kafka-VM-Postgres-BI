# Report whether the background producer and consumer are running.
# Windows replacement for scripts/pipeline_status.sh, which uses `kill -0`.
#
#   .\scripts\Get-PipelineStatus.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

foreach ($name in @('producer', 'consumer')) {
    $process = Get-TrackedProcess -Name $name
    if ($process) {
        Write-Output "${name}: running (PID $($process.Id), started $($process.StartTime.ToString('HH:mm:ss')))"
    } else {
        Write-Output "${name}: stopped"
    }
}
