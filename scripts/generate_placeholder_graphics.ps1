# Generates placeholder Play Store graphics (app icon + feature graphic) so the
# automated Fastlane upload has something valid to push on day one. Replace the
# output files with real branding whenever you have it — same filenames, same
# folder, no other change needed.
#
# Usage: pwsh scripts/generate_placeholder_graphics.ps1

Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot "..\fastlane\metadata\android\en-US\images"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$bg = [System.Drawing.Color]::FromArgb(255, 63, 81, 181)   # Material Indigo 500
$fg = [System.Drawing.Color]::White

function New-PlaceholderImage($width, $height, $text, $fontSize, $path) {
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($bg)

    $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush($fg)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $width, $height)
    $g.DrawString($text, $font, $brush, $rect, $format)

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Output "Wrote $path ($width x $height)"
}

New-PlaceholderImage 512 512 "IB" 220 (Join-Path $outDir "icon.png")
New-PlaceholderImage 1024 500 "ITMC Bussines OS" 64 (Join-Path $outDir "featureGraphic.png")
