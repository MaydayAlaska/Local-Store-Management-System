import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_windows_icon.dart <source.base64> <output.ico>',
    );
    exitCode = 64;
    return;
  }

  if (!Platform.isWindows) {
    throw UnsupportedError('Windows icon generation must run on Windows.');
  }

  final sourceFile = File(args[0]).absolute;
  if (!sourceFile.existsSync()) {
    throw StateError('Application icon source not found: ${sourceFile.path}');
  }

  final outputFile = File(args[1]).absolute;
  outputFile.parent.createSync(recursive: true);

  final script = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'lsms-generate-icon-$pid.ps1',
  );

  script.writeAsStringSync(r'''
param(
  [Parameter(Mandatory=$true)][string]$SourceBase64,
  [Parameter(Mandatory=$true)][string]$OutputIco
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-IcoDibBytes {
  param(
    [Parameter(Mandatory=$true)][Drawing.Bitmap]$Bitmap
  )

  $width = $Bitmap.Width
  $height = $Bitmap.Height
  $xorStride = $width * 4
  $andStride = [int](([Math]::Ceiling($width / 32.0)) * 4)
  $xorSize = $xorStride * $height

  $stream = [IO.MemoryStream]::new()
  $writer = [IO.BinaryWriter]::new($stream)
  try {
    # BITMAPINFOHEADER. ICO stores XOR + AND masks in one DIB, therefore
    # biHeight is twice the visible image height.
    $writer.Write([UInt32]40)
    $writer.Write([Int32]$width)
    $writer.Write([Int32]($height * 2))
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]0)
    $writer.Write([UInt32]$xorSize)
    $writer.Write([Int32]0)
    $writer.Write([Int32]0)
    $writer.Write([UInt32]0)
    $writer.Write([UInt32]0)

    # 32-bit BGRA pixels, bottom-up as required by the ICO DIB format.
    for ($y = $height - 1; $y -ge 0; $y--) {
      for ($x = 0; $x -lt $width; $x++) {
        $pixel = $Bitmap.GetPixel($x, $y)
        $writer.Write([Byte]$pixel.B)
        $writer.Write([Byte]$pixel.G)
        $writer.Write([Byte]$pixel.R)
        $writer.Write([Byte]$pixel.A)
      }
    }

    # Legacy 1-bit AND mask. Transparent pixels are marked as transparent;
    # opaque/semitransparent pixels rely on the alpha channel above.
    for ($y = $height - 1; $y -ge 0; $y--) {
      $row = New-Object byte[] $andStride
      for ($x = 0; $x -lt $width; $x++) {
        $pixel = $Bitmap.GetPixel($x, $y)
        if ($pixel.A -eq 0) {
          # Do not cast x / 8 to [int]: PowerShell rounds instead of truncating,
          # which can produce an out-of-range index at widths such as 32 px.
          $byteIndex = $x -shr 3
          $bitIndex = 7 - ($x -band 7)
          $row[$byteIndex] = $row[$byteIndex] -bor (1 -shl $bitIndex)
        }
      }
      $writer.Write($row)
    }

    $writer.Flush()
    return $stream.ToArray()
  } finally {
    $writer.Dispose()
    $stream.Dispose()
  }
}

$encoded = (Get-Content -Raw -LiteralPath $SourceBase64).Trim()
$sourceBytes = [Convert]::FromBase64String($encoded)
$sourceStream = [IO.MemoryStream]::new($sourceBytes, $false)
$sourceImage = $null
$images = [System.Collections.Generic.List[byte[]]]::new()
$sizes = @(16, 20, 24, 32, 40, 48, 64, 96, 128, 256)

try {
  $sourceImage = [Drawing.Image]::FromStream($sourceStream, $true, $true)

  foreach ($size in $sizes) {
    $bitmap = [Drawing.Bitmap]::new(
      $size,
      $size,
      [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
      $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.Clear([Drawing.Color]::Transparent)

      # Preserve the complete source image without cropping or stretching.
      $scale = [Math]::Min(
        $size / [double]$sourceImage.Width,
        $size / [double]$sourceImage.Height
      )
      $drawWidth = [Math]::Max(1, [int][Math]::Round($sourceImage.Width * $scale))
      $drawHeight = [Math]::Max(1, [int][Math]::Round($sourceImage.Height * $scale))
      $left = [int](($size - $drawWidth) / 2)
      $top = [int](($size - $drawHeight) / 2)

      $graphics.DrawImage(
        $sourceImage,
        [Drawing.Rectangle]::new($left, $top, $drawWidth, $drawHeight)
      )

      # Use classic DIB-backed ICO entries instead of PNG-compressed entries.
      # Inno Setup and Windows Explorer handle these consistently at small sizes.
      $images.Add((New-IcoDibBytes -Bitmap $bitmap))
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  }

  $directorySize = 6 + (16 * $sizes.Count)
  $file = [IO.File]::Open(
    $OutputIco,
    [IO.FileMode]::Create,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
  )
  $writer = [IO.BinaryWriter]::new($file)
  try {
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$sizes.Count)

    $imageOffset = $directorySize
    for ($i = 0; $i -lt $sizes.Count; $i++) {
      $size = $sizes[$i]
      $imageBytes = $images[$i]
      $writer.Write([Byte]$(if ($size -eq 256) { 0 } else { $size }))
      $writer.Write([Byte]$(if ($size -eq 256) { 0 } else { $size }))
      $writer.Write([Byte]0)
      $writer.Write([Byte]0)
      $writer.Write([UInt16]1)
      $writer.Write([UInt16]32)
      $writer.Write([UInt32]$imageBytes.Length)
      $writer.Write([UInt32]$imageOffset)
      $imageOffset += $imageBytes.Length
    }

    foreach ($imageBytes in $images) {
      $writer.Write($imageBytes)
    }
    $writer.Flush()
  } finally {
    $writer.Dispose()
    $file.Dispose()
  }

  Write-Host (
    "Generated Windows-compatible DIB ICO $OutputIco with $($sizes.Count) sizes " +
    "from $($sourceImage.Width)x$($sourceImage.Height) source."
  )
} finally {
  if ($null -ne $sourceImage) { $sourceImage.Dispose() }
  $sourceStream.Dispose()
}
''', flush: true);

  try {
    final result = Process.runSync(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-SourceBase64',
        sourceFile.path,
        '-OutputIco',
        outputFile.path,
      ],
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );

    if (result.stdout.toString().trim().isNotEmpty) {
      stdout.writeln(result.stdout.toString().trim());
    }
    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      throw StateError(
        'Unable to generate Windows icon (exit ${result.exitCode})'
        '${error.isEmpty ? '' : ': $error'}',
      );
    }
    if (!outputFile.existsSync() || outputFile.lengthSync() <= 22) {
      throw StateError('Windows icon generation produced an invalid output file.');
    }
  } finally {
    try {
      if (script.existsSync()) script.deleteSync();
    } catch (_) {}
  }
}
