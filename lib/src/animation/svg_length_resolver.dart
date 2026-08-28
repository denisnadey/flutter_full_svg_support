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

/// A length represented as the sum of an absolute user-unit component and a
/// viewport-relative percentage component.
///
/// SMIL computes animation values before painting, when an embedding viewport
/// may not be available. Keeping both components preserves their semantics
/// until [resolveSvgLength] / [resolveSvgLengthValue] can resolve the
/// percentage in the active viewport.
class SvgLengthPercentageValue {
  const SvgLengthPercentageValue({
    required this.absolute,
    required this.percentage,
  });

  /// The unitless / absolute component in SVG user units.
  final double absolute;

  /// The percentage component, expressed as percentage points.
  final double percentage;

  static final RegExp _pattern = RegExp(
    r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*(%|[a-zA-Z]*)$',
  );

  /// Parses the renderer's supported length syntax into its two components.
  ///
  /// Non-percentage units intentionally retain the renderer's existing numeric
  /// fallback behavior and use their numeric component as an absolute length.
  static SvgLengthPercentageValue? tryParse(Object? value) {
    if (value is SvgLengthPercentageValue) {
      return value;
    }
    if (value is num) {
      return SvgLengthPercentageValue(
        absolute: value.toDouble(),
        percentage: 0,
      );
    }
    if (value is! String) {
      return null;
    }

    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      return null;
    }
    return SvgLengthPercentageValue(
      absolute: match.group(2) == '%' ? 0 : number,
      percentage: match.group(2) == '%' ? number : 0,
    );
  }

  /// Resolves this value against [viewport] using [reference].
  double resolve(ui.Size viewport, SvgLengthReference reference) {
    final dimension = switch (reference) {
      SvgLengthReference.horizontal => viewport.width,
      SvgLengthReference.vertical => viewport.height,
      SvgLengthReference.normalizedDiagonal => math.sqrt(
        (viewport.width * viewport.width + viewport.height * viewport.height) /
            2,
      ),
    };
    return absolute + percentage * dimension / 100;
  }

  /// Avoids introducing a wrapper for values that remain purely absolute.
  Object toAnimatedValue() => percentage == 0 ? absolute : this;
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
  final length = SvgLengthPercentageValue.tryParse(value);
  if (length == null) {
    return null;
  }
  return _resolveSvgLengthPercentageValue(
    node,
    length,
    reference: reference,
    document: document,
  );
}

/// Resolves an already-computed length in [node]'s coordinate system.
///
/// Unlike [resolveSvgLength], [value] does not have to be an attribute stored
/// on the node — it may be a `SvgLengthPercentageValue` produced by SMIL
/// interpolation, a percentage string, or a plain number.
double? resolveSvgLengthValue(
  SvgNode node,
  Object? value, {
  required SvgLengthReference reference,
}) {
  final length = SvgLengthPercentageValue.tryParse(value);
  if (length == null) {
    return null;
  }
  return _resolveSvgLengthPercentageValue(node, length, reference: reference);
}

/// Resolves a numeric SVG attribute whose percentage semantics are not
/// geometry-specific.
///
/// Geometry attributes remain the responsibility of their existing horizontal,
/// vertical, or radial length resolvers. This helper closes the consumers for
/// deferred SMIL values used by stroke painting and opacity.
double? resolveSvgNumericAttributeValue(
  SvgNode node,
  Object? value,
  String attributeName,
) {
  final length = SvgLengthPercentageValue.tryParse(value);
  if (length == null) {
    return null;
  }

  switch (attributeName) {
    case 'stroke-width':
    case 'stroke-dashoffset':
      return resolveSvgLengthValue(
        node,
        length,
        reference: SvgLengthReference.normalizedDiagonal,
      );
    case 'opacity':
    case 'fill-opacity':
    case 'stroke-opacity':
    case 'stop-opacity':
    case 'offset':
      return length.absolute + length.percentage / 100;
    default:
      return null;
  }
}

double _resolveSvgLengthPercentageValue(
  SvgNode node,
  SvgLengthPercentageValue length, {
  required SvgLengthReference reference,
  SvgDocument? document,
}) {
  if (length.percentage == 0) {
    return length.absolute;
  }
  return length.resolve(_resolveNearestViewportSize(node, document), reference);
}

/// Returns the viewport against which [node]'s percentage lengths resolve.
///
/// This is the same nearest-viewport lookup used by [resolveSvgLengthValue],
/// exposed so callers such as the SMIL paced key-time cache can key on the
/// actually-applicable viewport (root embedding viewport for a `<use>`'s own
/// attributes, or a scoped `<use>`-instance viewport when one is active)
/// rather than only the root embedding viewport.
ui.Size resolveSvgNodeViewport(SvgNode node, SvgDocument? document) {
  return _resolveNearestViewportSize(node, document);
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

ui.Size _resolveNearestViewportSize(SvgNode node, [SvgDocument? document]) {
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

    var width = document == null
        ? resolveSvgLengthValue(
            current,
            current.getAttributeValue('width'),
            reference: SvgLengthReference.horizontal,
          )
        : resolveSvgLength(
            current,
            document,
            'width',
            reference: SvgLengthReference.horizontal,
          );
    var height = document == null
        ? resolveSvgLengthValue(
            current,
            current.getAttributeValue('height'),
            reference: SvgLengthReference.vertical,
          )
        : resolveSvgLength(
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

  final rootViewBox = document?.activeViewBox;
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

  final documentWidth = document?.width;
  final documentHeight = document?.height;
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
