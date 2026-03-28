part of 'animated_svg_painter.dart';

/// Text rendering utilities for SVG text styling.
///
/// This extension serves as a documentation marker. The implementation is split
/// across several specialized part files for maintainability:
///
/// - [AnimatedSvgPainterTextMeasurementExtension] in animated_svg_painter_text_measurement.dart:
///   Unicode processing, NFC normalization, grapheme cluster segmentation, BiDi handling
///
/// - [AnimatedSvgPainterTextLayoutExtension] in animated_svg_painter_text_layout.dart:
///   Paragraph building with font features, text path support, text content extraction,
///   layout computations, font variant features
///
/// - [AnimatedSvgPainterTextDecorationExtension] in animated_svg_painter_text_decoration.dart:
///   Decoration rendering (underline, overline, line-through), text shadow, text emphasis
///   marks, text transform (capitalize, uppercase, lowercase)
///
/// Key features across all extensions:
/// - Paragraph building with font features and variations
/// - Unicode bidirectional text handling (UAX #9 compliant)
/// - Text path support and spacing calculations
/// - Text content extraction with whitespace handling
/// - Grapheme cluster segmentation for complex scripts
/// - Combining marks and diacritics positioning
/// - NFC normalization for Unicode text
/// - Characters-based grapheme cluster iteration
extension AnimatedSvgPainterTextStyleRenderingExtension on AnimatedSvgPainter {
  // This extension is intentionally empty.
  // All text styling and rendering methods are implemented in the split part files:
  // - AnimatedSvgPainterTextMeasurementExtension (text measurement)
  // - AnimatedSvgPainterTextLayoutExtension (paragraph building and layout)
  // - AnimatedSvgPainterTextDecorationExtension (decoration rendering)
}
