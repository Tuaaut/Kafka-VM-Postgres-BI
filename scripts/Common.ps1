# Shared helpers for the Windows local-development scripts.
# Dot-source this from the other .ps1 files:  . "$PSScriptRoot\Common.ps1"

Set-StrictMode -Version Latest

$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:RuntimeDir  = Join-Path $script:ProjectRoot '.runtime'
$script:LogDir      = Join-Path $script:ProjectRoot 'logs'

function Get-ProjectRoot { $script:ProjectRoot }
function Get-RuntimeDir  { $script:RuntimeDir }
function Get-LogDir      { $script:LogDir }

function Initialize-ProjectDirs {
    foreach ($dir in @($script:RuntimeDir, $script:LogDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Resolves the virtualenv interpreter. Windows venvs put it in Scripts\, unlike
# the bin/ layout the shell scripts assume, which is why those fail here.
function Get-VenvPython {
    if ($env:PYTHON_BIN) {
        if (-not (Test-Path $env:PYTHON_BIN)) {
            throw "PYTHON_BIN is set to '$env:PYTHON_BIN' but that file does not exist."
        }
        return (Resolve-Path $env:PYTHON_BIN).Path
    }

    $candidates = @(
        (Join-Path $script:ProjectRoot '.venv\Scripts\python.exe'),
        (Join-Path $script:ProjectRoot '.venv\bin\python')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }

    throw @"
No virtualenv found at .venv. Create one first:

    python -m venv .venv
    .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
"@
}

# Loads .env into the current process so child processes inherit it. Values are
# taken literally; surrounding quotes are stripped, nothing is expanded.
function Import-DotEnv {
    param([string]$Path = (Join-Path $script:ProjectRoot '.env'))

    if (-not (Test-Path $Path)) { return }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }

        $split = $trimmed.IndexOf('=')
        if ($split -lt 1) { continue }

        $key   = $trimmed.Substring(0, $split).Trim()
        $value = $trimmed.Substring($split + 1).Trim()
        if ($value.Length -ge 2) {
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        Set-Item -Path "Env:$key" -Value $value
    }
}

function Get-PidFile {
    param([Parameter(Mandatory)][string]$Name)
    Join-Path $script:RuntimeDir "$Name.pid"
}

# Returns the running process for a PID file, or $null. Also clears a PID file
# left behind by a process that has since exited.
function Get-TrackedProcess {
    param([Parameter(Mandatory)][string]$Name)

    $pidFile = Get-PidFile -Name $Name
    if (-not (Test-Path $pidFile)) { return $null }

    $raw = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $processId = 0
    if (-not [int]::TryParse($raw, [ref]$processId)) {
        Remove-Item -LiteralPath $pidFile -Force
        return $null
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if (-not $process) {
        Remove-Item -LiteralPath $pidFile -Force
        return $null
    }

    return $process
}

function Start-TrackedProcess {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    Initialize-ProjectDirs

    $existing = Get-TrackedProcess -Name $Name
    if ($existing) {
        Write-Output "$Name already running (PID $($existing.Id))"
        return $existing
    }

    $logPath = Join-Path $script:LogDir "$Name.log"
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
        -WorkingDirectory $script:ProjectRoot `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError (Join-Path $script:LogDir "$Name.err.log") `
        -WindowStyle Hidden -PassThru

    Set-Content -LiteralPath (Get-PidFile -Name $Name) -Value $process.Id -Encoding ascii
    Write-Output "Started $Name (PID $($process.Id)), logging to logs\$Name.log"
    return $process
}

function Stop-TrackedProcess {
    param([Parameter(Mandatory)][string]$Name)

    $process = Get-TrackedProcess -Name $Name
    if (-not $process) {
        Write-Output "$Name is not running."
        return
    }

    Stop-Process -Id $process.Id -Force
    $pidFile = Get-PidFile -Name $Name
    if (Test-Path $pidFile) { Remove-Item -LiteralPath $pidFile -Force }
    Write-Output "Stopped $Name (PID $($process.Id))"
}
