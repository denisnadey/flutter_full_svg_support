import 'dart:ui' as ui;

import 'svg_dom.dart';

const Set<String> _supportedSwitchFeatures = <String>{
  'http://www.w3.org/tr/svg11/feature#svg',
  'http://www.w3.org/tr/svg11/feature#svg-static',
  'http://www.w3.org/tr/svg11/feature#basicstructure',
  'http://www.w3.org/tr/svg11/feature#shape',
  'http://www.w3.org/tr/svg11/feature#conditionalprocessing',
  '#svg',
  '#svg-static',
  '#basicstructure',
  '#shape',
  '#conditionalprocessing',
  'svg',
  'svg-static',
  'basicstructure',
  'shape',
  'conditionalprocessing',
};

SvgNode? resolveActiveSwitchChild(SvgNode switchNode) {
  if (switchNode.tagName != 'switch') {
    return null;
  }

  final locale = ui.PlatformDispatcher.instance.locale;
  final localeTag = _normalizeToken(locale.toLanguageTag());
  final languageCode = _normalizeToken(locale.languageCode);
  final localeCandidates = <String>{
    if (localeTag.isNotEmpty) localeTag,
    if (languageCode.isNotEmpty) languageCode,
  };

  for (final child in switchNode.children) {
    if (_matchesSwitchConditions(child, localeCandidates)) {
      return child;
    }
  }
  return null;
}

bool _matchesSwitchConditions(SvgNode node, Set<String> localeCandidates) {
  final requiredExtensions = _parseTokenList(
    node.getAttributeValue('requiredExtensions'),
  );
  if (requiredExtensions.isNotEmpty) {
    return false;
  }

  final requiredFeatures = _parseTokenList(
    node.getAttributeValue('requiredFeatures'),
  );
  if (requiredFeatures.isNotEmpty &&
      requiredFeatures.any(
        (feature) => !_supportedSwitchFeatures.contains(feature),
      )) {
    return false;
  }

  final systemLanguages = _parseTokenList(
    node.getAttributeValue('systemLanguage'),
    separator: RegExp(r'[\s,]+'),
  );
  if (systemLanguages.isEmpty) {
    return true;
  }

  for (final language in systemLanguages) {
    if (_matchesLanguage(language, localeCandidates)) {
      return true;
    }
  }
  return false;
}

List<String> _parseTokenList(Object? rawValue, {Pattern? separator}) {
  final raw = rawValue?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return const <String>[];
  }
  final parts = raw
      .split(separator ?? RegExp(r'[\s,]+'))
      .map(_normalizeToken)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return parts;
}

bool _matchesLanguage(String language, Set<String> localeCandidates) {
  for (final locale in localeCandidates) {
    if (locale == language ||
        locale.startsWith('$language-') ||
        language.startsWith('$locale-')) {
      return true;
    }
  }
  return false;
}

String _normalizeToken(String raw) {
  return raw.trim().toLowerCase();
}
