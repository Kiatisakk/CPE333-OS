# Build latex/main.pdf with pdfLaTeX.
#
# Uses pdflatex directly rather than latexmk: latexmk is a Perl script and a
# stock MiKTeX install has no Perl script engine. Two passes are needed so that
# cross-references resolve.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1
#
# Pass -Xe to build with XeLaTeX instead (needed for Thai characters -- see the
# switch instructions in latex/preamble.tex).

param([switch]$Xe)

$ErrorActionPreference = "Stop"

$engine = if ($Xe) { "xelatex" } else { "pdflatex" }

# Find the engine on PATH first, so this works for every group member; fall
# back to the usual per-user MiKTeX location only if it is not on PATH.
$exe = (Get-Command $engine -ErrorAction SilentlyContinue).Source
if (-not $exe) {
    $fallback = Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64\$engine.exe"
    if (Test-Path $fallback) { $exe = $fallback }
}
if (-not $exe) {
    Write-Host "$engine not found on PATH or in the usual MiKTeX location." -ForegroundColor Red
    Write-Host "Install MiKTeX (or TeX Live) and make sure $engine is on PATH."
    exit 1
}

$latexDir = Join-Path (Split-Path -Parent $PSScriptRoot) "latex"
$pdf = Join-Path $latexDir "main.pdf"
$log = Join-Path $latexDir "main.log"

Push-Location $latexDir
try {
    # A viewer holding main.pdf open makes pdflatex stop at a confusing prompt.
    # Test for a WRITE block specifically (share=Read): a viewer that allows
    # writing is not actually in the way.
    if (Test-Path $pdf) {
        try {
            $fs = [System.IO.File]::Open($pdf, 'Open', 'Write', 'Read')
            $fs.Close()
        }
        catch {
            Write-Host "main.pdf is open in another program -- close it and run this again." -ForegroundColor Yellow
            $viewers = Get-Process |
                Where-Object { $_.Name -match 'Acrobat|AcroRd|Foxit|Sumatra|PDFXEdit|Nitro|msedge|chrome|firefox' } |
                Where-Object { $_.Name -notmatch 'Update' } |
                Select-Object -ExpandProperty Name -Unique
            if ($viewers) { Write-Host "  candidates: $($viewers -join ', ')" }
            exit 1
        }
    }

    foreach ($pass in 1, 2) {
        Write-Host "pass $pass with $engine ..."
        & $exe -interaction=nonstopmode main.tex | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=== build failed on pass $pass ===" -ForegroundColor Red
            if (Test-Path $log) {
                Select-String -Path $log -Pattern '^!' -Context 0, 4 |
                    Select-Object -First 5 | ForEach-Object { $_.Line; $_.Context.PostContext }
            } else {
                Write-Host "(no main.log -- $engine may not have started at all)"
            }
            # nonstopmode still writes a PDF containing the error. Remove it, so
            # that nobody opens a broken report thinking the build succeeded.
            if (Test-Path $pdf) {
                Remove-Item $pdf -Force -ErrorAction SilentlyContinue
                Write-Host "removed the broken main.pdf" -ForegroundColor Yellow
            }
            exit 1
        }
    }

    $warn  = @(Select-String -Path $log -Pattern "Overfull|Underfull" -ErrorAction SilentlyContinue)
    $pages = (Select-String -Path $log -Pattern "Output written" -ErrorAction SilentlyContinue).Line

    Write-Host ""
    Write-Host "OK  $pages"
    Write-Host "    overfull/underfull boxes: $($warn.Count)"
    Write-Host "    output: $pdf"

    # The assignment asks for screenshots. Shipping the red placeholder boxes is
    # the easiest way to lose marks, so say so rather than reporting a clean OK.
    $figs = Join-Path (Split-Path -Parent $PSScriptRoot) "figures"
    $need = @("code.png", "Result_Terminal.png") |
            Where-Object { -not (Test-Path (Join-Path $figs $_)) }
    if ($need) {
        Write-Host ""
        Write-Host "WARNING: the PDF still shows placeholder boxes for:" -ForegroundColor Yellow
        $need | ForEach-Object { Write-Host "         figures\$_" }
        Write-Host "         Take those screenshots and build again before submitting."
    }
}
finally {
    Pop-Location
}
