/// CSS custom properties (variables) and calc() expression support.
library;

import 'dart:ui' show Size;

import 'svg_dom.dart';

part 'css_variables_calc_properties.dart';
part 'css_variables_calc_resolver.dart';
part 'css_variables_calc_evaluator.dart';
part 'css_variables_calc_combined.dart';

/// Callback type for looking up custom properties from use context.
/// This enables CSS variables to flow through <use> boundaries.
typedef UseContextCustomPropertyLookup = String? Function(String name);

/// Global hook for use context custom property lookup.
/// Set by the render tree when inside a <use> boundary.
/// Made public for access from part files.
UseContextCustomPropertyLookup? useContextCustomPropertyLookup;

/// Regex to match CSS custom property declarations: --property-name: value
final RegExp _customPropertyDeclarationRegex = RegExp(
  r'(--[\w-]+)\s*:\s*([^;]+)',
  caseSensitive: false,
);

/// Unit conversion factors to pixels (base unit)
const Map<String, double> _unitToPixels = {
  'px': 1.0,
  'pt': 1.333333, // 1pt = 4/3 px
  'pc': 16.0, // 1pc = 16px
  'in': 96.0, // 1in = 96px
  'cm': 37.795276, // 1cm ≈ 37.8px
  'mm': 3.7795276, // 1mm ≈ 3.78px
  'q': 0.94488189, // 1Q = 1/40 cm
};

/// Default font size for em/rem calculations
const double _defaultFontSize = 16.0;
