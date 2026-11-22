# Generate the algorithm-analysis deck and PDF with editable tables and notes.
# The original slides/PS08.pptx is retained as the design source.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_slides.ps1
#
# Pass -Pptx <file> to export some other deck to PDF without regenerating.

param([string]$Pptx)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $Pptx) {
    $runDirectory = Join-Path $root ('.build_algorithm\run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
    $candidate = Join-Path $runDirectory 'candidate.pptx'
    python (Join-Path $PSScriptRoot 'make_algorithm_slides.py') --output $candidate
    if ($LASTEXITCODE -ne 0) { throw 'Slide generation failed' }
    $renderDirectory = Join-Path $runDirectory 'render'
    & (Join-Path $PSScriptRoot 'render_algorithm_slides.ps1') -Pptx $candidate -RenderDirectory $renderDirectory
    $outputPptx = Join-Path $root 'slides\PS08_Algorithm_Analysis.pptx'
    $outputPdf = [System.IO.Path]::ChangeExtension($outputPptx, '.pdf')
    Copy-Item -LiteralPath (Join-Path $renderDirectory 'candidate_checked.pptx') -Destination $outputPptx -Force
    Copy-Item -LiteralPath (Join-Path $renderDirectory 'candidate.pdf') -Destination $outputPdf -Force
    Write-Host "wrote $outputPptx"
    Write-Host "wrote $outputPdf"
    return
}
$Pptx = (Resolve-Path $Pptx).Path
$pdf = [System.IO.Path]::ChangeExtension($Pptx, ".pdf")

# A viewer holding the PDF open makes SaveAs fail with an opaque COM error.
if (Test-Path $pdf) {
    try { $fs = [System.IO.File]::Open($pdf, 'Open', 'Write', 'Read'); $fs.Close() }
    catch {
        Write-Host "$pdf is open in another program -- close it and run this again." -ForegroundColor Yellow
        exit 1
    }
}

$alreadyRunning = @(Get-Process POWERPNT -ErrorAction SilentlyContinue).Count -gt 0
$app = New-Object -ComObject PowerPoint.Application
$deck = $null
try {
    # ReadOnly, Untitled = false, WithWindow = false
    $deck = $app.Presentations.Open($Pptx, $true, $false, $false)
    $deck.SaveAs($pdf, 32)   # 32 = ppSaveAsPDF
}
finally {
    if ($null -ne $deck) { $deck.Close() }
    if (-not $alreadyRunning) { $app.Quit() }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($app)
}
Write-Host "wrote $pdf"
