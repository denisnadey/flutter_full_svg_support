import 'dart:io';

String? _resolvedRootPath;

Future<String> loadW3cSvgSource(String suiteRelativePath) async {
  final normalizedPath = suiteRelativePath.replaceAll('\\', '/');
  final checkedPaths = <String>[];

  if (_resolvedRootPath != null) {
    final fastPath = _resolveWithinRoot(_resolvedRootPath!, normalizedPath);
    if (fastPath != null) {
      return File(fastPath).readAsString();
    }
    checkedPaths.addAll(_pathsWithinRoot(_resolvedRootPath!, normalizedPath));
  }

  final candidateRoots = _candidateRoots();
  for (final root in candidateRoots) {
    final resolved = _resolveWithinRoot(root, normalizedPath);
    if (resolved != null) {
      _resolvedRootPath = root;
      return File(resolved).readAsString();
    }
    checkedPaths.addAll(_pathsWithinRoot(root, normalizedPath));
  }

  final preview = checkedPaths.take(7).join(' | ');
  throw FileSystemException(
    'W3C SVG file not found. Checked ${checkedPaths.length} locations. '
    'Sample: $preview',
    normalizedPath,
  );
}

String? _resolveWithinRoot(String rootPath, String normalizedPath) {
  for (final candidate in _pathsWithinRoot(rootPath, normalizedPath)) {
    final file = File(candidate);
    if (file.existsSync()) {
      return candidate;
    }
  }
  return null;
}

List<String> _pathsWithinRoot(String rootPath, String normalizedPath) {
  final results = <String>{_joinPath(rootPath, normalizedPath)};
  const suitePrefix = 'W3C_SVG_11_TestSuite/';
  if (normalizedPath.startsWith(suitePrefix)) {
    final suiteRelative = normalizedPath.substring(suitePrefix.length);
    results.add(_joinPath(rootPath, suiteRelative));
  }
  return results.toList(growable: false);
}

List<String> _candidateRoots() {
  final roots = <String>{};

  void addAncestors(String startPath, {int maxDepth = 12}) {
    if (startPath.isEmpty) {
      return;
    }
    var cursor = Directory(startPath);
    for (var i = 0; i < maxDepth; i++) {
      final basePath = cursor.path;
      roots.add(basePath);
      final parent = cursor.parent;
      if (parent.path == basePath) {
        break;
      }
      cursor = parent;
    }
  }

  addAncestors(Directory.current.path);

  final pwd = Platform.environment['PWD'];
  if (pwd != null && pwd.isNotEmpty) {
    addAncestors(pwd);
  }

  addAncestors(File(Platform.resolvedExecutable).parent.path);

  try {
    addAncestors(File.fromUri(Platform.script).parent.path);
  } catch (_) {
    // On some platforms Platform.script is not a file URI.
  }

  final repoRootOverride = Platform.environment['FLUTTER_SVG_REPO_ROOT'];
  if (repoRootOverride != null && repoRootOverride.isNotEmpty) {
    addAncestors(repoRootOverride, maxDepth: 2);
  }

  final suiteRootOverride = Platform.environment['W3C_SVG_SUITE_ROOT'];
  if (suiteRootOverride != null && suiteRootOverride.isNotEmpty) {
    addAncestors(suiteRootOverride, maxDepth: 2);
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    addAncestors('$home/apps/flutter_full_svg_support', maxDepth: 2);
    addAncestors('$home/Downloads/flutter_full_svg_support', maxDepth: 2);
    addAncestors('$home/Documents/flutter_full_svg_support', maxDepth: 2);
    addAncestors('$home/Desktop/flutter_full_svg_support', maxDepth: 2);
  }

  return roots.toList(growable: false);
}

String _joinPath(String rootPath, String relativePath) {
  final root = rootPath.endsWith('/')
      ? rootPath.substring(0, rootPath.length - 1)
      : rootPath;
  final relative = relativePath.startsWith('/')
      ? relativePath.substring(1)
      : relativePath;
  return '$root/$relative';
}
