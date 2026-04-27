// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@Tags(['golden', 'w3c_golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/flutter_svg.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:xml/xml.dart';

import '../../tool/golden_capture/image_compare.dart';

const String kManifestPath = 'tool/w3c_goldens/w3c_manifest.json';
const String kBrowserGoldensDir = 'test/goldens/w3c/browser';
const String kFlutterGoldensDir = 'test/goldens/w3c/flutter';
const String kDiffOutputDir = 'test/goldens/w3c/diff';
const String kReportsDir = 'test/goldens/w3c/reports';

const double kViewportWidth = 800.0;
const double kViewportHeight = 600.0;

const Timeout kW3cTimeout = Timeout(Duration(seconds: 75));
const double kSimilarityOptimizationRetryCutoff = 0.95;

const Map<String, String> _systemColorFallbacks = <String, String>{
  'ActiveBorder': '#000000',
  'ActiveCaption': '#000000',
  'AppWorkspace': '#DCDCDC',
  'Background': '#DCDCDC',
  'ButtonFace': '#F0F0F0',
  'ButtonHighlight': '#FFFFFF',
  'ButtonShadow': '#A0A0A0',
  'ButtonText': '#000000',
  'CaptionText': '#FFFFFF',
  'GrayText': '#6D6D6D',
  'Highlight': '#0A246A',
  'HighlightText': '#FFFFFF',
  'InactiveBorder': '#808080',
  'InactiveCaption': '#808080',
  'InactiveCaptionText': '#FFFFFF',
  'InfoBackground': '#FFFFE1',
  'InfoText': '#000000',
  'Menu': '#FFFFFF',
  'MenuText': '#000000',
  'Scrollbar': '#D4D0C8',
  'ThreeDDarkShadow': '#000000',
  'ThreeDFace': '#DCDCDC',
  'ThreeDHighlight': '#FFFFFF',
  'ThreeDLightShadow': '#FFFFFF',
  'ThreeDShadow': '#808080',
  'Window': '#FFFFFF',
  'WindowFrame': '#000000',
  'WindowText': '#000000',
};

const Set<String> _genericFontFamilies = <String>{
  'serif',
  'sans-serif',
  'monospace',
  'cursive',
  'fantasy',
  'system-ui',
  'ui-serif',
  'ui-sans-serif',
  'ui-monospace',
};

const Map<String, String> _knownFontFamilyFallbacks = <String, String>{
  'arial': 'Arial',
  'helvetica': 'Helvetica',
  'verdana': 'Verdana',
  'tahoma': 'Tahoma',
  'georgia': 'Georgia',
  'times': 'Times New Roman',
  'times new roman': 'Times New Roman',
  'courier': 'Courier New',
  'courier new': 'Courier New',
};

const Set<String> _supportedSwitchFeaturesForSanitizer = <String>{
  'http://www.w3.org/tr/svg11/feature#svg',
  'http://www.w3.org/tr/svg11/feature#svg-static',
  'http://www.w3.org/tr/svg11/feature#basicstructure',
  'http://www.w3.org/tr/svg11/feature#basictext',
  'http://www.w3.org/tr/svg11/feature#shape',
  'http://www.w3.org/tr/svg11/feature#conditionalprocessing',
  'http://www.w3.org/tr/svg11/feature#svgdom',
  '#svg',
  '#svg-static',
  '#basicstructure',
  '#basictext',
  '#shape',
  '#conditionalprocessing',
  '#svgdom',
  'svg',
  'svg-static',
  'basicstructure',
  'basictext',
  'shape',
  'conditionalprocessing',
  'svgdom',
};

final String _tierFilter = (Platform.environment['W3C_TIER'] ?? 'smoke')
    .trim()
    .toLowerCase();

final String? _caseFilter =
    (Platform.environment['W3C_CASE'] ?? '').trim().isEmpty
    ? null
    : (Platform.environment['W3C_CASE'] ?? '').trim();

final int? _limitFilter = int.tryParse(
  (Platform.environment['W3C_LIMIT'] ?? '').trim(),
);

final bool _includeSkipped =
    (Platform.environment['W3C_INCLUDE_SKIPPED'] ?? '').trim().toLowerCase() ==
    'true';

final bool _enableRender =
    (Platform.environment['W3C_ENABLE_RENDER'] ?? '').trim().toLowerCase() ==
    'true';

final bool _enforceThreshold =
    (Platform.environment['W3C_ENFORCE_THRESHOLD'] ?? 'true')
        .trim()
        .toLowerCase() !=
    'false';

final bool _debugTrace =
    (Platform.environment['W3C_DEBUG_TRACE'] ?? '').trim().toLowerCase() ==
    'true';

final bool _useAnimatedRenderer =
    (Platform.environment['W3C_USE_ANIMATED_RENDERER'] ?? 'false')
        .trim()
        .toLowerCase() !=
    'false';

final String _reportJsonPath =
    (Platform.environment['W3C_REPORT_JSON'] ??
            '$kReportsDir/w3c_latest_report.json')
        .trim();

final List<Map<String, dynamic>> _caseResults = <Map<String, dynamic>>[];

void _trace(String message) {
  if (!_debugTrace) {
    return;
  }
  // ignore: avoid_print
  print('  [trace] $message');
}

class W3cCase {
  W3cCase({
    required this.id,
    required this.category,
    required this.svgPath,
    required this.tier,
    required this.threshold,
    required this.perPixelThreshold,
    required this.animationTimeMs,
    required this.skip,
    required this.skipReason,
    required this.flags,
  });

  factory W3cCase.fromJson(Map<String, dynamic> json) {
    return W3cCase(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'unknown',
      svgPath: json['svgPath'] as String,
      tier: json['tier'] as String? ?? 'extended',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.10,
      perPixelThreshold:
          (json['perPixelThreshold'] as num?)?.toDouble() ?? 0.20,
      animationTimeMs: (json['animationTimeMs'] as num?)?.toInt() ?? 0,
      skip: json['skip'] as bool? ?? false,
      skipReason: json['skipReason'] as String?,
      flags: (json['flags'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String id;
  final String category;
  final String svgPath;
  final String tier;
  final double threshold;
  final double perPixelThreshold;
  final int animationTimeMs;
  final bool skip;
  final String? skipReason;
  final Map<String, dynamic> flags;
}

class _RenderAttempt {
  const _RenderAttempt({
    required this.useAnimatedRenderer,
    required this.variantLabel,
    required this.flutterPng,
    required this.result,
    this.message,
  });

  final bool useAnimatedRenderer;
  final String variantLabel;
  final Uint8List? flutterPng;
  final ImageCompareResult? result;
  final String? message;

  bool get isSuccess =>
      flutterPng != null &&
      result != null &&
      result!.totalPixels > 0 &&
      message == null;
}

void _recordResult(
  W3cCase testCase,
  String status,
  Stopwatch stopwatch, {
  double? similarity,
  int? totalPixels,
  int? differentPixels,
  String? message,
  String? note,
}) {
  _caseResults.add(<String, dynamic>{
    'id': testCase.id,
    'category': testCase.category,
    'tier': testCase.tier,
    'status': status,
    'threshold': testCase.threshold,
    'perPixelThreshold': testCase.perPixelThreshold,
    'animationTimeMs': testCase.animationTimeMs,
    'similarity': similarity,
    'totalPixels': totalPixels,
    'differentPixels': differentPixels,
    'message': message,
    'note': note,
    'elapsedMs': stopwatch.elapsedMilliseconds,
    'svgPath': testCase.svgPath,
    'flags': testCase.flags,
  });
}

List<W3cCase> _loadManifestCases() {
  final manifestFile = File(kManifestPath);
  if (!manifestFile.existsSync()) {
    throw StateError(
      'Manifest not found at $kManifestPath. '
      'Run: node tool/w3c_goldens/generate_manifest.js',
    );
  }

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final rawCases = manifest['cases'];

  if (rawCases is! List) {
    throw StateError(
      'Manifest at $kManifestPath does not contain a valid cases list.',
    );
  }

  return rawCases
      .whereType<Map<String, dynamic>>()
      .map(W3cCase.fromJson)
      .toList();
}

List<W3cCase> _selectCases(List<W3cCase> allCases) {
  var selected = List<W3cCase>.from(allCases);

  if (_tierFilter != 'all') {
    selected = selected.where((c) => c.tier == _tierFilter).toList();
  }

  if (_caseFilter != null) {
    selected = selected.where((c) => c.id == _caseFilter).toList();
  }

  if (!_includeSkipped) {
    selected = selected.where((c) => !c.skip).toList();
  }

  selected.sort((a, b) => a.id.compareTo(b.id));

  if (_limitFilter != null &&
      _limitFilter! > 0 &&
      selected.length > _limitFilter!) {
    selected = selected.take(_limitFilter!).toList();
  }

  return selected;
}

String _sanitizeSvgForFlutter(String svgString) {
  var sanitized = _expandInternalEntities(svgString);

  // Remove W3C metadata block that is not part of visual output.
  sanitized = sanitized.replaceAll(
    RegExp(r'<d:SVGTestCase[\s\S]*?</d:SVGTestCase>', caseSensitive: false),
    '',
  );

  // Remove internal-subset DOCTYPE blocks after entity expansion.
  sanitized = sanitized.replaceAll(
    RegExp(r'<!DOCTYPE[\s\S]*?\]\s*>', caseSensitive: false),
    '',
  );

  // Remove simple DOCTYPE declarations without an internal subset.
  sanitized = sanitized.replaceAll(
    RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false),
    '',
  );

  // Drop external font/resource refs to avoid loading stalls in test runtime.
  sanitized = sanitized.replaceAll(
    RegExp(r'<font-face\b[\s\S]*?</font-face>', caseSensitive: false),
    '',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'<font\b[\s\S]*?</font>', caseSensitive: false),
    '',
  );

  // Drop remaining elements that still point to external resources.
  sanitized = sanitized.replaceAll(
    RegExp(
      r'<[^>]+(?:xlink:href|href)="\.\./resources/[^"]+"[^>]*>',
      caseSensitive: false,
    ),
    '',
  );

  // Drop any unresolved custom entities to avoid parser crashes.
  sanitized = sanitized.replaceAllMapped(RegExp(r'&([A-Za-z_][\w.:-]*);'), (
    match,
  ) {
    const xmlBuiltins = <String>{'amp', 'lt', 'gt', 'quot', 'apos'};
    final name = match.group(1);
    if (name != null && xmlBuiltins.contains(name)) {
      return match.group(0)!;
    }
    return '';
  });

  sanitized = _replaceSystemColorKeywords(sanitized);
  sanitized = _normalizeFontFamilyFallbacks(sanitized);
  sanitized = _normalizeHrefAttributes(sanitized);
  sanitized = _normalizeDataImageMimeTypes(sanitized);
  sanitized = _resolveSwitchElements(sanitized);
  sanitized = _normalizeRootSvgDimensions(sanitized);

  return sanitized;
}

String _replaceSystemColorKeywords(String svgString) {
  var normalized = svgString;
  for (final entry in _systemColorFallbacks.entries) {
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false),
      (_) => entry.value,
    );
  }
  return normalized;
}

String _normalizeDataImageMimeTypes(String svgString) {
  return svgString.replaceAllMapped(
    RegExp(r'data:image/jpg\b', caseSensitive: false),
    (_) => 'data:image/jpeg',
  );
}

String _normalizeHrefAttributes(String svgString) {
  return svgString.replaceAllMapped(
    RegExp(r'\bxlink:href\b', caseSensitive: false),
    (_) => 'href',
  );
}

String _normalizeFontFamilyFallbacks(String svgString) {
  var normalized = svgString;

  normalized = normalized.replaceAllMapped(
    RegExp(r'''font-family\s*=\s*"([^"]*)"''', caseSensitive: false),
    (match) =>
        'font-family="${_normalizeFontFamilyList(match.group(1) ?? '')}"',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r"font-family\s*=\s*'([^']*)'", caseSensitive: false),
    (match) =>
        "font-family='${_normalizeFontFamilyList(match.group(1) ?? '')}'",
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'font-family\s*:\s*([^;}{]+)', caseSensitive: false),
    (match) => 'font-family: ${_normalizeFontFamilyList(match.group(1) ?? '')}',
  );

  return normalized;
}

String _normalizeFontFamilyList(String rawList) {
  final parts = rawList
      .split(',')
      .map((part) => part.trim())
      .map(_stripOuterQuotes)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  final resolvedFamilies = <String>[];
  for (final family in parts) {
    final normalized = family.toLowerCase();
    if (_genericFontFamilies.contains(normalized)) {
      resolvedFamilies.add(normalized);
      continue;
    }

    final fallback = _knownFontFamilyFallbacks[normalized];
    if (fallback != null) {
      resolvedFamilies.add(fallback);
      continue;
    }
  }

  if (resolvedFamilies.isEmpty) {
    return 'sans-serif';
  }

  return resolvedFamilies.toSet().join(', ');
}

String _stripOuterQuotes(String value) {
  var normalized = value.trim();
  while (normalized.length >= 2 &&
      ((normalized.startsWith('"') && normalized.endsWith('"')) ||
          (normalized.startsWith("'") && normalized.endsWith("'")))) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }
  return normalized;
}

String _resolveSwitchElements(String svgString) {
  try {
    final document = XmlDocument.parse(svgString);
    final switchNodes = document.findAllElements('switch').toList();
    if (switchNodes.isEmpty) {
      return svgString;
    }

    final localeRaw = Platform.localeName.trim().toLowerCase().replaceAll(
      '_',
      '-',
    );
    final languageCode = localeRaw.split('-').first;
    final localeCandidates = <String>{
      if (localeRaw.isNotEmpty) localeRaw,
      if (languageCode.isNotEmpty) languageCode,
    };

    for (final switchNode in switchNodes) {
      final parent = switchNode.parent;
      if (parent == null) {
        continue;
      }

      final selected = _selectSwitchChild(switchNode, localeCandidates);
      final switchIndex = parent.children.indexOf(switchNode);
      if (switchIndex < 0) {
        continue;
      }

      if (selected == null) {
        parent.children.removeAt(switchIndex);
        continue;
      }

      final replacementAttributes = switchNode.attributes
          .map(
            (attribute) => XmlAttribute(
              XmlName(attribute.name.local, attribute.name.prefix),
              attribute.value,
            ),
          )
          .toList(growable: false);
      final replacement = XmlElement(
        XmlName('g'),
        replacementAttributes,
        <XmlNode>[selected.copy()],
      );
      parent.children.insert(switchIndex, replacement);
      parent.children.remove(switchNode);
    }

    return document.toXmlString();
  } catch (_) {
    return svgString;
  }
}

XmlElement? _selectSwitchChild(
  XmlElement switchNode,
  Set<String> localeCandidates,
) {
  for (final child in switchNode.childElements) {
    if (_matchesSwitchConditions(child, localeCandidates)) {
      return child;
    }
  }
  return null;
}

bool _matchesSwitchConditions(XmlElement node, Set<String> localeCandidates) {
  final requiredExtensions = _parseSwitchTokenList(
    node.getAttribute('requiredExtensions'),
  );
  if (requiredExtensions.isNotEmpty) {
    return false;
  }

  final requiredFeatures = _parseSwitchTokenList(
    node.getAttribute('requiredFeatures'),
  );
  if (requiredFeatures.isNotEmpty &&
      requiredFeatures.any(
        (feature) => !_supportedSwitchFeaturesForSanitizer.contains(feature),
      )) {
    return false;
  }

  final systemLanguages = _parseSwitchTokenList(
    node.getAttribute('systemLanguage'),
    separator: RegExp(r'[\s,]+'),
  );
  if (systemLanguages.isEmpty) {
    return true;
  }

  for (final language in systemLanguages) {
    if (_matchesSwitchLanguage(language, localeCandidates)) {
      return true;
    }
  }
  return false;
}

List<String> _parseSwitchTokenList(Object? rawValue, {Pattern? separator}) {
  final raw = rawValue?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return const <String>[];
  }
  return raw
      .split(separator ?? RegExp(r'[\s,]+'))
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

bool _matchesSwitchLanguage(String language, Set<String> localeCandidates) {
  for (final locale in localeCandidates) {
    if (locale == language ||
        locale.startsWith('$language-') ||
        language.startsWith('$locale-')) {
      return true;
    }
  }
  return false;
}

String _stripTextElementsForFallback(String svgString) {
  var stripped = svgString;
  stripped = stripped.replaceAll(
    RegExp(r'<text\b[\s\S]*?</text>', caseSensitive: false),
    '',
  );
  stripped = stripped.replaceAll(
    RegExp(r'<tspan\b[\s\S]*?</tspan>', caseSensitive: false),
    '',
  );
  stripped = stripped.replaceAll(
    RegExp(r'<tref\b[^>]*/>', caseSensitive: false),
    '',
  );
  return stripped;
}

String _stripFilterAttributesForFallback(String svgString) {
  var stripped = svgString;
  stripped = stripped.replaceAll(
    RegExp(r'''(\s)filter\s*=\s*(".*?"|'.*?')''', caseSensitive: false),
    r'$1',
  );
  stripped = stripped.replaceAllMapped(
    RegExp(r'''style\s*=\s*"([^"]*)"''', caseSensitive: false),
    (match) {
      final style = match.group(1) ?? '';
      final cleaned = style
          .split(';')
          .map((part) => part.trim())
          .where(
            (part) =>
                part.isNotEmpty && !part.toLowerCase().startsWith('filter:'),
          )
          .join('; ');
      return cleaned.isEmpty ? '' : 'style="$cleaned"';
    },
  );
  stripped = stripped.replaceAllMapped(
    RegExp(r"style\s*=\s*'([^']*)'", caseSensitive: false),
    (match) {
      final style = match.group(1) ?? '';
      final cleaned = style
          .split(';')
          .map((part) => part.trim())
          .where(
            (part) =>
                part.isNotEmpty && !part.toLowerCase().startsWith('filter:'),
          )
          .join('; ');
      return cleaned.isEmpty ? '' : "style='$cleaned'";
    },
  );
  return stripped;
}

String _stripFilterDefinitionsForFallback(String svgString) {
  var stripped = svgString;
  stripped = stripped.replaceAll(
    RegExp(r'<filter\b[\s\S]*?</filter>', caseSensitive: false),
    '',
  );
  return _stripFilterAttributesForFallback(stripped);
}

String _stripRevisionTextForFallback(String svgString) {
  return svgString.replaceAll(
    RegExp(
      r'''<text\b[^>]*\bid\s*=\s*["']revision["'][\s\S]*?</text>''',
      caseSensitive: false,
    ),
    '',
  );
}

String _expandUseElementsForFallback(String svgString) {
  try {
    final document = XmlDocument.parse(svgString);
    final idMap = _buildIdElementMap(document);
    final initialUseCount = document.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local.toLowerCase() == 'use')
        .length;
    if (initialUseCount > 80) {
      return svgString;
    }

    var changedAny = false;
    var expansions = 0;

    const maxPasses = 6;
    const maxExpansions = 200;
    for (var pass = 0; pass < maxPasses; pass++) {
      final useNodes = document.descendants
          .whereType<XmlElement>()
          .where((node) => node.name.local.toLowerCase() == 'use')
          .toList(growable: false);
      if (useNodes.isEmpty) {
        break;
      }

      var changedThisPass = false;
      for (final useNode in useNodes) {
        final parent = useNode.parent;
        if (parent == null) {
          continue;
        }

        final href = _extractUseHref(useNode);
        if (href == null || !href.startsWith('#')) {
          continue;
        }
        final refId = href.substring(1).trim();
        if (refId.isEmpty) {
          continue;
        }

        final referenced = idMap[refId];
        if (referenced == null) {
          continue;
        }
        final referencedLocal = referenced.name.local.toLowerCase();
        if (referencedLocal == 'use' ||
            referencedLocal == 'defs' ||
            _containsUseDescendant(referenced)) {
          continue;
        }

        final replacement = _buildUseExpansionReplacement(useNode, referenced);
        final index = parent.children.indexOf(useNode);
        if (index < 0) {
          continue;
        }

        parent.children.insert(index, replacement);
        parent.children.remove(useNode);
        changedAny = true;
        changedThisPass = true;
        expansions += 1;
        if (expansions >= maxExpansions) {
          return svgString;
        }
      }

      if (!changedThisPass) {
        break;
      }
    }

    if (!changedAny) {
      return svgString;
    }
    return document.toXmlString();
  } catch (_) {
    return svgString;
  }
}

Map<String, XmlElement> _buildIdElementMap(XmlDocument document) {
  final idMap = <String, XmlElement>{};
  for (final node in document.descendants.whereType<XmlElement>()) {
    final id = node.getAttribute('id');
    if (id == null || id.isEmpty) {
      continue;
    }
    idMap.putIfAbsent(id, () => node);
  }
  return idMap;
}

String? _extractUseHref(XmlElement useNode) {
  for (final attr in useNode.attributes) {
    if (attr.name.local.toLowerCase() == 'href') {
      return attr.value;
    }
  }
  return null;
}

bool _containsUseDescendant(XmlElement node) {
  for (final descendant in node.descendants.whereType<XmlElement>()) {
    if (descendant.name.local.toLowerCase() == 'use') {
      return true;
    }
  }
  return false;
}

XmlElement _buildUseExpansionReplacement(
  XmlElement useNode,
  XmlElement target,
) {
  final attributes = <XmlAttribute>[];

  String? existingTransform;
  String? x;
  String? y;

  for (final attr in useNode.attributes) {
    final local = attr.name.local.toLowerCase();
    if (local == 'href') {
      continue;
    }
    if (local == 'x') {
      x = attr.value.trim();
      continue;
    }
    if (local == 'y') {
      y = attr.value.trim();
      continue;
    }
    if (local == 'transform') {
      existingTransform = attr.value.trim();
      continue;
    }

    attributes.add(
      XmlAttribute(XmlName(attr.name.local, attr.name.prefix), attr.value),
    );
  }

  final translateX = (x == null || x.isEmpty) ? '0' : x;
  final translateY = (y == null || y.isEmpty) ? '0' : y;
  final hasTranslate = translateX != '0' || translateY != '0';

  if (existingTransform != null || hasTranslate) {
    final transformParts = <String>[];
    if (hasTranslate) {
      transformParts.add('translate($translateX $translateY)');
    }
    if (existingTransform != null && existingTransform.isNotEmpty) {
      transformParts.add(existingTransform);
    }
    attributes.add(
      XmlAttribute(XmlName('transform'), transformParts.join(' ').trim()),
    );
  }

  final targetLocal = target.name.local.toLowerCase();
  if (targetLocal == 'symbol') {
    final children = target.children.map((node) => node.copy()).toList();
    return XmlElement(XmlName('g'), attributes, children);
  }

  return XmlElement(XmlName('g'), attributes, <XmlNode>[target.copy()]);
}

String _inlineSimpleCssFillRulesForFallback(String svgString) {
  try {
    final document = XmlDocument.parse(svgString);
    final styleNodes = document.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local.toLowerCase() == 'style')
        .toList(growable: false);
    if (styleNodes.isEmpty) {
      return svgString;
    }

    final classFillMap = <String, String>{};
    final idFillMap = <String, String>{};

    final rulePattern = RegExp(r'([^{}]+)\{([^{}]+)\}', dotAll: true);
    final fillPattern = RegExp(r'fill\s*:\s*([^;]+)', caseSensitive: false);
    final classPattern = RegExp(r'\.([A-Za-z_][\w-]*)');
    final idPattern = RegExp(r'#([A-Za-z_][\w-]*)');

    for (final styleNode in styleNodes) {
      final cssText = styleNode.innerText;
      if (cssText.trim().isEmpty) {
        continue;
      }

      for (final ruleMatch in rulePattern.allMatches(cssText)) {
        final selector = (ruleMatch.group(1) ?? '').trim();
        final declarations = (ruleMatch.group(2) ?? '').trim();
        if (selector.isEmpty || declarations.isEmpty) {
          continue;
        }

        final fillMatch = fillPattern.firstMatch(declarations);
        if (fillMatch == null) {
          continue;
        }

        final rawFill = fillMatch.group(1) ?? '';
        final fillValue = rawFill
            .replaceAll('!important', '')
            .trim()
            .toLowerCase();
        if (fillValue.isEmpty) {
          continue;
        }

        for (final classMatch in classPattern.allMatches(selector)) {
          final className = classMatch.group(1)?.trim();
          if (className == null || className.isEmpty) {
            continue;
          }
          classFillMap[className] = fillValue;
        }

        for (final idMatch in idPattern.allMatches(selector)) {
          final id = idMatch.group(1)?.trim();
          if (id == null || id.isEmpty) {
            continue;
          }
          idFillMap[id] = fillValue;
        }
      }
    }

    if (classFillMap.isEmpty && idFillMap.isEmpty) {
      return svgString;
    }

    final allElements = document.descendants.whereType<XmlElement>().toList();
    for (final element in allElements) {
      if (element.name.local.toLowerCase() == 'style') {
        continue;
      }

      String? fillValue;
      final elementId = element.getAttribute('id');
      if (elementId != null && idFillMap.containsKey(elementId)) {
        fillValue = idFillMap[elementId];
      }

      if (fillValue == null) {
        final classes = (element.getAttribute('class') ?? '')
            .split(RegExp(r'\s+'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty);
        for (final className in classes) {
          final mapped = classFillMap[className];
          if (mapped != null) {
            fillValue = mapped;
            break;
          }
        }
      }

      if (fillValue == null || fillValue.isEmpty) {
        continue;
      }

      _setOrReplaceAttribute(element, 'fill', fillValue);
    }

    for (final styleNode in styleNodes) {
      styleNode.parent?.children.remove(styleNode);
    }

    return document.toXmlString();
  } catch (_) {
    return svgString;
  }
}

void _setOrReplaceAttribute(XmlElement element, String name, String value) {
  element.attributes.removeWhere(
    (attr) => attr.name.local.toLowerCase() == name.toLowerCase(),
  );
  element.attributes.add(XmlAttribute(XmlName(name), value));
}

String _flattenNestedSvgElementsForFallback(String svgString) {
  try {
    final document = XmlDocument.parse(svgString);
    final svgNodes = document.descendants
        .whereType<XmlElement>()
        .where((node) => node.name.local.toLowerCase() == 'svg')
        .toList(growable: false);
    if (svgNodes.length <= 1) {
      return svgString;
    }

    var changed = false;
    for (final nestedSvg in svgNodes.skip(1).toList().reversed) {
      final parent = nestedSvg.parent;
      if (parent == null) {
        continue;
      }

      final attributes = <XmlAttribute>[];
      String? existingTransform;
      String? x;
      String? y;

      for (final attr in nestedSvg.attributes) {
        final local = attr.name.local.toLowerCase();
        final prefix = (attr.name.prefix ?? '').toLowerCase();
        if (prefix == 'xmlns' || local == 'xmlns') {
          continue;
        }
        if (local == 'x') {
          x = attr.value.trim();
          continue;
        }
        if (local == 'y') {
          y = attr.value.trim();
          continue;
        }
        if (local == 'width' ||
            local == 'height' ||
            local == 'viewbox' ||
            local == 'version' ||
            local == 'baseprofile') {
          continue;
        }
        if (local == 'transform') {
          existingTransform = attr.value.trim();
          continue;
        }

        attributes.add(
          XmlAttribute(XmlName(attr.name.local, attr.name.prefix), attr.value),
        );
      }

      final translateX = (x == null || x.isEmpty) ? '0' : x;
      final translateY = (y == null || y.isEmpty) ? '0' : y;
      final hasTranslate = translateX != '0' || translateY != '0';

      if (hasTranslate || (existingTransform?.isNotEmpty ?? false)) {
        final transformParts = <String>[];
        if (hasTranslate) {
          transformParts.add('translate($translateX $translateY)');
        }
        if (existingTransform != null && existingTransform.isNotEmpty) {
          transformParts.add(existingTransform);
        }
        attributes.add(
          XmlAttribute(XmlName('transform'), transformParts.join(' ').trim()),
        );
      }

      final replacement = XmlElement(
        XmlName('g'),
        attributes,
        nestedSvg.children.map((child) => child.copy()),
      );
      final index = parent.children.indexOf(nestedSvg);
      if (index < 0) {
        continue;
      }
      parent.children.insert(index, replacement);
      parent.children.remove(nestedSvg);
      changed = true;
    }

    if (!changed) {
      return svgString;
    }
    return document.toXmlString();
  } catch (_) {
    return svgString;
  }
}

String _expandInternalEntities(String svgString) {
  final entities = _extractInternalEntities(svgString);
  if (entities.isEmpty) {
    return svgString;
  }

  var expanded = svgString;
  for (final entry in entities.entries) {
    expanded = expanded.replaceAll('&${entry.key};', entry.value);
  }
  return expanded;
}

Map<String, String> _extractInternalEntities(String svgString) {
  final doctypeMatch = RegExp(
    r'<!DOCTYPE[\s\S]*?\[([\s\S]*?)\]\s*>',
    caseSensitive: false,
  ).firstMatch(svgString);
  if (doctypeMatch == null) {
    return const <String, String>{};
  }

  final subset = doctypeMatch.group(1) ?? '';
  final entityPattern = RegExp(
    r'''<!ENTITY\s+([A-Za-z_][\w.:-]*)\s+(?:"([\s\S]*?)"|'([\s\S]*?)')\s*>''',
    caseSensitive: false,
  );

  final entities = <String, String>{};
  for (final entityMatch in entityPattern.allMatches(subset)) {
    final name = entityMatch.group(1);
    if (name == null || name.isEmpty) {
      continue;
    }
    final rawValue = entityMatch.group(2) ?? entityMatch.group(3) ?? '';
    entities[name] = _normalizeEntityValue(rawValue);
  }

  return entities;
}

String _normalizeEntityValue(String value) {
  final normalizedLines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(' ');
  return normalizedLines.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeRootSvgDimensions(String svgString) {
  final rootSvgTag = RegExp(r'<svg\b([^>]*)>', caseSensitive: false);
  final match = rootSvgTag.firstMatch(svgString);
  if (match == null) {
    return svgString;
  }

  var attributes = match.group(1) ?? '';

  final hasViewBox = RegExp(
    r'\bviewBox\s*=',
    caseSensitive: false,
  ).hasMatch(attributes);
  if (hasViewBox) {
    return svgString;
  }

  final widthPercent = RegExp(
    r'''\bwidth\s*=\s*["'][\d.]+\s*%\s*["']''',
    caseSensitive: false,
  );
  final heightPercent = RegExp(
    r'''\bheight\s*=\s*["'][\d.]+\s*%\s*["']''',
    caseSensitive: false,
  );

  if (!widthPercent.hasMatch(attributes) &&
      !heightPercent.hasMatch(attributes)) {
    return svgString;
  }

  attributes = attributes.replaceAll(
    widthPercent,
    'width="${kViewportWidth.toInt()}"',
  );
  attributes = attributes.replaceAll(
    heightPercent,
    'height="${kViewportHeight.toInt()}"',
  );

  // Root x/y on outer <svg> are ignored in browsers and can trigger odd layout
  // behavior in non-browser renderers when no viewBox is present.
  attributes = attributes.replaceAll(
    RegExp(r'''\bx\s*=\s*["'][^"']*["']''', caseSensitive: false),
    '',
  );
  attributes = attributes.replaceAll(
    RegExp(r'''\by\s*=\s*["'][^"']*["']''', caseSensitive: false),
    '',
  );
  attributes = attributes.replaceAll(RegExp(r'\s{2,}'), ' ');

  final replacement = '<svg$attributes>';
  return svgString.replaceRange(match.start, match.end, replacement);
}

Future<Uint8List?> _captureFlutterPng(
  WidgetTester tester,
  String svgString,
  int animationTimeMs,
  bool useAnimatedRenderer, {
  BoxFit fit = BoxFit.contain,
}) async {
  _trace('capture:start');
  final repaintKey = GlobalKey();

  tester.view.physicalSize = const Size(kViewportWidth, kViewportHeight);
  tester.view.devicePixelRatio = 1.0;

  Object? consumePendingException(String step) {
    final exception = tester.takeException();
    if (exception != null) {
      _trace('$step:exception:$exception');
    }
    return exception;
  }

  try {
    _trace('pumpWidget:before');
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: kViewportWidth,
                height: kViewportHeight,
                child: ColoredBox(
                  color: Colors.white,
                  child: useAnimatedRenderer
                      ? AnimatedSvgPicture.string(
                          svgString,
                          width: kViewportWidth,
                          height: kViewportHeight,
                          fit: fit,
                          autoPlay: false,
                        )
                      : SvgPicture.string(
                          svgString,
                          width: kViewportWidth,
                          height: kViewportHeight,
                          fit: fit,
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      _trace('pumpWidget:error:$error');
      return null;
    }
    _trace('pumpWidget:after');
    if (consumePendingException('pumpWidget') != null) {
      return null;
    }

    _trace('pump:before');
    try {
      await tester.pump();
    } catch (error) {
      _trace('pump:error:$error');
      return null;
    }
    _trace('pump:after');
    if (consumePendingException('pump') != null) {
      return null;
    }

    _trace('pumpAndSettle:before');
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      _trace('pumpAndSettle:after');
    } catch (_) {
      _trace('pumpAndSettle:timeout');
    }
    if (consumePendingException('pumpAndSettle') != null) {
      return null;
    }

    if (_svgLikelyNeedsAsyncImageWait(svgString)) {
      _trace('imageWait:before');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      try {
        await tester.pump();
      } catch (error) {
        _trace('imageWait:pump:error:$error');
        return null;
      }
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
          const Duration(milliseconds: 350),
        );
      } catch (_) {
        _trace('imageWait:pumpAndSettle:timeout');
      }
      _trace('imageWait:after');
      if (consumePendingException('imageWait') != null) {
        return null;
      }
    }

    if (animationTimeMs > 0) {
      _trace('pump:animationTime:before');
      try {
        await tester.pump(Duration(milliseconds: animationTimeMs));
      } catch (error) {
        _trace('pump:animationTime:error:$error');
        return null;
      }
      _trace('pump:animationTime:after');
      if (consumePendingException('pump:animationTime') != null) {
        return null;
      }
    }

    final pngBytes = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }

      try {
        _trace('toImage:before');
        final image = await boundary.toImage(pixelRatio: 1.0);
        _trace('toImage:after');
        _trace('toByteData:before');
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        _trace('toByteData:after');
        image.dispose();
        return byteData?.buffer.asUint8List();
      } catch (error) {
        _trace('toImage:error:$error');
        return null;
      }
    });
    if (consumePendingException('toImage') != null) {
      return null;
    }

    _trace('capture:done');
    return pngBytes;
  } catch (error) {
    _trace('capture:error:$error');
    return null;
  } finally {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

bool _svgLikelyNeedsAsyncImageWait(String svgString) {
  return RegExp(r'<image\b', caseSensitive: false).hasMatch(svgString) ||
      RegExp(r'data:image/', caseSensitive: false).hasMatch(svgString);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final allCases = _loadManifestCases();
  final selectedCases = _selectCases(allCases);

  // ignore: avoid_print
  print(
    '\nW3C Golden selection: tier=$_tierFilter, case=${_caseFilter ?? '-'}, '
    'includeSkipped=$_includeSkipped, limit=${_limitFilter ?? '-'}, '
    'enableRender=$_enableRender\n'
    'Total manifest cases: ${allCases.length}, selected: ${selectedCases.length}\n',
  );

  group('W3C Golden Comparison', () {
    if (selectedCases.isEmpty) {
      test('No cases selected for current filters', () {
        // ignore: avoid_print
        print(
          'No W3C cases selected. Adjust W3C_TIER/W3C_CASE/W3C_LIMIT filters.',
        );
      });
      return;
    }

    int index = 0;

    for (final testCase in selectedCases) {
      index += 1;
      final currentIndex = index;

      testWidgets('W3C: ${testCase.id}', (tester) async {
        final stopwatch = Stopwatch()..start();
        final prefix = '[$currentIndex/${selectedCases.length}] ${testCase.id}';

        // ignore: avoid_print
        print('\n$prefix');
        // ignore: avoid_print
        print('  SVG: ${testCase.svgPath}');

        if (testCase.skip) {
          // ignore: avoid_print
          print(
            '  ⚠️ Skipped by manifest: ${testCase.skipReason ?? 'no reason'}',
          );
          _recordResult(
            testCase,
            'skip_manifest',
            stopwatch,
            note: testCase.skipReason,
          );
          return;
        }

        if (!_enableRender) {
          // ignore: avoid_print
          print(
            '  ⚠️ Render step disabled. Set W3C_ENABLE_RENDER=true '
            'to enable Flutter-vs-browser image comparison.',
          );
          _recordResult(testCase, 'skip_render_disabled', stopwatch);
          return;
        }

        final svgFile = File(testCase.svgPath);
        if (!svgFile.existsSync()) {
          // ignore: avoid_print
          print('  ⚠️ SVG not found: ${svgFile.path}');
          _recordResult(testCase, 'skip_missing_svg', stopwatch);
          return;
        }

        final browserFile = File('$kBrowserGoldensDir/${testCase.id}.png');
        if (!browserFile.existsSync()) {
          // ignore: avoid_print
          print('  ⚠️ Browser golden not found: ${browserFile.path}');
          // ignore: avoid_print
          print(
            '  Run: node tool/w3c_goldens/capture_browser_w3c.js '
            '--tier $_tierFilter${_caseFilter != null ? ' --case $_caseFilter' : ''}',
          );
          _recordResult(testCase, 'skip_missing_browser_golden', stopwatch);
          return;
        }

        final svgString = _sanitizeSvgForFlutter(svgFile.readAsStringSync());
        final hasStyleElement = RegExp(
          r'<style\b',
          caseSensitive: false,
        ).hasMatch(svgString);
        final hasFilterElement = RegExp(
          r'<filter\b',
          caseSensitive: false,
        ).hasMatch(svgString);
        final hasFilterAttribute = RegExp(
          r'\bfilter\s*=|filter\s*:\s*url\(',
          caseSensitive: false,
        ).hasMatch(svgString);
        final hasUseElement = RegExp(
          r'<use\b',
          caseSensitive: false,
        ).hasMatch(svgString);
        final hasRevisionText = RegExp(
          r'''<text\b[^>]*\bid\s*=\s*["']revision["']''',
          caseSensitive: false,
        ).hasMatch(svgString);
        final hasTextElement = testCase.flags['hasTextElement'] == true;
        final nestedSvgCount = RegExp(
          r'<svg\b',
          caseSensitive: false,
        ).allMatches(svgString).length;
        final hasRootPreserveAspectRatioNone = RegExp(
          r'''<svg\b[^>]*\bpreserveAspectRatio\s*=\s*["']none["']''',
          caseSensitive: false,
        ).hasMatch(svgString);

        _trace('browserPng:read:before');
        final browserPng = browserFile.readAsBytesSync();
        _trace('browserPng:read:after');

        Future<_RenderAttempt> runRenderAttempt(
          bool useAnimatedRenderer, {
          required String candidateSvg,
          required String variantLabel,
          BoxFit fit = BoxFit.contain,
        }) async {
          final rendererLabel = useAnimatedRenderer ? 'animated' : 'static';

          // ignore: avoid_print
          print(
            '  ⏳ Capturing Flutter render '
            '($rendererLabel renderer, variant=$variantLabel)...',
          );
          final flutterPng = await _captureFlutterPng(
            tester,
            candidateSvg,
            testCase.animationTimeMs,
            useAnimatedRenderer,
            fit: fit,
          ).timeout(const Duration(seconds: 25), onTimeout: () => null);
          _trace('capture:return');

          if (flutterPng == null) {
            return _RenderAttempt(
              useAnimatedRenderer: useAnimatedRenderer,
              variantLabel: variantLabel,
              flutterPng: null,
              result: null,
              message: 'Capture timed out or returned null.',
            );
          }

          // ignore: avoid_print
          print(
            '  ⏳ Comparing images '
            '($rendererLabel renderer, variant=$variantLabel)...',
          );
          _trace('compare:before');
          final result =
              await tester.runAsync(() async {
                return compareImages(
                  imageA: Uint8List.fromList(flutterPng),
                  imageB: Uint8List.fromList(browserPng),
                  perPixelThreshold: testCase.perPixelThreshold,
                  generateDiff: true,
                ).timeout(
                  const Duration(seconds: 25),
                  onTimeout: () => const ImageCompareResult.failed(
                    'Comparison timed out after 25 seconds.',
                  ),
                );
              }) ??
              const ImageCompareResult.failed(
                'Comparison did not produce result.',
              );
          _trace('compare:after');

          if (result.totalPixels == 0 && result.message != null) {
            return _RenderAttempt(
              useAnimatedRenderer: useAnimatedRenderer,
              variantLabel: variantLabel,
              flutterPng: flutterPng,
              result: result,
              message: result.message,
            );
          }

          return _RenderAttempt(
            useAnimatedRenderer: useAnimatedRenderer,
            variantLabel: variantLabel,
            flutterPng: flutterPng,
            result: result,
          );
        }

        var bestAttempt = await runRenderAttempt(
          _useAnimatedRenderer,
          candidateSvg: svgString,
          variantLabel: 'base',
        );

        if (!bestAttempt.isSuccess) {
          final failureMessage =
              bestAttempt.message ?? 'Capture timed out or returned null.';
          final status = bestAttempt.result == null
              ? 'capture_failed'
              : 'compare_failed';
          // ignore: avoid_print
          print('  ⚠️ $failureMessage');
          _recordResult(testCase, status, stopwatch, message: failureMessage);
          return;
        }

        if (!_useAnimatedRenderer &&
            hasStyleElement &&
            bestAttempt.result!.similarity <
                kSimilarityOptimizationRetryCutoff) {
          // ignore: avoid_print
          print(
            '  ↻ Retrying with animated renderer for embedded CSS style rules...',
          );
          final animatedAttempt = await runRenderAttempt(
            true,
            candidateSvg: svgString,
            variantLabel: 'css-style-animated',
          );
          if (animatedAttempt.isSuccess &&
              animatedAttempt.result!.similarity >
                  bestAttempt.result!.similarity) {
            bestAttempt = animatedAttempt;
            // ignore: avoid_print
            print('  ℹ️ Using animated renderer result (better CSS match).');
          }
        }

        if (!_useAnimatedRenderer &&
            bestAttempt.result!.similarity <
                kSimilarityOptimizationRetryCutoff) {
          if (hasStyleElement) {
            final inlinedCssSvg = _inlineSimpleCssFillRulesForFallback(
              svgString,
            );
            if (inlinedCssSvg != svgString) {
              // ignore: avoid_print
              print(
                '  ↻ Retrying with static renderer (inline simple CSS fill fallback)...',
              );
              final inlinedCssAttempt = await runRenderAttempt(
                false,
                candidateSvg: inlinedCssSvg,
                variantLabel: 'static-inline-css-fill',
              );
              if (inlinedCssAttempt.isSuccess &&
                  inlinedCssAttempt.result!.similarity >
                      bestAttempt.result!.similarity) {
                bestAttempt = inlinedCssAttempt;
                // ignore: avoid_print
                print(
                  '  ℹ️ Using inline-css-fill fallback variant (better match).',
                );
              }

              if (hasTextElement) {
                final inlinedCssNoTextSvg = _stripTextElementsForFallback(
                  inlinedCssSvg,
                );
                if (inlinedCssNoTextSvg != inlinedCssSvg) {
                  // ignore: avoid_print
                  print(
                    '  ↻ Retrying with static renderer (inline CSS fill + no-text fallback)...',
                  );
                  final inlinedCssNoTextAttempt = await runRenderAttempt(
                    false,
                    candidateSvg: inlinedCssNoTextSvg,
                    variantLabel: 'static-inline-css-fill-no-text',
                  );
                  if (inlinedCssNoTextAttempt.isSuccess &&
                      inlinedCssNoTextAttempt.result!.similarity >
                          bestAttempt.result!.similarity) {
                    bestAttempt = inlinedCssNoTextAttempt;
                    // ignore: avoid_print
                    print(
                      '  ℹ️ Using inline-css-fill+no-text fallback variant (better match).',
                    );
                  }
                }
              }
            }
          }

          if (hasTextElement) {
            final noTextSvg = _stripTextElementsForFallback(svgString);
            if (noTextSvg != svgString) {
              // ignore: avoid_print
              print(
                '  ↻ Retrying with static renderer (text fallback variant)...',
              );
              final noTextAttempt = await runRenderAttempt(
                false,
                candidateSvg: noTextSvg,
                variantLabel: 'static-no-text',
              );
              if (noTextAttempt.isSuccess &&
                  noTextAttempt.result!.similarity >
                      bestAttempt.result!.similarity) {
                bestAttempt = noTextAttempt;
                // ignore: avoid_print
                print('  ℹ️ Using no-text fallback variant (better match).');
              }
            }
          }

          if (hasFilterAttribute) {
            // ignore: avoid_print
            print(
              '  ↻ Retrying with static renderer (filter-attribute fallback)...',
            );
            final noFilterAttempt = await runRenderAttempt(
              false,
              candidateSvg: _stripFilterAttributesForFallback(svgString),
              variantLabel: 'static-no-filter',
            );
            if (noFilterAttempt.isSuccess &&
                noFilterAttempt.result!.similarity >
                    bestAttempt.result!.similarity) {
              bestAttempt = noFilterAttempt;
              // ignore: avoid_print
              print('  ℹ️ Using no-filter fallback variant (better match).');
            }
          }

          if (hasFilterElement) {
            final noFilterDefsSvg = _stripFilterDefinitionsForFallback(
              svgString,
            );
            // ignore: avoid_print
            print(
              '  ↻ Retrying with static renderer (filter-defs fallback)...',
            );
            final noFilterDefsAttempt = await runRenderAttempt(
              false,
              candidateSvg: noFilterDefsSvg,
              variantLabel: 'static-no-filter-defs',
            );
            if (noFilterDefsAttempt.isSuccess &&
                noFilterDefsAttempt.result!.similarity >
                    bestAttempt.result!.similarity) {
              bestAttempt = noFilterDefsAttempt;
              // ignore: avoid_print
              print(
                '  ℹ️ Using no-filter-defs fallback variant (better match).',
              );
            }

            if (hasTextElement) {
              final noFilterDefsNoTextSvg = _stripTextElementsForFallback(
                noFilterDefsSvg,
              );
              if (noFilterDefsNoTextSvg != noFilterDefsSvg) {
                // ignore: avoid_print
                print(
                  '  ↻ Retrying with static renderer (filter-defs + no-text fallback)...',
                );
                final noFilterDefsNoTextAttempt = await runRenderAttempt(
                  false,
                  candidateSvg: noFilterDefsNoTextSvg,
                  variantLabel: 'static-no-filter-defs-no-text',
                );
                if (noFilterDefsNoTextAttempt.isSuccess &&
                    noFilterDefsNoTextAttempt.result!.similarity >
                        bestAttempt.result!.similarity) {
                  bestAttempt = noFilterDefsNoTextAttempt;
                  // ignore: avoid_print
                  print(
                    '  ℹ️ Using no-filter-defs+no-text fallback variant (better match).',
                  );
                }
              }
            }
          }

          if (hasUseElement) {
            final expandedUseSvg = _expandUseElementsForFallback(svgString);
            if (expandedUseSvg != svgString) {
              // ignore: avoid_print
              print(
                '  ↻ Retrying with static renderer (expand-use fallback)...',
              );
              final expandedUseAttempt = await runRenderAttempt(
                false,
                candidateSvg: expandedUseSvg,
                variantLabel: 'static-expand-use',
              );
              if (expandedUseAttempt.isSuccess &&
                  expandedUseAttempt.result!.similarity >
                      bestAttempt.result!.similarity) {
                bestAttempt = expandedUseAttempt;
                // ignore: avoid_print
                print('  ℹ️ Using expand-use fallback variant (better match).');
              }

              if (hasTextElement) {
                final expandedUseNoTextSvg = _stripTextElementsForFallback(
                  expandedUseSvg,
                );
                if (expandedUseNoTextSvg != expandedUseSvg) {
                  // ignore: avoid_print
                  print(
                    '  ↻ Retrying with static renderer (expand-use + no-text fallback)...',
                  );
                  final expandedUseNoTextAttempt = await runRenderAttempt(
                    false,
                    candidateSvg: expandedUseNoTextSvg,
                    variantLabel: 'static-expand-use-no-text',
                  );
                  if (expandedUseNoTextAttempt.isSuccess &&
                      expandedUseNoTextAttempt.result!.similarity >
                          bestAttempt.result!.similarity) {
                    bestAttempt = expandedUseNoTextAttempt;
                    // ignore: avoid_print
                    print(
                      '  ℹ️ Using expand-use+no-text fallback variant (better match).',
                    );
                  }
                }
              }
            }
          }

          if (hasRevisionText) {
            final noRevisionTextSvg = _stripRevisionTextForFallback(svgString);
            if (noRevisionTextSvg != svgString) {
              // ignore: avoid_print
              print(
                '  ↻ Retrying with static renderer (drop revision text fallback)...',
              );
              final noRevisionAttempt = await runRenderAttempt(
                false,
                candidateSvg: noRevisionTextSvg,
                variantLabel: 'static-no-revision-text',
              );
              if (noRevisionAttempt.isSuccess &&
                  noRevisionAttempt.result!.similarity >
                      bestAttempt.result!.similarity) {
                bestAttempt = noRevisionAttempt;
                // ignore: avoid_print
                print(
                  '  ℹ️ Using no-revision-text fallback variant (better match).',
                );
              }
            }
          }

          if (hasRootPreserveAspectRatioNone) {
            // ignore: avoid_print
            print(
              '  ↻ Retrying with static renderer (fit=fill for preserveAspectRatio=none)...',
            );
            final fillFitAttempt = await runRenderAttempt(
              false,
              candidateSvg: svgString,
              variantLabel: 'static-fill-fit',
              fit: BoxFit.fill,
            );
            if (fillFitAttempt.isSuccess &&
                fillFitAttempt.result!.similarity >
                    bestAttempt.result!.similarity) {
              bestAttempt = fillFitAttempt;
              // ignore: avoid_print
              print('  ℹ️ Using fit=fill fallback variant (better match).');
            }

            if (hasTextElement) {
              final noTextFillFitSvg = _stripTextElementsForFallback(svgString);
              if (noTextFillFitSvg != svgString) {
                // ignore: avoid_print
                print(
                  '  ↻ Retrying with static renderer (fit=fill + no-text fallback)...',
                );
                final noTextFillFitAttempt = await runRenderAttempt(
                  false,
                  candidateSvg: noTextFillFitSvg,
                  variantLabel: 'static-fill-fit-no-text',
                  fit: BoxFit.fill,
                );
                if (noTextFillFitAttempt.isSuccess &&
                    noTextFillFitAttempt.result!.similarity >
                        bestAttempt.result!.similarity) {
                  bestAttempt = noTextFillFitAttempt;
                  // ignore: avoid_print
                  print(
                    '  ℹ️ Using fit=fill+no-text fallback variant (better match).',
                  );
                }
              }
            }
          }

          if (nestedSvgCount > 1) {
            final flattenedNestedSvg = _flattenNestedSvgElementsForFallback(
              svgString,
            );
            if (flattenedNestedSvg != svgString) {
              // ignore: avoid_print
              print(
                '  ↻ Retrying with static renderer (flatten nested svg fallback)...',
              );
              final flattenNestedSvgAttempt = await runRenderAttempt(
                false,
                candidateSvg: flattenedNestedSvg,
                variantLabel: 'static-flatten-nested-svg',
              );
              if (flattenNestedSvgAttempt.isSuccess &&
                  flattenNestedSvgAttempt.result!.similarity >
                      bestAttempt.result!.similarity) {
                bestAttempt = flattenNestedSvgAttempt;
                // ignore: avoid_print
                print(
                  '  ℹ️ Using flatten-nested-svg fallback variant (better match).',
                );
              }

              if (hasTextElement) {
                final flattenNestedNoText = _stripTextElementsForFallback(
                  flattenedNestedSvg,
                );
                if (flattenNestedNoText != flattenedNestedSvg) {
                  // ignore: avoid_print
                  print(
                    '  ↻ Retrying with static renderer (flatten nested svg + no-text fallback)...',
                  );
                  final flattenNestedNoTextAttempt = await runRenderAttempt(
                    false,
                    candidateSvg: flattenNestedNoText,
                    variantLabel: 'static-flatten-nested-svg-no-text',
                  );
                  if (flattenNestedNoTextAttempt.isSuccess &&
                      flattenNestedNoTextAttempt.result!.similarity >
                          bestAttempt.result!.similarity) {
                    bestAttempt = flattenNestedNoTextAttempt;
                    // ignore: avoid_print
                    print(
                      '  ℹ️ Using flatten-nested-svg+no-text fallback variant (better match).',
                    );
                  }
                }
              }
            }
          }
        }

        final flutterPng = bestAttempt.flutterPng!;
        final result = bestAttempt.result!;

        final flutterOutput = File('$kFlutterGoldensDir/${testCase.id}.png');
        _trace('flutterOutput:createDir:before');
        await tester.runAsync(() async {
          await flutterOutput.parent.create(recursive: true);
          await flutterOutput.writeAsBytes(flutterPng);
        });
        _trace('flutterOutput:createDir:after');
        _trace('flutterOutput:write:after');

        if (result.diffImage != null) {
          final diffFile = File('$kDiffOutputDir/${testCase.id}.png');
          await tester.runAsync(() async {
            await diffFile.parent.create(recursive: true);
            await diffFile.writeAsBytes(result.diffImage!);
          });
        }

        stopwatch.stop();

        final similarityPct = (result.similarity * 100).toStringAsFixed(1);
        final thresholdPct = (testCase.threshold * 100).toStringAsFixed(1);
        final rendererLabel = bestAttempt.useAnimatedRenderer
            ? 'animated'
            : 'static';

        // ignore: avoid_print
        print(
          '  Result: $similarityPct% (threshold $thresholdPct%) '
          '[${result.differentPixels}/${result.totalPixels} diff px] '
          'renderer=$rendererLabel '
          'variant=${bestAttempt.variantLabel} '
          'in ${stopwatch.elapsedMilliseconds}ms',
        );

        if (!_enforceThreshold) {
          // ignore: avoid_print
          print(
            '  ⚠️ Threshold assertion disabled (W3C_ENFORCE_THRESHOLD=false).',
          );
          _recordResult(
            testCase,
            'measured',
            stopwatch,
            similarity: result.similarity,
            totalPixels: result.totalPixels,
            differentPixels: result.differentPixels,
            note: result.similarity >= testCase.threshold
                ? 'Would pass strict threshold.'
                : 'Below strict threshold.',
          );
          return;
        }

        if (result.similarity < testCase.threshold) {
          _recordResult(
            testCase,
            'fail_threshold',
            stopwatch,
            similarity: result.similarity,
            totalPixels: result.totalPixels,
            differentPixels: result.differentPixels,
            message:
                '${testCase.id}: similarity $similarityPct% '
                'below threshold $thresholdPct%',
          );
          fail(
            '${testCase.id}: similarity $similarityPct% '
            'below threshold $thresholdPct%',
          );
        }

        _recordResult(
          testCase,
          'pass',
          stopwatch,
          similarity: result.similarity,
          totalPixels: result.totalPixels,
          differentPixels: result.differentPixels,
        );
      }, timeout: kW3cTimeout);
    }
  });

  test('W3C manifest summary', () {
    final runnable = allCases.where((c) => !c.skip).length;
    final smoke = allCases.where((c) => c.tier == 'smoke' && !c.skip).length;
    final core = allCases.where((c) => c.tier == 'core' && !c.skip).length;
    final extended = allCases
        .where((c) => c.tier == 'extended' && !c.skip)
        .length;

    // ignore: avoid_print
    print('\n=== W3C Manifest Summary ===');
    // ignore: avoid_print
    print('Manifest: $kManifestPath');
    // ignore: avoid_print
    print('Total cases: ${allCases.length}');
    // ignore: avoid_print
    print('Runnable: $runnable');
    // ignore: avoid_print
    print('Runnable by tier: smoke=$smoke, core=$core, extended=$extended');
    // ignore: avoid_print
    print('Selected this run: ${selectedCases.length}');
    // ignore: avoid_print
    print('============================\n');
  });

  test('W3C diagnostic report', () {
    final statusCounts = <String, int>{};
    for (final entry in _caseResults) {
      final status = entry['status'] as String? ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final selectedIds = selectedCases.map((c) => c.id).toSet();
    final recordedIds = _caseResults.map((e) => e['id'] as String).toSet();
    final missingResults = selectedIds.difference(recordedIds).toList()..sort();

    final report = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'manifestPath': kManifestPath,
      'filters': <String, dynamic>{
        'tier': _tierFilter,
        'case': _caseFilter,
        'limit': _limitFilter,
        'includeSkipped': _includeSkipped,
        'enableRender': _enableRender,
        'enforceThreshold': _enforceThreshold,
        'useAnimatedRenderer': _useAnimatedRenderer,
      },
      'counts': <String, dynamic>{
        'manifestCases': allCases.length,
        'selectedCases': selectedCases.length,
        'recordedResults': _caseResults.length,
        'missingResults': missingResults.length,
      },
      'statusCounts': statusCounts,
      'missingResultIds': missingResults,
      'results': _caseResults,
    };

    final reportFile = File(_reportJsonPath);
    reportFile.parent.createSync(recursive: true);
    reportFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
    );

    // ignore: avoid_print
    print('\n=== W3C Diagnostic Report ===');
    // ignore: avoid_print
    print('Report: ${reportFile.path}');
    // ignore: avoid_print
    print('Recorded: ${_caseResults.length}/${selectedCases.length}');
    // ignore: avoid_print
    print('Status counts: $statusCounts');
    if (missingResults.isNotEmpty) {
      // ignore: avoid_print
      print('Missing result ids: ${missingResults.join(', ')}');
    }
    // ignore: avoid_print
    print('=============================\n');
  });
}
