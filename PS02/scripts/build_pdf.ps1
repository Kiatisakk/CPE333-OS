# Build latex/main.pdf with MiKTeX.
#
# Uses pdflatex directly rather than latexmk: latexmk is a Perl script and this
# MiKTeX install has no Perl script engine. Two passes are needed so the table
# of contents and any cross-references resolve.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1
#
# Pass -Xe to build with XeLaTeX instead (needed if you put Thai characters in
# main.tex -- see the switch instructions in latex/preamble.tex).

param([switch]$Xe)

$ErrorActionPreference = "Stop"

$miktex = "C:\Users\kiati\AppData\Local\Programs\MiKTeX\miktex\bin\x64"
$engine = if ($Xe) { "xelatex.exe" } else { "pdflatex.exe" }
$exe = Join-Path $miktex $engine

if (-not (Test-Path $exe)) {
    Write-Error "$engine not found at $miktex -- is MiKTeX installed?"
}

$latexDir = Join-Path (Split-Path -Parent $PSScriptRoot) "latex"
Push-Location $latexDir
try {
    # A PDF viewer holding main.pdf open makes pdflatex fail with a confusing
    # "I can't write on file" prompt. Check for it first and say so plainly.
    $pdf = Join-Path $latexDir "main.pdf"
    if (Test-Path $pdf) {
        try {
            $fs = [System.IO.File]::Open($pdf, 'Open', 'ReadWrite', 'None')
            $fs.Close()
        }
        catch {
            Write-Host "main.pdf is open in another program -- close it and run this again." -ForegroundColor Yellow
            $viewers = Get-Process |
                Where-Object { $_.Name -match 'Acrobat|AcroRd|Foxit|Sumatra|PDFXEdit|Nitro' } |
                Select-Object -ExpandProperty Name -Unique
            if ($viewers) { Write-Host "  likely culprit: $($viewers -join ', ')" }
            exit 1
        }
    }

    foreach ($pass in 1, 2) {
        Write-Host "pass $pass with $engine ..."
        & $exe -interaction=nonstopmode main.tex | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=== build failed on pass $pass ===" -ForegroundColor Red
            Select-String -Path main.log -Pattern '^!' -Context 0, 4 |
                Select-Object -First 5 | ForEach-Object { $_.Line; $_.Context.PostContext }
            exit 1
        }
    }

    $warn = @(Select-String -Path main.log -Pattern "Overfull|Underfull")
    $pages = (Select-String -Path main.log -Pattern "Output written").Line

    Write-Host ""
    Write-Host "OK  $pages"
    Write-Host "    overfull/underfull boxes: $($warn.Count)"
    Write-Host "    output: $(Join-Path $latexDir 'main.pdf')"
}
finally {
    Pop-Location
}
