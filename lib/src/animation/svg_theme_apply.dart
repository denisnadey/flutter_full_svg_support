import 'dart:ui' as ui;

import '../svg_theme.dart';
import 'svg_dom.dart';

/// Presentation attributes whose value is a literal color and which a
/// [ColorMapper] is therefore allowed to substitute.
const Set<String> _colorAttributes = <String>{
  'fill',
  'stroke',
  'stop-color',
  'color',
  'flood-color',
  'lighting-color',
  'solid-color',
};

/// Scalar geometry attributes that may carry font-relative (`em`/`ex`) units.
const Set<String> _lengthAttributes = <String>{
  'x',
  'y',
  'width',
  'height',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'x1',
  'y1',
  'x2',
  'y2',
  'dx',
  'dy',
  'stroke-width',
};

/// Applies an [SvgTheme] and/or [ColorMapper] to an already-parsed [document].
///
/// This runs as an isolated pass over the parsed DOM so it never has to reach
/// into the rendering pipeline:
///
///  * [theme] seeds the document-wide `color` (used by the `currentColor`
///    keyword) and `font-size` (used by `em` units) when the SVG does not
///    declare them itself.
///  * Font-relative (`em`/`ex`) lengths in geometry attributes are resolved
///    to absolute user units against the effective font size / x-height.
///  * [colorMapper] rewrites every literal color presentation attribute.
///
/// Both arguments are optional. `em`/`ex` resolution always runs, using the
/// default [SvgTheme] (`font-size` 14) when no theme is supplied.
void applySvgTheme(
  SvgDocument document, {
  SvgTheme? theme,
  ColorMapper? colorMapper,
}) {
  final SvgTheme effectiveTheme = theme ?? const SvgTheme();
  if (theme != null) {
    _applyTheme(document.root, theme);
  }
  _resolveFontRelativeUnits(
    document.root,
    effectiveTheme.fontSize,
    effectiveTheme.xHeight,
  );
  if (colorMapper != null) {
    try {
      _applyColorMapper(document.root, colorMapper);
    } catch (_) {
      // A misbehaving color mapper must never crash rendering.
    }
  }
}

void _applyTheme(SvgNode root, SvgTheme theme) {
  if (!_declaresProperty(root, 'color')) {
    root.setAttribute(
      'color',
      theme.currentColor,
      type: SvgAttributeType.color,
      rawValue: _hex(theme.currentColor),
    );
  }
  if (!_declaresProperty(root, 'font-size')) {
    root.setAttribute(
      'font-size',
      theme.fontSize,
      type: SvgAttributeType.number,
      rawValue: theme.fontSize.toString(),
    );
  }
}

/// Whether [node] already declares [property] as an attribute or inline style.
bool _declaresProperty(SvgNode node, String property) {
  if (node.getAttribute(property) != null) {
    return true;
  }
  final style = node.getRawAttributeValue('style');
  if (style == null || style.isEmpty) {
    return false;
  }
  for (final declaration in style.split(';')) {
    final colon = declaration.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    if (declaration.substring(0, colon).trim().toLowerCase() == property) {
      return true;
    }
  }
  return false;
}

/// A length measured from an attribute value.
class _Length {
  const _Length(this.value, {required this.fontRelative});

  /// The resolved value in user units, or null when the value is not a plain
  /// length (a percentage, a keyword, an unparseable list, etc.).
  final double? value;

  /// Whether the source value used a font-relative (`em`/`ex`) unit.
  final bool fontRelative;
}

/// Interprets [raw] as a length, resolving `em`/`ex` against [fontSize] /
/// [xHeight]. Percentages and other non-plain values yield a null value.
_Length _measureLength(Object? raw, double fontSize, double xHeight) {
  if (raw is num) {
    return _Length(raw.toDouble(), fontRelative: false);
  }
  if (raw is! String) {
    return const _Length(null, fontRelative: false);
  }
  final String s = raw.trim().toLowerCase();
  if (s.isEmpty) {
    return const _Length(null, fontRelative: false);
  }
  if (s.endsWith('ex')) {
    final double? n = double.tryParse(s.substring(0, s.length - 2));
    return n == null
        ? const _Length(null, fontRelative: false)
        : _Length(n * xHeight, fontRelative: true);
  }
  if (s.endsWith('em') && !s.endsWith('rem')) {
    final double? n = double.tryParse(s.substring(0, s.length - 2));
    return n == null
        ? const _Length(null, fontRelative: false)
        : _Length(n * fontSize, fontRelative: true);
  }
  if (s.endsWith('px')) {
    return _Length(
      double.tryParse(s.substring(0, s.length - 2)),
      fontRelative: false,
    );
  }
  return _Length(double.tryParse(s), fontRelative: false);
}

/// Rewrites `em`/`ex` lengths in geometry attributes to absolute user units.
///
/// `em` resolves against the element's inherited `font-size`; `ex` against
/// [xHeight]. Non font-relative values are left untouched so the renderer's
/// own percentage / viewport handling is preserved.
void _resolveFontRelativeUnits(
  SvgNode node,
  double inheritedFontSize,
  double xHeight,
) {
  // The original attribute strings (e.g. "0.5em") are preserved as raw
  // values; the typed base value has already had its unit stripped.
  double nodeFontSize = inheritedFontSize;
  final String? fontSizeRaw = node.getRawAttributeValue('font-size');
  if (fontSizeRaw != null) {
    final _Length measured = _measureLength(
      fontSizeRaw,
      inheritedFontSize,
      xHeight,
    );
    if (measured.value != null) {
      nodeFontSize = measured.value!;
      if (measured.fontRelative) {
        node.setAttribute(
          'font-size',
          nodeFontSize,
          type: SvgAttributeType.number,
          rawValue: nodeFontSize.toString(),
        );
      }
    }
  }

  for (final name in _lengthAttributes) {
    final String? raw = node.getRawAttributeValue(name);
    if (raw == null) {
      continue;
    }
    final _Length measured = _measureLength(raw, nodeFontSize, xHeight);
    if (measured.fontRelative && measured.value != null) {
      node.setAttribute(
        name,
        measured.value!,
        type: SvgAttributeType.number,
        rawValue: measured.value!.toString(),
      );
    }
  }

  for (final child in node.children) {
    _resolveFontRelativeUnits(child, nodeFontSize, xHeight);
  }
}

void _applyColorMapper(SvgNode node, ColorMapper colorMapper) {
  for (final name in _colorAttributes) {
    final attribute = node.getAttribute(name);
    final value = attribute?.baseValue;
    if (value is ui.Color) {
      final substitute = colorMapper.substitute(
        node.id,
        node.tagName,
        name,
        value,
      );
      if (substitute != value) {
        node.setAttribute(
          name,
          substitute,
          type: SvgAttributeType.color,
          rawValue: _hex(substitute),
        );
      }
    }
  }
  for (final child in node.children) {
    _applyColorMapper(child, colorMapper);
  }
}

String _hex(ui.Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
