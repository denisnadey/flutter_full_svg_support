import 'w3c_source_loader_stub.dart'
    if (dart.library.io) 'w3c_source_loader_io.dart'
    as impl;

Future<String> loadW3cSvgSource(String suiteRelativePath) {
  return impl.loadW3cSvgSource(suiteRelativePath);
}
