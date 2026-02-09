# generate-icon.ps1
# Generates app.ico with blue background (#1E40AF) + white bold "N" (Segoe UI)
# Sizes: 256px (PNG-compressed) + 48px, 32px, 16px (BMP)
# Requires: .NET System.Drawing (Windows)
#
# Usage: powershell -ExecutionPolicy Bypass -File generate-icon.ps1

Add-Type -AssemblyName System.Drawing

function New-IconBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # Blue background
    $bgColor = [System.Drawing.Color]::FromArgb(0x1E, 0x40, 0xAF)
    $g.Clear($bgColor)

    # White bold "N"
    $fontSize = $size * 0.65
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.Brushes]::White
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $g.DrawString("N", $font, $brush, $rect, $sf)

    $sf.Dispose()
    $font.Dispose()
    $g.Dispose()
    return $bmp
}

function ConvertTo-BmpIconEntry([System.Drawing.Bitmap]$bmp) {
    # ICO BMP format: BITMAPINFOHEADER (40 bytes) + pixel data (BGRA bottom-up) + AND mask
    $size = $bmp.Width
    $headerSize = 40
    $pixelDataSize = $size * $size * 4
    $andMaskRowBytes = [Math]::Ceiling($size / 8)
    # Rows are padded to 4-byte boundary
    $andMaskRowPadded = [Math]::Ceiling($andMaskRowBytes / 4) * 4
    $andMaskSize = $andMaskRowPadded * $size

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # BITMAPINFOHEADER
    $bw.Write([int]$headerSize)        # biSize
    $bw.Write([int]$size)              # biWidth
    $bw.Write([int]($size * 2))        # biHeight (doubled for ICO: XOR + AND)
    $bw.Write([short]1)               # biPlanes
    $bw.Write([short]32)              # biBitCount
    $bw.Write([int]0)                 # biCompression (BI_RGB)
    $bw.Write([int]($pixelDataSize + $andMaskSize)) # biSizeImage
    $bw.Write([int]0)                 # biXPelsPerMeter
    $bw.Write([int]0)                 # biYPelsPerMeter
    $bw.Write([int]0)                 # biClrUsed
    $bw.Write([int]0)                 # biClrImportant

    # Pixel data (BGRA, bottom-up)
    for ($y = $size - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $size; $x++) {
            $pixel = $bmp.GetPixel($x, $y)
            $bw.Write([byte]$pixel.B)
            $bw.Write([byte]$pixel.G)
            $bw.Write([byte]$pixel.R)
            $bw.Write([byte]$pixel.A)
        }
    }

    # AND mask (all zeros = fully opaque)
    $zeros = New-Object byte[] $andMaskSize
    $bw.Write($zeros)

    $bw.Flush()
    $data = $ms.ToArray()
    $bw.Dispose()
    $ms.Dispose()
    return $data
}

function ConvertTo-PngIconEntry([System.Drawing.Bitmap]$bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $data = $ms.ToArray()
    $ms.Dispose()
    return $data
}

# Generate bitmaps
$sizes = @(256, 48, 32, 16)
$bitmaps = @{}
foreach ($s in $sizes) {
    $bitmaps[$s] = New-IconBitmap $s
}

# Build ICO file
$entries = @()
# 256px as PNG, rest as BMP
$entries += @{ Size = 256; Data = (ConvertTo-PngIconEntry $bitmaps[256]) }
$entries += @{ Size = 48;  Data = (ConvertTo-BmpIconEntry $bitmaps[48]) }
$entries += @{ Size = 32;  Data = (ConvertTo-BmpIconEntry $bitmaps[32]) }
$entries += @{ Size = 16;  Data = (ConvertTo-BmpIconEntry $bitmaps[16]) }

$icoPath = Join-Path $PSScriptRoot "app.ico"
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICO header
$bw.Write([short]0)                    # Reserved
$bw.Write([short]1)                    # Type (1 = ICO)
$bw.Write([short]$entries.Count)       # Number of images

# Calculate offsets: header(6) + directory(16 * count) = data start
$dataOffset = 6 + 16 * $entries.Count

# Write directory entries
foreach ($entry in $entries) {
    $s = $entry.Size
    $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))  # Width (0 = 256)
    $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))  # Height (0 = 256)
    $bw.Write([byte]0)                # Color palette count
    $bw.Write([byte]0)                # Reserved
    $bw.Write([short]1)               # Color planes
    $bw.Write([short]32)              # Bits per pixel
    $bw.Write([int]$entry.Data.Length) # Size of image data
    $bw.Write([int]$dataOffset)       # Offset to image data
    $dataOffset += $entry.Data.Length
}

# Write image data
foreach ($entry in $entries) {
    $bw.Write($entry.Data)
}

$bw.Flush()
$bw.Dispose()
$fs.Dispose()

# Cleanup
foreach ($bmp in $bitmaps.Values) { $bmp.Dispose() }

Write-Host "Created: $icoPath"
