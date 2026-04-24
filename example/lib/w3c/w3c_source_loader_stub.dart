import 'dart:typed_data';

Future<String> loadW3cSvgSource(String suiteRelativePath) async {
  throw UnsupportedError(
    'Local filesystem loading is not supported on this platform: '
    '$suiteRelativePath',
  );
}

Future<Uint8List?> loadW3cResourceBytes({
  required String baseSvgPath,
  required String href,
}) async {
  return null;
}
