import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'css_cascade.dart';
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

/// Synchronous rendering context used to resolve viewport-relative lengths.
///
/// The DOM alone cannot represent the viewport negotiated by the embedding
/// widget, nor the viewport created when a `<use>` instance references a
/// `<symbol>`/`<svg>`. The context is zone-scoped so simultaneous painters do
/// not store mutable runtime state on [SvgDocument].
class SvgLengthResolutionContext {
  SvgLengthResolutionContext._();

  /// Runs [callback] with [viewport] as the root embedding viewport.
  static T runWithRootViewport<T>(ui.Size viewport, T Function() callback) {
    return Zone.current
        .fork(
          zoneValues: <Object?, Object?>{
            _svgLengthResolutionScopeKey: _SvgLengthResolutionScope(
              rootViewport: viewport,
            ),
          },
        )
        .run(callback);
  }

  /// The root embedding viewport for the active synchronous render scope.
  ///
  /// This is null while timeline updates run outside painting or hit testing.
  static ui.Size? get rootViewport => _currentScope?.rootViewport;

  /// Runs [callback] with [viewport] as the viewport for [node]'s descendants.
  ///
  /// This is used for the viewport established by an instantiated `<use>`.
  static T runWithViewportForNode<T>(
    SvgNode node,
    ui.Size viewport,
    T Function() callback,
  ) {
    final current = _currentScope;
    final viewports = Map<SvgNode, ui.Size>.of(
      current?.viewportsByNode ?? const <SvgNode, ui.Size>{},
    )..[node] = viewport;
    return Zone.current
        .fork(
          zoneValues: <Object?, Object?>{
            _svgLengthResolutionScopeKey: _SvgLengthResolutionScope(
              rootViewport: current?.rootViewport,
              viewportsByNode: viewports,
            ),
          },
        )
        .run(callback);
  }
}

final Object _svgLengthResolutionScopeKey = Object();

class _SvgLengthResolutionScope {
  const _SvgLengthResolutionScope({
    this.rootViewport,
    this.viewportsByNode = const <SvgNode, ui.Size>{},
  });

  final ui.Size? rootViewport;
  final Map<SvgNode, ui.Size> viewportsByNode;
}

_SvgLengthResolutionScope? get _currentScope =>
    Zone.current[_svgLengthResolutionScopeKey] as _SvgLengthResolutionScope?;

Object? _resolveSvgLengthAttributeValue(
  SvgNode node,
  SvgDocument document,
  String attributeName, {
  required bool isAnimated,
  CssCascadeResolver? cascadeResolver,
  String? shadowBoundaryId,
}) {
  final rawValue = node.getRawAttributeValue(attributeName)?.trim();
  if (isAnimated) {
    return node.getAttributeValue(attributeName);
  }

  final cssRules = document.cssSelectorRules ?? const [];
  final baseResolver =
      cascadeResolver ??
      (CssCascadeResolver(cssRules: cssRules)
        ..pseudoClassState = document.pseudoClassState);
  final resolver =
      (shadowBoundaryId == null ||
          shadowBoundaryId == baseResolver.shadowBoundaryId)
      ? baseResolver
      : baseResolver.withShadowBoundary(shadowBoundaryId);

  final inlineValue = _extractInlineStyleValue(node, attributeName);
  final stylesheetValue = resolver.resolveFromStyleRulesOnly(
    node,
    attributeName,
  );
  if (inlineValue != null || stylesheetValue != null) {
    return resolver.resolveOwnProperty(node, attributeName);
  }

  if (rawValue != null && rawValue.isNotEmpty) {
    return rawValue;
  }
  return node.getAttributeValue(attributeName);
}

String? _extractInlineStyleValue(SvgNode node, String property) {
  final style =
      node.getRawAttributeValue('style') ??
      node.getAttributeValue('style')?.toString();
  if (style == null || style.trim().isEmpty) {
    return null;
  }

  final normalizedProperty = property.trim().toLowerCase();
  for (final declaration in style.split(';')) {
    final separator = declaration.indexOf(':');
    if (separator <= 0) {
      continue;
    }
    final name = declaration.substring(0, separator).trim().toLowerCase();
    if (name == normalizedProperty) {
      final value = declaration.substring(separator + 1).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

/// Resolves an SVG length attribute in the coordinate system of [node].
///
/// Unitless values remain unchanged. Percentage values are resolved against
/// the nearest ancestral SVG viewport, using [reference]. Other units retain
/// the renderer's existing numeric fallback behavior and use their numeric
/// component without CSS-unit conversion.
///
/// When [cascadeResolver] is provided it is reused for stylesheet-rule
/// matching (preserving its rule cache and pseudo-class state); otherwise a
/// resolver carrying [SvgDocument.pseudoClassState] is built. [shadowBoundaryId]
/// scopes combinator selector matching to the referenced content of a `<use>`
/// instance, matching the renderer's shadow-boundary cascade semantics.
double? resolveSvgLength(
  SvgNode node,
  SvgDocument document,
  String attributeName, {
  required SvgLengthReference reference,
  CssCascadeResolver? cascadeResolver,
  String? shadowBoundaryId,
}) {
  final attribute = node.getAttribute(attributeName);
  // The parser stores many length values as numbers, which would lose the
  // percentage unit. Preserve the raw presentation-attribute text only when
  // that attribute wins the cascade; inline styles and stylesheet rules must
  // remain the effective value.
  final value = _resolveSvgLengthAttributeValue(
    node,
    document,
    attributeName,
    isAnimated: attribute?.isAnimated ?? false,
    cascadeResolver: cascadeResolver,
    shadowBoundaryId: shadowBoundaryId,
  );
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

/// Resolves the used physical viewport established by an `<svg>` element.
///
/// This is the viewport in the parent user coordinate system, not the
/// element's `viewBox` coordinate system. Omitted nested SVG dimensions use
/// the corresponding parent viewport dimension per SVG's `100%` default.
ui.Size? resolveSvgViewportSize(SvgNode node, SvgDocument document) {
  var width = resolveSvgLength(
    node,
    document,
    'width',
    reference: SvgLengthReference.horizontal,
  );
  var height = resolveSvgLength(
    node,
    document,
    'height',
    reference: SvgLengthReference.vertical,
  );

  if (node.tagName == 'svg' && (width == null || height == null)) {
    final parentViewport = _resolveNearestViewportSize(node, document);
    width ??= parentViewport.width;
    height ??= parentViewport.height;
  }

  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return ui.Size(width, height);
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

    // A viewBox establishes this element's user coordinate system. It wins
    // over an instantiating <use> viewport, whose size only applies after the
    // viewBox-to-viewport transform. <foreignObject> percentages use its
    // physical viewport, not a viewBox.
    final viewBox = _parseViewBox(current.getAttributeValue('viewBox'));
    if (current.tagName != 'foreignObject' &&
        viewBox != null &&
        viewBox.width > 0 &&
        viewBox.height > 0) {
      return ui.Size(viewBox.width, viewBox.height);
    }

    // A <use> instance establishes a viewport for the referenced
    // <symbol>/<svg>. Prefer that over definition-site DOM ancestry.
    final contextualViewport = _currentScope?.viewportsByNode[current];
    if (contextualViewport != null &&
        contextualViewport.width > 0 &&
        contextualViewport.height > 0) {
      return contextualViewport;
    }

    var width = resolveSvgLength(
      current,
      document,
      'width',
      reference: SvgLengthReference.horizontal,
    );
    var height = resolveSvgLength(
      current,
      document,
      'height',
      reference: SvgLengthReference.vertical,
    );

    // For nested <svg>, an omitted viewport dimension has a used value of
    // 100% of the parent viewport. This default does not apply to
    // <foreignObject> or <symbol>.
    if (current.tagName == 'svg' && (width == null || height == null)) {
      final parentViewport = _resolveNearestViewportSize(current, document);
      width ??= parentViewport.width;
      height ??= parentViewport.height;
    }
    if (width != null && height != null && width > 0 && height > 0) {
      return ui.Size(width, height);
    }
  }

  final rootViewBox = document.activeViewBox;
  if (rootViewBox != null && rootViewBox.width > 0 && rootViewBox.height > 0) {
    return ui.Size(rootViewBox.width, rootViewBox.height);
  }

  // The embedding widget negotiates the root viewport for a dimensionless
  // root SVG; it must not fall back to a fixed 100×100 once one exists.
  final rootViewport = _currentScope?.rootViewport;
  if (rootViewport != null &&
      rootViewport.width > 0 &&
      rootViewport.height > 0) {
    return rootViewport;
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
