import 'dart:io';
import 'dart:typed_data';

export 'dart:io' show File;

Future<Uint8List?> readFileBytes(Uri uri) async {
  try {
    final file = File.fromUri(uri);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}
