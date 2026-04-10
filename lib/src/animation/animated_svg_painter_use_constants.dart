part of 'animated_svg_painter.dart';

/// Maximum recursion depth for nested <use> elements (matching Blink).
/// This prevents infinite loops and excessive resource usage.
const int _kMaxUseRecursionDepth = 10;

/// Global CSS rules available during painting.
/// Set by the painter when rendering begins.
List<CssSelectorRule>? _currentDocumentCssRules;

/// Cached CSS resolver for the currently painted document.
/// Reused across node lookups to avoid rebuilding cascade state.
CssCascadeResolver? _currentDocumentCssResolver;

/// CSS properties that are inherited by default per CSS/SVG specification.
/// Non-inherited properties (like opacity, transform, display) should NOT
/// flow through <use> boundaries.
const Set<String> _cssInheritablePropertiesForUse = {
  // Color properties
  'color',

  // Font properties
  'font',
  'font-family',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'font-feature-settings',
  'font-variation-settings',

  // Text properties
  'letter-spacing',
  'line-height',
  'text-align',
  'text-indent',
  'text-transform',
  'white-space',
  'word-spacing',
  'word-break',
  'word-wrap',
  'overflow-wrap',
  'direction',
  'writing-mode',
  'text-orientation',
  'dominant-baseline',
  'alignment-baseline',
  'baseline-shift',

  // SVG specific inheritable properties
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-opacity',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'marker',
  'marker-start',
  'marker-mid',
  'marker-end',
  'paint-order',
  'color-interpolation',
  'color-interpolation-filters',
  'color-rendering',
  'shape-rendering',
  'text-rendering',
  'image-rendering',

  // Visibility
  'visibility',
  'pointer-events',
  'cursor',

  // Text decoration (partially inheritable)
  'text-decoration',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',

  // Text emphasis
  'text-emphasis',
  'text-emphasis-color',
  'text-emphasis-position',
  'text-emphasis-style',
};

/// CSS properties that cross foreignObject boundaries.
/// These are the same inheritable properties that CSS defines,
/// which flow from SVG context into foreignObject HTML content.
/// Note: foreignObject establishes a new stacking context, so
/// non-inherited properties (transform, opacity, clip-path, etc.)
/// do NOT cross the boundary.
const Set<String> cssInheritablePropertiesForForeignObject =
    _cssInheritablePropertiesForUse;
