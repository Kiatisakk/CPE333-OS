param(
    [string]$Pptx = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build_algorithm\candidate.pptx'),
    [string]$RenderDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build_algorithm\render-v1')
)
$ErrorActionPreference = 'Stop'
$candidatePath = (Resolve-Path -LiteralPath $Pptx).Path
$renderRoot = [System.IO.Path]::GetFullPath($RenderDirectory)
New-Item -ItemType Directory -Path $renderRoot -Force | Out-Null
$candidatePdf = Join-Path $renderRoot 'candidate.pdf'
$checkedPptx = Join-Path $renderRoot 'candidate_checked.pptx'
$alreadyRunning = @(Get-Process POWERPNT -ErrorAction SilentlyContinue).Count -gt 0
$powerPointApp = New-Object -ComObject PowerPoint.Application
$originalAlerts = $powerPointApp.DisplayAlerts
$presentation = $null
try {
    $powerPointApp.DisplayAlerts = 1
    $presentation = $powerPointApp.Presentations.Open($candidatePath, $true, $false, $false)
    if ($presentation.Slides.Count -ne 19) { throw 'Expected 19 slides' }
    $presentation.SaveAs($checkedPptx, 24)
    $presentation.SaveAs($candidatePdf, 32)
    $presentation.Export($renderRoot, 'PNG', 1600, 900)
    $overflow = @()
    foreach ($slide in $presentation.Slides) {
        foreach ($shape in $slide.Shapes) {
            if ($shape.HasTextFrame -eq -1 -and $shape.TextFrame.HasText -eq -1) {
                $textFrame = $shape.TextFrame2
                $availableHeight = $shape.Height - $textFrame.MarginTop - $textFrame.MarginBottom
                $availableWidth = $shape.Width - $textFrame.MarginLeft - $textFrame.MarginRight
                if ($textFrame.TextRange.BoundHeight -gt ($availableHeight + 3) -or $textFrame.TextRange.BoundWidth -gt ($availableWidth + 3)) {
                    $overflow += [pscustomobject]@{ Slide=$slide.SlideIndex; Shape=$shape.Name; Text=$shape.TextFrame.TextRange.Text; BoundHeight=$textFrame.TextRange.BoundHeight; AvailableHeight=$availableHeight; BoundWidth=$textFrame.TextRange.BoundWidth; AvailableWidth=$availableWidth }
                }
            }
            if ($shape.HasTable -eq -1) {
                foreach ($row in $shape.Table.Rows) {
                    foreach ($cell in $row.Cells) {
                        $textFrame = $cell.Shape.TextFrame2
                        $availableHeight = $cell.Shape.Height - $textFrame.MarginTop - $textFrame.MarginBottom
                        $availableWidth = $cell.Shape.Width - $textFrame.MarginLeft - $textFrame.MarginRight
                        if ($textFrame.TextRange.BoundHeight -gt ($availableHeight + 3) -or $textFrame.TextRange.BoundWidth -gt ($availableWidth + 3)) {
                            $overflow += [pscustomobject]@{ Slide=$slide.SlideIndex; Shape='Table cell'; Text=$cell.Shape.TextFrame.TextRange.Text; BoundHeight=$textFrame.TextRange.BoundHeight; AvailableHeight=$availableHeight; BoundWidth=$textFrame.TextRange.BoundWidth; AvailableWidth=$availableWidth }
                        }
                    }
                }
            }
        }
    }
    ConvertTo-Json -InputObject @($overflow) -Depth 4 | Set-Content -LiteralPath (Join-Path $renderRoot 'overflow.json') -Encoding UTF8
    Write-Output ('Rendered slides: ' + $presentation.Slides.Count)
    Write-Output ('Text fit findings: ' + $overflow.Count)
    Write-Output $candidatePdf
    Write-Output $checkedPptx
    if ($overflow.Count -gt 0) { throw 'Text does not fit. Review overflow.json before publishing.' }
}
finally {
    if ($null -ne $presentation) { $presentation.Close() }
    $powerPointApp.DisplayAlerts = $originalAlerts
    if (-not $alreadyRunning) { $powerPointApp.Quit() }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($powerPointApp)
}
