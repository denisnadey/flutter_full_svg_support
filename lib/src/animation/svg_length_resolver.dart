import 'dart:math' as math;
import 'dart:ui' as ui;

import 'svg_dom.dart';

/// The reference dimension used when resolving an SVG percentage length.
enum SvgLengthReference {
  /// Resolve against the nearest SVG viewport's width.
  horizontal,

  /// Resolve against the nearest SVG viewport's height.
  vertical,

  /// Resolve against the nearest SVG viewport's normalized diagonal.
  normalizedDiagonal,
}

/// Resolves an SVG length attribute in the coordinate system of [node].
///
/// Unitless values remain unchanged. Percentage values are resolved against
/// the nearest ancestral SVG viewport, using [reference]. Other units retain
/// the renderer's existing numeric fallback behavior and use their numeric
/// component without CSS-unit conversion.
double? resolveSvgLength(
  SvgNode node,
  SvgDocument document,
  String attributeName, {
  required SvgLengthReference reference,
}) {
  final value = node.getAttributeValue(attributeName);
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is! String) {
    return null;
  }

  final match = RegExp(
    r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*(%|[a-zA-Z]*)$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }

  final number = double.tryParse(match.group(1)!);
  if (number == null) {
    return null;
  }
  if (match.group(2) != '%') {
    return number;
  }

  final viewport = _resolveNearestViewportSize(node, document);
  final dimension = switch (reference) {
    SvgLengthReference.horizontal => viewport.width,
    SvgLengthReference.vertical => viewport.height,
    SvgLengthReference.normalizedDiagonal => math.sqrt(
      (viewport.width * viewport.width + viewport.height * viewport.height) / 2,
    ),
  };
  return number * dimension / 100;
}

ui.Size _resolveNearestViewportSize(SvgNode node, SvgDocument document) {
  for (
    SvgNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current.tagName != 'svg' &&
        current.tagName != 'symbol' &&
        current.tagName != 'foreignObject') {
      continue;
    }

    final viewBox = _parseViewBox(current.getAttributeValue('viewBox'));
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return ui.Size(viewBox.width, viewBox.height);
    }

    final width = resolveSvgLength(
      current,
      document,
      'width',
      reference: SvgLengthReference.horizontal,
    );
    final height = resolveSvgLength(
      current,
      document,
      'height',
      reference: SvgLengthReference.vertical,
    );
    if (width != null && height != null && width > 0 && height > 0) {
      return ui.Size(width, height);
    }
  }

  final rootViewBox = document.activeViewBox;
  if (rootViewBox != null && rootViewBox.width > 0 && rootViewBox.height > 0) {
    return ui.Size(rootViewBox.width, rootViewBox.height);
  }

  final documentWidth = document.width;
  final documentHeight = document.height;
  if (documentWidth != null &&
      documentHeight != null &&
      documentWidth > 0 &&
      documentHeight > 0) {
    return ui.Size(documentWidth, documentHeight);
  }

  return const ui.Size(100, 100);
}

ui.Rect? _parseViewBox(Object? value) {
  if (value is! String) {
    return null;
  }
  final values = value
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .toList(growable: false);
  if (values.length != 4 || values.any((entry) => entry == null)) {
    return null;
  }
  return ui.Rect.fromLTWH(values[0]!, values[1]!, values[2]!, values[3]!);
}
