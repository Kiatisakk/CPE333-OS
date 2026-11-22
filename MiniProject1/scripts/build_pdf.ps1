# Build MiniProject1/latex/MiniProject1.pdf with pdfLaTeX.
#
# Uses two passes so that any future references resolve.  Pass -Xe switches to
# XeLaTeX when the author block is later filled with Thai characters.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1

param([switch]$Xe)

$ErrorActionPreference = "Stop"

$engineName = if ($Xe) { "xelatex" } else { "pdflatex" }
$engine = (Get-Command $engineName -ErrorAction SilentlyContinue).Source
if (-not $engine) {
    $fallback = Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64\$engineName.exe"
    if (Test-Path $fallback) { $engine = $fallback }
}
if (-not $engine) {
    Write-Error "$engineName was not found on PATH or in the usual MiKTeX location."
}

# Keep the report evidence small enough for listings while preserving a direct
# derivation from the full captured transcripts.
$evidenceScript = Join-Path $PSScriptRoot "make_evidence.ps1"
& $evidenceScript
if (-not $?) {
    throw "Evidence excerpt generation failed."
}

$latexDir = Join-Path (Split-Path -Parent $PSScriptRoot) "latex"
$pdf = Join-Path $latexDir "MiniProject1.pdf"
$log = Join-Path $latexDir "MiniProject1.log"

Push-Location $latexDir
try {
    if (Test-Path $pdf) {
        try {
            $stream = [System.IO.File]::Open($pdf, 'Open', 'Write', 'Read')
            $stream.Close()
        }
        catch {
            Write-Host "MiniProject1.pdf is open in another program; close it and run again." -ForegroundColor Yellow
            exit 1
        }
    }

    foreach ($pass in 1, 2) {
        Write-Host "pass $pass with $engineName ..."
        & $engine -interaction=nonstopmode -halt-on-error -jobname=MiniProject1 main.tex | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=== build failed on pass $pass ===" -ForegroundColor Red
            if (Test-Path $log) {
                Select-String -Path $log -Pattern '^!' -Context 0,4 |
                    Select-Object -First 5 |
                    ForEach-Object { $_.Line; $_.Context.PostContext }
            }
            if (Test-Path $pdf) {
                Remove-Item $pdf -Force -ErrorAction SilentlyContinue
            }
            exit 1
        }
    }

    $warnings = @(Select-String -Path $log -Pattern "Overfull|Underfull" -ErrorAction SilentlyContinue)
    $pages = (Select-String -Path $log -Pattern "Output written" -ErrorAction SilentlyContinue).Line
    Write-Host ""
    Write-Host "OK  $pages"
    Write-Host "    overfull/underfull boxes: $($warnings.Count)"
    Write-Host "    output: $pdf"
}
finally {
    Pop-Location
}
