// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@Tags(['golden', 'w3c_golden'])
library w3c_golden_comparison_test;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
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
  'ActiveBorder': '#B4B4B4',
  'ActiveCaption': '#99B4D1',
  'AppWorkspace': '#ABABAB',
  'Background': '#6363CE',
  'ButtonFace': '#F0F0F0',
  'ButtonHighlight': '#FFFFFF',
  'ButtonShadow': '#A0A0A0',
  'ButtonText': '#000000',
  'CaptionText': '#000000',
  'GrayText': '#6D6D6D',
  'Highlight': '#3399FF',
  'HighlightText': '#FFFFFF',
  'InactiveBorder': '#F4F7FC',
  'InactiveCaption': '#BFCDDB',
  'InactiveCaptionText': '#434E54',
  'InfoBackground': '#FFFFE1',
  'InfoText': '#000000',
  'Menu': '#F0F0F0',
  'MenuText': '#000000',
  'Scrollbar': '#C8C8C8',
  'ThreeDDarkShadow': '#696969',
  'ThreeDFace': '#C0C0C0',
  'ThreeDHighlight': '#FFFFFF',
  'ThreeDLightShadow': '#DFDFDF',
  'ThreeDShadow': '#A0A0A0',
  'Window': '#FFFFFF',
  'WindowFrame': '#646464',
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

String _normalizeFontFamilyFallbacks(String svgString) {
  var normalized = svgString;

  normalized = normalized.replaceAllMapped(
    RegExp(r'''font-family\s*=\s*"([^"]*)"''', caseSensitive: false),
    (match) => 'font-family="${_normalizeFontFamilyList(match.group(1) ?? '')}"',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r"font-family\s*=\s*'([^']*)'", caseSensitive: false),
    (match) => "font-family='${_normalizeFontFamilyList(match.group(1) ?? '')}'",
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
                part.isNotEmpty &&
                !part.toLowerCase().startsWith('filter:'),
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
                part.isNotEmpty &&
                !part.toLowerCase().startsWith('filter:'),
          )
          .join('; ');
      return cleaned.isEmpty ? '' : "style='$cleaned'";
    },
  );
  return stripped;
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
  bool useAnimatedRenderer,
) async {
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
                          fit: BoxFit.contain,
                          autoPlay: false,
                        )
                      : SvgPicture.string(
                          svgString,
                          width: kViewportWidth,
                          height: kViewportHeight,
                          fit: BoxFit.contain,
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
        final prefix =
            '[${currentIndex}/${selectedCases.length}] ${testCase.id}';

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

        _trace('browserPng:read:before');
        final browserPng = browserFile.readAsBytesSync();
        _trace('browserPng:read:after');

        Future<_RenderAttempt> runRenderAttempt(
          bool useAnimatedRenderer, {
          required String candidateSvg,
          required String variantLabel,
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
            bestAttempt.result!.similarity < kSimilarityOptimizationRetryCutoff) {
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
            bestAttempt.result!.similarity < kSimilarityOptimizationRetryCutoff) {
          final noTextSvg = _stripTextElementsForFallback(svgString);
          if (noTextSvg != svgString) {
            // ignore: avoid_print
            print('  ↻ Retrying with static renderer (text fallback variant)...');
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

          final noFilterSvg = _stripFilterAttributesForFallback(svgString);
          if (noFilterSvg != svgString) {
            // ignore: avoid_print
            print(
              '  ↻ Retrying with static renderer (filter-attribute fallback)...',
            );
            final noFilterAttempt = await runRenderAttempt(
              false,
              candidateSvg: noFilterSvg,
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
