import 'dart:convert';
import 'dart:io';

class W3cManifestEntry {
  const W3cManifestEntry({
    required this.name,
    required this.category,
    required this.svgPath,
    required this.pngPath,
    required this.viewBox,
  });

  final String name;
  final String category;
  final String svgPath;
  final String pngPath;
  final String viewBox;

  factory W3cManifestEntry.fromJson(Map<String, dynamic> json) {
    return W3cManifestEntry(
      name: json['name'] as String,
      category: json['category'] as String,
      svgPath: json['svgPath'] as String,
      pngPath: json['pngPath'] as String,
      viewBox: json['viewBox'] as String,
    );
  }
}

class W3cManifest {
  const W3cManifest({
    required this.generatedAt,
    required this.selectedCount,
    required this.entries,
  });

  final String generatedAt;
  final int selectedCount;
  final List<W3cManifestEntry> entries;

  factory W3cManifest.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const [];
    final entries = rawEntries
        .cast<Map<String, dynamic>>()
        .map(W3cManifestEntry.fromJson)
        .toList(growable: false);

    return W3cManifest(
      generatedAt: json['generatedAt'] as String? ?? '',
      selectedCount: json['selectedCount'] as int? ?? entries.length,
      entries: entries,
    );
  }
}

W3cManifest loadW3cManifest(String manifestPath) {
  final file = File(manifestPath);
  if (!file.existsSync()) {
    throw StateError('W3C manifest not found: $manifestPath');
  }

  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid W3C manifest format: $manifestPath');
  }

  return W3cManifest.fromJson(decoded);
}
