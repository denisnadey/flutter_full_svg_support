import 'package:flutter/widgets.dart';

/// A theme used when decoding and rendering an SVG picture.
///
/// Controls how context-sensitive SVG values are resolved:
///
///  * [currentColor] resolves the `currentColor` keyword.
///  * [fontSize] resolves `em` length units.
///  * [xHeight] resolves `ex` length units.
@immutable
class SvgTheme {
  /// Instantiates an SVG theme with the [currentColor] and [fontSize].
  ///
  /// Defaults the [fontSize] to 14.
  const SvgTheme({
    this.currentColor = const Color(0xFF000000),
    this.fontSize = 14,
    double? xHeight,
  }) : xHeight = xHeight ?? fontSize / 2;

  /// The default color applied to SVG elements that inherit the `color`
  /// property (the `currentColor` keyword).
  ///
  /// See: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#currentcolor_keyword
  final Color currentColor;

  /// The font size used when resolving `em` length units of SVG elements.
  ///
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units
  final double fontSize;

  /// The x-height (corpus size) of the font used when resolving `ex` units.
  ///
  /// Defaults to [fontSize] / 2 if not provided.
  ///
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units, https://en.wikipedia.org/wiki/X-height
  final double xHeight;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SvgTheme &&
        currentColor == other.currentColor &&
        fontSize == other.fontSize &&
        xHeight == other.xHeight;
  }

  @override
  int get hashCode => Object.hash(currentColor, fontSize, xHeight);

  @override
  String toString() =>
      'SvgTheme(currentColor: $currentColor, fontSize: $fontSize, xHeight: $xHeight)';
}

/// A class that transforms one color into another during SVG parsing.
///
/// Implementations must be immutable so they are suitable for use as part of
/// an SVG cache key.
@immutable
abstract class ColorMapper {
  /// Allows const constructors on subclasses.
  const ColorMapper();

  /// Returns a new color to use in place of [color].
  ///
  /// Called for every literal color encountered while parsing the SVG.
  /// [id] is the owning element's `id` (if any), [elementName] is its tag
  /// name, and [attributeName] is the attribute the color was read from
  /// (for example `fill`, `stroke`, or `stop-color`).
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  );
}
