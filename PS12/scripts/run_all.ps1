# Run both Linux (WSL Ubuntu) and Windows experiments for CPE 333 PS12.
#
#   powershell -ExecutionPolicy Bypass -File PS12\scripts\run_all.ps1

$ErrorActionPreference = "Stop"
$ps12Dir = Split-Path -Parent $PSScriptRoot
$repoDir = Split-Path -Parent $ps12Dir

Push-Location $repoDir
try {
    Write-Host "=== Running Windows Lab 1 (cmd /c) ==="
    & cmd /c "$ps12Dir\scripts\run_windows.cmd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host ""
    Write-Host "=== Running Linux Labs 1-3 (WSL Ubuntu) ==="
    $env:MSYS_NO_PATHCONV = "1"
    & wsl -d Ubuntu -- bash ./PS12/scripts/run_all.sh
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
