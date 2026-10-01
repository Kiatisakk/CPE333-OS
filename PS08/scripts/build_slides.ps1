# Generate slides/PS08.pptx from results/ and export slides/PS08.pdf with
# PowerPoint.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_slides.ps1
#
# Pass -Pptx <file> to export some other deck to PDF without regenerating.

param([string]$Pptx)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $Pptx) {
    python (Join-Path $PSScriptRoot "make_slides.py")
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $Pptx = Join-Path $root "slides\PS08.pptx"
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

$app = New-Object -ComObject PowerPoint.Application
try {
    # ReadOnly, Untitled = false, WithWindow = false
    $deck = $app.Presentations.Open($Pptx, $true, $false, $false)
    $deck.SaveAs($pdf, 32)   # 32 = ppSaveAsPDF
    $deck.Close()
}
finally {
    $app.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($app)
}
Write-Host "wrote $pdf"
