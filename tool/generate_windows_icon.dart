import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_windows_icon.dart <source.base64> <output.ico>',
    );
    exitCode = 64;
    return;
  }

  final sourceFile = File(args[0]);
  final outputFile = File(args[1]);
  final encoded = sourceFile.readAsStringSync().trim();
  final sourceBytes = base64Decode(encoded);
  final sourceImage = img.decodeImage(sourceBytes);
  if (sourceImage == null) {
    throw StateError('Unable to decode the application icon source image.');
  }

  const sizes = <int>[16, 20, 24, 32, 40, 48, 64, 96, 128, 256];
  final images = <Uint8List>[];
  for (final size in sizes) {
    final resized = img.copyResize(sourceImage, width: size, height: size);
    images.add(Uint8List.fromList(img.encodePng(resized)));
  }

  final directorySize = 6 + (16 * sizes.length);
  final directory = ByteData(directorySize);
  directory.setUint16(0, 0, Endian.little);
  directory.setUint16(2, 1, Endian.little);
  directory.setUint16(4, sizes.length, Endian.little);

  var imageOffset = directorySize;
  for (var index = 0; index < sizes.length; index++) {
    final entryOffset = 6 + (16 * index);
    final size = sizes[index];
    final imageBytes = images[index];
    directory.setUint8(entryOffset, size == 256 ? 0 : size);
    directory.setUint8(entryOffset + 1, size == 256 ? 0 : size);
    directory.setUint8(entryOffset + 2, 0);
    directory.setUint8(entryOffset + 3, 0);
    directory.setUint16(entryOffset + 4, 1, Endian.little);
    directory.setUint16(entryOffset + 6, 32, Endian.little);
    directory.setUint32(entryOffset + 8, imageBytes.length, Endian.little);
    directory.setUint32(entryOffset + 12, imageOffset, Endian.little);
    imageOffset += imageBytes.length;
  }

  final builder = BytesBuilder(copy: false)
    ..add(directory.buffer.asUint8List());
  for (final imageBytes in images) {
    builder.add(imageBytes);
  }

  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsBytesSync(builder.takeBytes(), flush: true);
  stdout.writeln(
    'Generated ${outputFile.path} with ${sizes.length} icon sizes from '
    '${sourceImage.width}x${sourceImage.height} source.',
  );
}
