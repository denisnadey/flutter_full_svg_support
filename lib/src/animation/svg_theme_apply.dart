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

/// Applies an [SvgTheme] and/or [ColorMapper] to an already-parsed [document].
///
/// This runs as an isolated pass over the parsed DOM so it never has to reach
/// into the rendering pipeline:
///
///  * [theme] seeds the document-wide `color` (used by the `currentColor`
///    keyword) and `font-size` (used by `em` units) when the SVG does not
///    declare them itself.
///  * [colorMapper] rewrites every literal color presentation attribute.
///
/// Both arguments are optional; passing `null` for both leaves [document]
/// untouched.
void applySvgTheme(
  SvgDocument document, {
  SvgTheme? theme,
  ColorMapper? colorMapper,
}) {
  if (theme != null) {
    _applyTheme(document.root, theme);
  }
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
