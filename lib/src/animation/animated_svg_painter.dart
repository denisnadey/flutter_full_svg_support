import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'css_animations.dart';
import 'css_cascade.dart';
import 'css_named_colors.dart';
import 'css_variables_calc.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'smil/motion_path.dart';
import 'switch_processing.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';
import 'svg_transform.dart';
import 'transform_3d.dart';

part 'animated_svg_painter_cache.dart';
part 'animated_svg_painter_types.dart';
part 'animated_svg_painter_text_types.dart';
part 'animated_svg_painter_use_constants.dart';
part 'animated_svg_painter_use_context.dart';
part 'animated_svg_painter_use.dart';
part 'animated_svg_painter_use_foreign_object.dart';
part 'animated_svg_painter_tree.dart';
part 'animated_svg_painter_clip_mask.dart';
part 'animated_svg_painter_clip_mask_geometry.dart';
part 'animated_svg_painter_clip_mask_units.dart';
part 'animated_svg_painter_clip_nested.dart';
part 'animated_svg_painter_mask_luminance.dart';
part 'animated_svg_painter_mask_clip_combination.dart';
part 'animated_svg_painter_clip_mask_composition.dart';
part 'animated_svg_painter_clip_mask_advanced.dart';
part 'animated_svg_painter_shapes_basic.dart';
part 'animated_svg_painter_shapes_lines.dart';
part 'animated_svg_painter_shapes_rect.dart';
part 'animated_svg_painter_shapes_image.dart';
part 'animated_svg_painter_shapes_paths.dart';
part 'animated_svg_painter_text_paint.dart';
part 'animated_svg_painter_text_paint_path.dart';
part 'animated_svg_painter_text_paint_glyph.dart';
part 'animated_svg_painter_text_paint_plain.dart';
part 'animated_svg_painter_text_style.dart';
part 'animated_svg_painter_text_style_font.dart';
part 'animated_svg_painter_text_style_decoration.dart';
part 'animated_svg_painter_text_style_layout.dart';
part 'animated_svg_painter_text_style_resolution.dart';
part 'animated_svg_painter_text_positioning.dart';
part 'animated_svg_painter_text_style_rendering.dart';
part 'animated_svg_painter_text_decoration.dart';
part 'animated_svg_painter_text_layout_measurement.dart';
part 'animated_svg_painter_text_layout_render.dart';
part 'animated_svg_painter_text_measurement.dart';
part 'animated_svg_painter_svg_fonts.dart';
part 'animated_svg_painter_geometry.dart';
part 'animated_svg_painter_geometry_foreign_object.dart';
part 'animated_svg_painter_geometry_path.dart';
part 'animated_svg_painter_paints.dart';
part 'animated_svg_painter_gradients.dart';
part 'animated_svg_painter_gradients_resolver.dart';
part 'animated_svg_painter_gradients_values.dart';
part 'animated_svg_painter_matrix.dart';
part 'animated_svg_painter_values.dart';
part 'animated_svg_painter_transform.dart';
part 'animated_svg_painter_markers.dart';
part 'animated_svg_painter_patterns.dart';
part 'animated_svg_painter_paint_order.dart';

/// CustomPainter for rendering an animated SVG
///
/// Uses SvgDocument with already-applied animated attribute values
/// (via AnimatableSvgAttribute.effectiveValue).
///
/// For static subtrees (hasAnimations = false), cachedPicture can be used
/// for optimization.
class AnimatedSvgPainter extends CustomPainter {
  /// Creates a painter for an animated SVG
  AnimatedSvgPainter({
    required this.document,
    this.backgroundColor,
    this.imagesByHref = const <String, ui.Image>{},
    this.convolvedImagesByFilterKey = const <String, ui.Image>{},
    this.lightingImagesByFilterKey = const <String, ui.Image>{},
    this.displacementImagesByFilterKey = const <String, ui.Image>{},
    this.animationTime,
    this.hasAnimations = false,
    _RenderCache? renderCache,
  }) : _renderCache = renderCache ?? _RenderCache();

  /// SVG document with current (animated) attribute values
  final SvgDocument document;

  /// Background color (optional)
  final ui.Color? backgroundColor;

  /// Decoded raster images keyed by raw `href`/`xlink:href` value.
  final Map<String, ui.Image> imagesByHref;

  /// Precomputed convolution outputs keyed by `<href>|<filterId>`.
  final Map<String, ui.Image> convolvedImagesByFilterKey;

  /// Precomputed lighting outputs keyed by `<href>|<filterId>|<size>|<kind>`.
  final Map<String, ui.Image> lightingImagesByFilterKey;

  /// Precomputed displacement outputs keyed by `<filterId>|<size>`.
  final Map<String, ui.Image> displacementImagesByFilterKey;

  /// Current animation time in seconds (for cache invalidation).
  final double? animationTime;

  /// Whether the document has animations.
  final bool hasAnimations;

  /// Performance cache for computed render values.
  final _RenderCache _renderCache;

  final Map<String, _ResolvedGradientDefinition?> _gradientCache =
      <String, _ResolvedGradientDefinition?>{};
  final Map<String, _ResolvedMarkerDefinition?> _markerCache =
      <String, _ResolvedMarkerDefinition?>{};
  final Map<String, _ResolvedPatternDefinition?> _patternCache =
      <String, _ResolvedPatternDefinition?>{};
  final Map<String, MotionPath> _motionPathCache = <String, MotionPath>{};
  Map<String, _SvgFontDefinition>? _svgFontsByFamilyCache;
  Map<String, _SvgFontDefinition>? _svgFontsByIdCache;
  Map<String, String>? _svgFontFamilyToFontIdCache;
  bool _currentPassPaintFill = true;
  bool _currentPassPaintStroke = true;
  ui.Color? _currentPassFillColorOverride;
  ui.Color? _currentPassStrokeColorOverride;
  SvgFilterPaintPass? _currentFilterPass;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Prepare cache for this frame
    _renderCache.prepareFrame(animationTime, hasAnimations);

    // Clear definition caches when animation time changes, so animated
    // stop-color, marker, and pattern values are re-read from DOM nodes.
    if (hasAnimations) {
      _gradientCache.clear();
      _markerCache.clear();
      _patternCache.clear();
    }

    // Set up CSS rules from document for use-referenced content resolution
    _currentDocumentCssRules = document.cssSelectorRules;
    _currentDocumentCssResolver = _currentDocumentCssRules == null
        ? null
        : CssCascadeResolver(cssRules: _currentDocumentCssRules!);

    // Apply background:
    // 1) explicit widget parameter backgroundColor
    // 2) fallback to root SVG style/background-color
    final resolvedBackgroundColor =
        backgroundColor ?? _resolveDocumentBackgroundColor();
    if (resolvedBackgroundColor != null) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Paint()..color = resolvedBackgroundColor,
      );
    }

    // Compute the viewBox → size transform
    final transform = _computeViewBoxTransform(size);

    canvas.save();
    canvas.transform(transform.storage);

    // Paint the root node
    _paintNode(canvas, document.root);

    canvas.restore();

    // Clean up global CSS rules reference
    _currentDocumentCssRules = null;
    _currentDocumentCssResolver = null;
  }

  /// Computes the transformation matrix for the viewBox
  Matrix4 _computeViewBoxTransform(ui.Size size) {
    // Use active viewBox (from <view> element if selected, otherwise root viewBox)
    final viewBox = document.activeViewBox;

    if (viewBox == null) {
      // Without a viewBox, use 1:1 scale
      return Matrix4.identity();
    }

    final layout = resolveSvgViewportLayout(
      viewport: ui.Rect.fromLTWH(0, 0, size.width, size.height),
      sourceSize: viewBox.size,
      preserveAspectRatio: document.activePreserveAspectRatio,
    );
    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }

  ui.Color? _resolveDocumentBackgroundColor() {
    final root = document.root;

    final backgroundAttr = _getString(root, 'background-color');
    if (backgroundAttr != null && backgroundAttr.trim().isNotEmpty) {
      final color = _parseColor(backgroundAttr);
      if (color != null) {
        return color;
      }
    }

    final styleAttr = _getString(root, 'style');
    if (styleAttr == null || styleAttr.trim().isEmpty) {
      return null;
    }

    for (final declaration in styleAttr.split(';')) {
      final colonIndex = declaration.indexOf(':');
      if (colonIndex <= 0) {
        continue;
      }
      final property = declaration
          .substring(0, colonIndex)
          .trim()
          .toLowerCase();
      if (property != 'background-color') {
        continue;
      }
      final value = declaration.substring(colonIndex + 1).trim();
      if (value.isEmpty) {
        continue;
      }
      final color = _parseColor(value);
      if (color != null) {
        return color;
      }
    }

    return null;
  }

  /// Paints a node and its children
  void _paintNode(ui.Canvas canvas, SvgNode node, {Set<String>? useStack}) {
    _paintNodeImpl(this, canvas, node, useStack: useStack);
  }

  /// Measures node bounds in current SVG user units.
  ui.Rect measureNodeBounds(SvgNode node) {
    return _getNodeBounds(node);
  }

  /// Paints a node subtree to the provided canvas.
  ///
  /// When [ignoreFilter] is true, the node-level `filter` attribute is
  /// temporarily disabled so callers can capture SourceGraphic content.
  void paintNodeForRaster(
    ui.Canvas canvas,
    SvgNode node, {
    bool ignoreFilter = false,
  }) {
    final originalFilter = ignoreFilter
        ? node.getRawAttributeValue('filter')
        : null;
    final shouldDisableFilter =
        originalFilter != null && originalFilter.trim().isNotEmpty;
    if (shouldDisableFilter) {
      node.setAttribute('filter', 'none', rawValue: 'none');
    }

    try {
      _paintNode(canvas, node);
    } finally {
      if (shouldDisableFilter) {
        node.setAttribute('filter', originalFilter, rawValue: originalFilter);
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedSvgPainter oldDelegate) {
    // Always repaint, as animations may have changed values
    return true;
  }

  @override
  bool shouldRebuildSemantics(AnimatedSvgPainter oldDelegate) {
    return false;
  }
}
