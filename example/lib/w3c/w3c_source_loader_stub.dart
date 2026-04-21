Future<String> loadW3cSvgSource(String suiteRelativePath) async {
  throw UnsupportedError(
    'Local filesystem loading is not supported on this platform: '
    '$suiteRelativePath',
  );
}
