import 'dart:typed_data';

import 'w3c_source_loader_stub.dart'
    if (dart.library.io) 'w3c_source_loader_io.dart'
    as impl;

Future<String> loadW3cSvgSource(String suiteRelativePath) {
  return impl.loadW3cSvgSource(suiteRelativePath);
}

Future<Uint8List?> loadW3cResourceBytes({
  required String baseSvgPath,
  required String href,
}) {
  return impl.loadW3cResourceBytes(baseSvgPath: baseSvgPath, href: href);
}
