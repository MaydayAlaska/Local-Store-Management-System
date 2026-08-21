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
      $graphics.DrawImage(
        $sourceImage,
        [Drawing.Rectangle]::new(0, 0, $size, $size)
      )

      $pngStream = [IO.MemoryStream]::new()
      try {
        $bitmap.Save($pngStream, [Drawing.Imaging.ImageFormat]::Png)
        $images.Add($pngStream.ToArray())
      } finally {
        $pngStream.Dispose()
      }
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
    "Generated $OutputIco with $($sizes.Count) icon sizes from " +
    "$($sourceImage.Width)x$($sourceImage.Height) source."
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
