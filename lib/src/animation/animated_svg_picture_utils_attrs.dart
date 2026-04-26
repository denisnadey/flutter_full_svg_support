part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateAttrsExtension on _AnimatedSvgPictureState {
  String? _extractHrefId(SvgNode node) {
    final href =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (href == null) {
      return null;
    }

    final raw = href.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }

    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }

  String? _extractStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    // Parse and store custom properties from this node's style
    node.parseAndSetCustomProperties(style);

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) {
        continue;
      }
      final key = parts.first.trim().toLowerCase();
      if (key != property) {
        continue;
      }
      var value = parts.sublist(1).join(':').trim();
      value = value
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (value.isEmpty) {
        return null;
      }
      // Resolve CSS variables if present
      if (containsVarReference(value)) {
        value = CssVariableResolver.resolveValue(value, node);
      }
      return value.isEmpty ? null : value;
    }
    return null;
  }

  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  /// Parses a space/comma-separated list of numbers from an attribute.
  /// Returns empty list if attribute is missing or empty.
  List<double> _getNumberList(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName)?.toString();
    if (value == null || value.trim().isEmpty) {
      return const <double>[];
    }
    return value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();
  }

  Object? _getInheritedAttributeValue(SvgNode node, String attributeName) {
    final normalizedName = attributeName.trim().toLowerCase();
    SvgNode? current = node;
    while (current != null) {
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        return styleValue;
      }
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        return value;
      }
      current = current.parent;
    }
    return null;
  }

  String? _getInheritedString(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    final str = value?.toString();
    if (str == null) {
      return null;
    }
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _getInheritedNumber(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }

  String? _extractTextContent(SvgNode node) {
    final raw = node.getAttributeValue('__text')?.toString();
    if (raw == null) {
      return null;
    }

    // Check xml:space attribute for whitespace handling
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    if (xmlSpace == 'preserve') {
      // Preserve whitespace as-is (only convert newlines to spaces)
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }

    // Default: collapse whitespace
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
