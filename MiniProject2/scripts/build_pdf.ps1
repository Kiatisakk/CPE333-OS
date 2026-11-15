# Build latex/MiniProject2.pdf with pdfLaTeX.
#
# Regenerates latex/generated/ from results/ first (scripts/make_latex.py),
# then runs two passes so that cross-references resolve. Uses pdflatex
# directly rather than latexmk: a stock MiKTeX install has no Perl.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1

$ErrorActionPreference = "Stop"

$exe = (Get-Command pdflatex -ErrorAction SilentlyContinue).Source
if (-not $exe) {
    $fallback = Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64\pdflatex.exe"
    if (Test-Path $fallback) { $exe = $fallback }
}
if (-not $exe) {
    Write-Host "pdflatex not found on PATH or in the usual MiKTeX location." -ForegroundColor Red
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
python (Join-Path $PSScriptRoot "make_latex.py")
if ($LASTEXITCODE -ne 0) {
    Write-Host "make_latex.py failed" -ForegroundColor Red
    exit 1
}

$latexDir = Join-Path $root "latex"
$job = "MiniProject2"
$pdf = Join-Path $latexDir "$job.pdf"
$log = Join-Path $latexDir "$job.log"

Push-Location $latexDir
try {
    # A viewer holding the PDF open makes pdflatex stop at a confusing prompt.
    if (Test-Path $pdf) {
        try {
            $fs = [System.IO.File]::Open($pdf, 'Open', 'Write', 'Read')
            $fs.Close()
        }
        catch {
            Write-Host "$job.pdf is open in another program -- close it and run this again." -ForegroundColor Yellow
            $viewers = Get-Process |
                Where-Object { $_.Name -match 'Acrobat|AcroRd|Foxit|Sumatra|PDFXEdit|Nitro|msedge|chrome|firefox' } |
                Where-Object { $_.Name -notmatch 'Update' } |
                Select-Object -ExpandProperty Name -Unique
            if ($viewers) { Write-Host "  candidates: $($viewers -join ', ')" }
            exit 1
        }
    }

    foreach ($pass in 1, 2) {
        Write-Host "pass $pass with pdflatex ..."
        & $exe -interaction=nonstopmode -halt-on-error "-jobname=$job" main.tex | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=== build failed on pass $pass ===" -ForegroundColor Red
            if (Test-Path $log) {
                Select-String -Path $log -Pattern '^!' -Context 0, 4 |
                    Select-Object -First 5 | ForEach-Object { $_.Line; $_.Context.PostContext }
            }
            if (Test-Path $pdf) { Remove-Item $pdf -Force -ErrorAction SilentlyContinue }
            exit 1
        }
    }

    $warn  = @(Select-String -Path $log -Pattern "Overfull|Underfull" -ErrorAction SilentlyContinue)
    $pages = (Select-String -Path $log -Pattern "Output written" -ErrorAction SilentlyContinue).Line
    $body  = (Select-String -Path $log -Pattern "^BODY-PAGES: (\d+)" -ErrorAction SilentlyContinue).Matches.Groups[1].Value

    Write-Host ""
    Write-Host "OK  $pages"
    Write-Host "    body pages (limit 25, appendix excluded): $body"
    Write-Host "    overfull/underfull boxes: $($warn.Count)"
    Write-Host "    output: $pdf"
    if ([int]$body -gt 25) {
        Write-Host "body exceeds 25 pages" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}
