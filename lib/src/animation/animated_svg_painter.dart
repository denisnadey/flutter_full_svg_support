import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'path_data.dart';
import 'path_parser.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';
import 'svg_transform.dart';

/// CustomPainter для отрисовки анимированного SVG
///
/// Использует SvgDocument с уже применёнными анимированными значениями
/// атрибутов (через AnimatableSvgAttribute.effectiveValue).
///
/// Для статических поддеревьев (hasAnimations = false) можно использовать
/// cachedPicture для оптимизации.
class AnimatedSvgPainter extends CustomPainter {
  /// Создаёт painter для анимированного SVG
  AnimatedSvgPainter({
    required this.document,
    this.backgroundColor,
    this.imagesByHref = const <String, ui.Image>{},
  });

  /// SVG документ с актуальными (анимированными) значениями атрибутов
  final SvgDocument document;

  /// Фоновый цвет (опционально)
  final ui.Color? backgroundColor;

  /// Decoded raster images keyed by raw `href`/`xlink:href` value.
  final Map<String, ui.Image> imagesByHref;

  final Map<String, _ResolvedGradientDefinition?> _gradientCache =
      <String, _ResolvedGradientDefinition?>{};

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Применяем фон если указан
    if (backgroundColor != null) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Paint()..color = backgroundColor!,
      );
    }

    // Вычисляем трансформацию viewBox → size
    final transform = _computeViewBoxTransform(size);

    canvas.save();
    canvas.transform(transform.storage);

    // Рисуем корневой узел
    _paintNode(canvas, document.root);

    canvas.restore();
  }

  /// Вычисляет матрицу трансформации для viewBox
  Matrix4 _computeViewBoxTransform(ui.Size size) {
    final viewBox = document.viewBox;

    if (viewBox == null) {
      // Без viewBox используем 1:1 масштаб
      return Matrix4.identity();
    }

    // Вычисляем scale для fit
    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Центрируем
    final translateX =
        (size.width - viewBox.width * scale) / 2 - viewBox.left * scale;
    final translateY =
        (size.height - viewBox.height * scale) / 2 - viewBox.top * scale;

    return Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale, scale);
  }

  /// Рисует узел и его детей
  void _paintNode(ui.Canvas canvas, SvgNode node, {Set<String>? useStack}) {
    final display = node.getAttributeValue('display') as String?;
    if (display == 'none') return;

    final visibility = node.getAttributeValue('visibility') as String?;
    final isHidden = visibility == 'hidden' || visibility == 'collapse';

    final currentUseStack = useStack ?? <String>{};
    canvas.save();

    // Применяем transform если есть
    _applyTransform(canvas, node);

    // Baseline foreignObject viewport: смещение + clip children областью.
    _applyForeignObjectViewport(canvas, node);

    // Применяем clipPath если есть.
    _applyClipPath(canvas, node, useStack: currentUseStack);

    // Применяем mask если есть (baseline geometry mask).
    _applyMask(canvas, node, useStack: currentUseStack);

    final filterPasses = _resolveFilterPasses(node);

    // Рисуем сам узел в зависимости от типа
    if (!isHidden) {
      switch (node.tagName) {
        case 'rect':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintRect(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'circle':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintCircle(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'ellipse':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintEllipse(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'path':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintPath(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'polygon':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintPolygon(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'polyline':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintPolyline(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'line':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintLine(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'image':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintImage(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'text':
          _paintWithFilterPasses(
            canvas,
            filterPasses,
            (imageFilter, colorFilter, blendMode) => _paintText(
              canvas,
              node,
              imageFilter: imageFilter,
              colorFilter: colorFilter,
              blendMode: blendMode,
            ),
          );
          break;
        case 'tspan':
          // Рендерится из родительского <text> прохода.
          break;
        case 'textPath':
          // Рендерится из родительского <text> прохода.
          break;
        case 'use':
          _paintUse(canvas, node, useStack: currentUseStack);
          break;
        case 'g':
        case 'svg':
        case 'foreignObject':
          // Группы не рисуются, только применяют атрибуты к детям
          break;
        default:
          // Игнорируем неподдерживаемые элементы (animate, text, etc.)
          break;
      }
    }

    // Рекурсивно рисуем детей.
    if (_shouldPaintChildren(node)) {
      for (final child in node.children) {
        _paintNode(canvas, child, useStack: currentUseStack);
      }
    }

    canvas.restore();
  }

  List<SvgFilterPaintPass> _resolveFilterPasses(SvgNode node) {
    final filterId = _getFilterId(node);
    if (filterId == null || document.filters == null) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }
    final passes = document.filters!.resolvePaintPasses(filterId);
    if (passes.isEmpty) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }
    return passes;
  }

  void _paintWithFilterPasses(
    ui.Canvas canvas,
    List<SvgFilterPaintPass> passes,
    void Function(
      ui.ImageFilter? imageFilter,
      ui.ColorFilter? colorFilter,
      ui.BlendMode? blendMode,
    )
    paint,
  ) {
    for (final pass in passes) {
      canvas.save();
      if (pass.offset != ui.Offset.zero) {
        canvas.translate(pass.offset.dx, pass.offset.dy);
      }
      paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
      canvas.restore();
    }
  }

  void _applyForeignObjectViewport(ui.Canvas canvas, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }

    canvas.translate(x, y);
    canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height), doAntiAlias: true);
  }

  void _paintUse(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final hrefId = _extractHrefId(node);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;

    canvas.save();
    canvas.translate(x, y);

    final nextUseStack = <String>{...useStack, hrefId};
    if (referenced.tagName == 'symbol') {
      _paintSymbolReference(
        canvas,
        useNode: node,
        symbolNode: referenced,
        useStack: nextUseStack,
      );
    } else {
      _paintNode(canvas, referenced, useStack: nextUseStack);
    }

    canvas.restore();
  }

  void _paintSymbolReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode symbolNode,
    required Set<String> useStack,
  }) {
    final viewBox = _parseViewBox(_getString(symbolNode, 'viewBox'));
    final width = _getNumber(useNode, 'width');
    final height = _getNumber(useNode, 'height');

    if (viewBox != null &&
        width != null &&
        height != null &&
        width > 0 &&
        height > 0 &&
        viewBox.width > 0 &&
        viewBox.height > 0) {
      final scaleX = width / viewBox.width;
      final scaleY = height / viewBox.height;
      final scale = math.min(scaleX, scaleY);
      final translateX =
          (width - viewBox.width * scale) / 2 - viewBox.left * scale;
      final translateY =
          (height - viewBox.height * scale) / 2 - viewBox.top * scale;
      canvas.translate(translateX, translateY);
      canvas.scale(scale, scale);
    }

    for (final child in symbolNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }
  }

  bool _shouldPaintChildren(SvgNode node) {
    switch (node.tagName) {
      case 'defs':
      case 'symbol':
      case 'linearGradient':
      case 'radialGradient':
      case 'stop':
      case 'clipPath':
      case 'mask':
      case 'pattern':
      case 'filter':
      case 'use':
      case 'text':
      case 'tspan':
      case 'textPath':
      case 'image':
        return false;
      case 'foreignObject':
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return width > 0 && height > 0;
      default:
        return true;
    }
  }

  void _applyClipPath(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final clipId = _extractPaintServerId(node.getAttributeValue('clip-path'));
    if (clipId == null || clipId.isEmpty) {
      return;
    }

    final clipNode = document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return;
    }

    final clipPath = _buildClipPathForNode(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );
    if (clipPath == null) {
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  void _applyMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final maskId = _extractPaintServerId(node.getAttributeValue('mask'));
    if (maskId == null || maskId.isEmpty) {
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return;
    }

    final maskPath = _buildMaskPathForNode(
      maskedNode: node,
      maskNode: maskNode,
      useStack: useStack,
    );
    if (maskPath == null) {
      return;
    }

    canvas.clipPath(maskPath, doAntiAlias: true);
  }

  ui.Path? _buildClipPathForNode({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
  }) {
    final clipPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    final clipUnits = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    if (clipUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBounds(clippedNode);
      if (localBounds == null ||
          localBounds.width.abs() < 1e-6 ||
          localBounds.height.abs() < 1e-6) {
        return null;
      }
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, localBounds.width)
        ..setEntry(1, 1, localBounds.height)
        ..setEntry(0, 3, localBounds.left)
        ..setEntry(1, 3, localBounds.top);
    }

    _appendClipGeometry(
      target: clipPath,
      node: clipPathNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }

    return clipPath;
  }

  ui.Path? _buildMaskPathForNode({
    required SvgNode maskedNode,
    required SvgNode maskNode,
    required Set<String> useStack,
  }) {
    final maskPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    final contentUnits =
        (_getString(maskNode, 'maskContentUnits') ?? 'userSpaceOnUse')
            .trim()
            .toLowerCase();
    if (contentUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBounds(maskedNode);
      if (localBounds == null ||
          localBounds.width.abs() < 1e-6 ||
          localBounds.height.abs() < 1e-6) {
        return null;
      }
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, localBounds.width)
        ..setEntry(1, 1, localBounds.height)
        ..setEntry(0, 3, localBounds.left)
        ..setEntry(1, 3, localBounds.top);
    }

    _appendClipGeometry(
      target: maskPath,
      node: maskNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = maskPath.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }

    return maskPath;
  }

  void _appendClipGeometry({
    required ui.Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    final nodeTransform = _buildTransformMatrixFromValue(
      node.getAttributeValue('transform'),
    );
    if (nodeTransform != null) {
      matrix.multiply(nodeTransform);
    }

    switch (node.tagName) {
      case 'clipPath':
      case 'mask':
      case 'g':
      case 'svg':
        for (final child in node.children) {
          _appendClipGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
          );
        }
        return;
      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return;
        }
        final referenced = document.root.findById(hrefId);
        if (referenced == null) {
          return;
        }
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final translated = Matrix4.copy(matrix)
          ..multiply(
            Matrix4.identity()
              ..setEntry(0, 3, x)
              ..setEntry(1, 3, y),
          );
        final nextUseStack = <String>{...useStack, hrefId};
        _appendClipGeometry(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
        );
        return;
      default:
        final path = _buildGeometryPath(node);
        if (path == null) {
          return;
        }
        target.addPath(path.transform(matrix.storage), ui.Offset.zero);
    }
  }

  ui.Rect? _computeNodeLocalBounds(SvgNode node) {
    final path = _buildGeometryPath(node);
    if (path == null) {
      return null;
    }
    final bounds = path.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }
    return bounds;
  }

  /// Рисует <rect>
  void _paintRect(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? rx;

    if (width <= 0 || height <= 0) return;

    final rect = ui.Rect.fromLTWH(x, y, width, height);
    final fillPaint = _createFillPaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    if (fillPaint != null) {
      if (rx > 0 || ry > 0) {
        final rrect = ui.RRect.fromRectXY(rect, rx, ry);
        canvas.drawRRect(rrect, fillPaint);
      } else {
        canvas.drawRect(rect, fillPaint);
      }
    }

    // Stroke если указан.
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      // Convert to path for dasharray/dashoffset support.
      final strokePath = (rx > 0 || ry > 0)
          ? (ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry)))
          : (ui.Path()..addRect(rect));
      final dashedPath = _buildDashedPath(strokePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  /// Рисует <circle>
  void _paintCircle(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final r = _getNumber(node, 'r') ?? 0.0;

    if (r <= 0) return;

    final center = ui.Offset(cx, cy);
    final bounds = ui.Rect.fromCircle(center: center, radius: r);
    final fillPaint = _createFillPaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    if (fillPaint != null) {
      canvas.drawCircle(center, r, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final circlePath = ui.Path()..addOval(bounds);
      final dashedPath = _buildDashedPath(circlePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  /// Рисует <ellipse>
  void _paintEllipse(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? 0.0;

    if (rx <= 0 || ry <= 0) return;

    final rect = ui.Rect.fromCenter(
      center: ui.Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    final fillPaint = _createFillPaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    if (fillPaint != null) {
      canvas.drawOval(rect, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final ellipsePath = ui.Path()..addOval(rect);
      final dashedPath = _buildDashedPath(ellipsePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  /// Рисует <line>
  void _paintLine(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x1 = _getNumber(node, 'x1') ?? 0.0;
    final y1 = _getNumber(node, 'y1') ?? 0.0;
    final x2 = _getNumber(node, 'x2') ?? 0.0;
    final y2 = _getNumber(node, 'y2') ?? 0.0;

    final bounds = ui.Rect.fromPoints(ui.Offset(x1, y1), ui.Offset(x2, y2));
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final linePath = ui.Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2);
      final dashedPath = _buildDashedPath(linePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  void _paintImage(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final href = _extractImageHref(node);
    if (href == null || href.isEmpty) {
      return;
    }

    final image = imagesByHref[href];
    if (image == null) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? image.width.toDouble();
    final height = _getNumber(node, 'height') ?? image.height.toDouble();
    if (width <= 0 || height <= 0) {
      return;
    }

    final viewport = ui.Rect.fromLTWH(x, y, width, height);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final layout = _resolveImageLayout(
      viewport: viewport,
      imageSize: srcRect.size,
      preserveAspectRatio: _getString(node, 'preserveAspectRatio'),
    );

    final paint = ui.Paint();
    final opacity = (_getNumber(node, 'opacity') ?? 1.0).clamp(0.0, 1.0);
    paint.color = const ui.Color(0xFFFFFFFF).withValues(alpha: opacity);

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }

    if (layout.clipToViewport) {
      canvas.save();
      canvas.clipRect(viewport, doAntiAlias: true);
      canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
      canvas.restore();
      return;
    }

    canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
  }

  /// Рисует <path>
  void _paintPath(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final pathData = _getString(node, 'd');
    if (pathData == null || pathData.isEmpty) return;

    final path = _buildPath(pathData);
    if (path == null) return;

    final fillRule = _getString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (fillPaint != null) {
      canvas.drawPath(path, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final dashedPath = _buildDashedPath(path, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  void _paintPolygon(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final points = _parsePoints(node);
    if (points.length < 3) return;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    final fillRule = _getString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (fillPaint != null) {
      canvas.drawPath(path, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final dashedPath = _buildDashedPath(path, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  void _paintPolyline(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final points = _parsePoints(node);
    if (points.length < 2) return;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (fillPaint != null) {
      canvas.drawPath(path, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final dashedPath = _buildDashedPath(path, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

  void _paintText(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final startX = _getNumber(node, 'x') ?? 0.0;
    final startY = _getNumber(node, 'y') ?? 0.0;
    final cursor = _TextCursor(x: startX, y: startY);

    _paintTextNode(
      canvas,
      node,
      cursor,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
  }

  void _paintTextNode(
    ui.Canvas canvas,
    SvgNode node,
    _TextCursor cursor, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x = _getNumber(node, 'x');
    final y = _getNumber(node, 'y');
    final dx = _getNumber(node, 'dx') ?? 0.0;
    final dy = _getNumber(node, 'dy') ?? 0.0;

    if (x != null) {
      cursor.x = x;
    }
    if (y != null) {
      cursor.y = y;
    }
    cursor
      ..x += dx
      ..y += dy;

    final style = _resolveTextStyle(node);
    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      final consumed = _paintPlainText(
        canvas,
        text: text,
        style: style,
        x: cursor.x,
        baselineY: cursor.y,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      cursor.x += consumed;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _paintTextNode(
          canvas,
          child,
          cursor,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      } else if (child.tagName == 'textPath') {
        final consumed = _paintTextPathNode(
          canvas,
          child,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
        cursor.x += consumed;
      }
    }
  }

  double _paintTextPathNode(
    ui.Canvas canvas,
    SvgNode textPathNode, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final path = _resolveTextPathGeometry(textPathNode);
    if (path == null) {
      return 0.0;
    }
    final metricIterator = path.computeMetrics().iterator;
    if (!metricIterator.moveNext()) {
      return 0.0;
    }
    final metric = metricIterator.current;
    if (metric.length <= 0) {
      return 0.0;
    }

    double offset = _parseTextPathStartOffset(textPathNode, metric.length);
    var consumed = 0.0;

    final directText = _extractTextContent(textPathNode);
    if (directText != null && directText.isNotEmpty) {
      final style = _resolveTextStyle(textPathNode);
      final textConsumed = _paintTextAlongPath(
        canvas,
        text: directText,
        style: style,
        metric: metric,
        startOffset: offset,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    for (final child in textPathNode.children) {
      if (child.tagName != 'tspan') {
        continue;
      }
      final childText = _extractTextContent(child);
      if (childText == null || childText.isEmpty) {
        continue;
      }
      final style = _resolveTextStyle(child);
      final textConsumed = _paintTextAlongPath(
        canvas,
        text: childText,
        style: style,
        metric: metric,
        startOffset: offset,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }

  double _paintPlainText(
    ui.Canvas canvas, {
    required String text,
    required _ResolvedTextStyle style,
    required double x,
    required double baselineY,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final paragraph = _buildTextParagraph(text, style);
    final width = paragraph.maxIntrinsicWidth;
    var drawX = x;
    switch (style.textAnchor) {
      case _SvgTextAnchor.start:
        break;
      case _SvgTextAnchor.middle:
        drawX -= width / 2;
        break;
      case _SvgTextAnchor.end:
        drawX -= width;
        break;
    }
    final drawY = baselineY - paragraph.alphabeticBaseline;

    _drawParagraphWithEffects(
      canvas,
      paragraph: paragraph,
      x: drawX,
      y: drawY,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    return width;
  }

  double _paintTextAlongPath(
    ui.Canvas canvas, {
    required String text,
    required _ResolvedTextStyle style,
    required ui.PathMetric metric,
    required double startOffset,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final glyphs = text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (glyphs.isEmpty) {
      return 0.0;
    }

    final paragraphs = glyphs
        .map((glyph) => _buildTextParagraph(glyph, style))
        .toList(growable: false);
    final widths = paragraphs
        .map((paragraph) => paragraph.maxIntrinsicWidth)
        .toList(growable: false);
    final totalWidth = widths.fold<double>(0.0, (sum, w) => sum + w);

    var drawOffset = startOffset;
    switch (style.textAnchor) {
      case _SvgTextAnchor.start:
        break;
      case _SvgTextAnchor.middle:
        drawOffset -= totalWidth / 2;
        break;
      case _SvgTextAnchor.end:
        drawOffset -= totalWidth;
        break;
    }

    final needsLayer =
        imageFilter != null || colorFilter != null || blendMode != null;
    if (needsLayer) {
      final layerPaint = ui.Paint();
      if (imageFilter != null) {
        layerPaint.imageFilter = imageFilter;
      }
      if (colorFilter != null) {
        layerPaint.colorFilter = colorFilter;
      }
      if (blendMode != null) {
        layerPaint.blendMode = blendMode;
      }
      final pathBounds = metric
          .extractPath(0.0, metric.length)
          .getBounds()
          .inflate(style.fontSize * 2.0);
      canvas.saveLayer(pathBounds, layerPaint);
    }

    var consumed = 0.0;
    var cursor = drawOffset;
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final glyphWidth = widths[i];
      final center = (cursor + glyphWidth / 2).clamp(0.0, metric.length);
      final tangent = metric.getTangentForOffset(center);
      if (tangent == null) {
        cursor += glyphWidth;
        consumed += glyphWidth;
        continue;
      }

      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      canvas.drawParagraph(
        paragraph,
        ui.Offset(-glyphWidth / 2, -paragraph.alphabeticBaseline),
      );
      canvas.restore();

      cursor += glyphWidth;
      consumed += glyphWidth;
      if (cursor > metric.length + style.fontSize) {
        break;
      }
    }

    if (needsLayer) {
      canvas.restore();
    }
    return consumed;
  }

  _ResolvedTextStyle _resolveTextStyle(SvgNode node) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final fillColor =
        _resolveColorValue(fillValue) ?? const ui.Color(0xFF000000);
    final opacity = (_getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
      0.0,
      1.0,
    );
    final fillOpacity = (_getInheritedNumber(node, 'fill-opacity') ?? 1.0)
        .clamp(0.0, 1.0);
    final color = _applyOpacity(fillColor, opacity * fillOpacity);
    final fontFamily = _getInheritedString(node, 'font-family');
    final fontWeight = _resolveFontWeight(
      _getInheritedString(node, 'font-weight'),
    );
    final fontStyle = _resolveFontStyle(
      _getInheritedString(node, 'font-style'),
    );
    final textAnchor = _resolveTextAnchor(
      _getInheritedString(node, 'text-anchor'),
    );

    return _ResolvedTextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textAnchor: textAnchor,
    );
  }

  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
      ),
    );
    paragraphBuilder.pushStyle(
      ui.TextStyle(
        color: style.color,
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
      ),
    );
    paragraphBuilder.addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
    return paragraph;
  }

  void _drawParagraphWithEffects(
    ui.Canvas canvas, {
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    if (imageFilter == null && colorFilter == null && blendMode == null) {
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
      return;
    }

    final layerPaint = ui.Paint();
    if (imageFilter != null) {
      layerPaint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      layerPaint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      layerPaint.blendMode = blendMode;
    }
    final bounds = ui.Rect.fromLTWH(
      x,
      y,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    ).inflate(1.0);
    canvas.saveLayer(bounds, layerPaint);
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
    canvas.restore();
  }

  ui.Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') {
      return null;
    }

    final path = _buildGeometryPath(referenced);
    if (path == null) {
      return null;
    }

    final transform = _buildTransformMatrixFromValue(
      referenced.getAttributeValue('transform'),
    );
    if (transform == null) {
      return path;
    }
    return path.transform(transform.storage);
  }

  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) {
      return 0.0;
    }

    if (raw is num) {
      return raw.toDouble().clamp(0.0, pathLength);
    }

    final value = raw.toString().trim();
    if (value.isEmpty) {
      return 0.0;
    }

    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }

    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }

  String? _extractTextContent(SvgNode node) {
    final raw = _getString(node, '__text');
    if (raw == null) {
      return null;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  ui.Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? rx;
        if (width <= 0 || height <= 0) return null;
        final rect = ui.Rect.fromLTWH(x, y, width, height);
        if (rx > 0 || ry > 0) {
          return ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry));
        }
        return ui.Path()..addRect(rect);
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return null;
        return ui.Path()
          ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return null;
        return ui.Path()..addOval(
          ui.Rect.fromCenter(
            center: ui.Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        return ui.Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      case 'polygon':
        final polygon = _parsePoints(node);
        if (polygon.length < 3) return null;
        final polygonPath = ui.Path()
          ..moveTo(polygon.first.dx, polygon.first.dy);
        for (int i = 1; i < polygon.length; i++) {
          polygonPath.lineTo(polygon[i].dx, polygon[i].dy);
        }
        polygonPath.close();
        _applyPathFillType(polygonPath, node);
        return polygonPath;
      case 'polyline':
        final polyline = _parsePoints(node);
        if (polyline.length < 2) return null;
        final polylinePath = ui.Path()
          ..moveTo(polyline.first.dx, polyline.first.dy);
        for (int i = 1; i < polyline.length; i++) {
          polylinePath.lineTo(polyline[i].dx, polyline[i].dy);
        }
        _applyPathFillType(polylinePath, node);
        return polylinePath;
      case 'path':
        final pathData = _getString(node, 'd');
        if (pathData == null || pathData.isEmpty) return null;
        final parsed = _buildPath(pathData);
        if (parsed == null) return null;
        _applyPathFillType(parsed, node);
        return parsed;
      default:
        return null;
    }
  }

  void _applyPathFillType(ui.Path path, SvgNode node) {
    final fillRule =
        _getString(node, 'clip-rule')?.toLowerCase() ??
        _getString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;
  }

  ui.Path? _buildPath(String pathData) {
    List<PathCommand> commands;
    try {
      commands = PathParser().parse(pathData);
    } catch (_) {
      return null;
    }

    if (commands.isEmpty) {
      return null;
    }

    final path = ui.Path();
    double currentX = 0.0;
    double currentY = 0.0;
    double subPathStartX = 0.0;
    double subPathStartY = 0.0;
    PathCommand? previousCommand;

    for (final command in commands) {
      final absoluteCommand = command.toAbsolute(currentX, currentY);

      switch (absoluteCommand) {
        case MoveToCommand():
          path.moveTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          subPathStartX = currentX;
          subPathStartY = currentY;
          previousCommand = absoluteCommand;

        case LineToCommand():
          path.lineTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case HorizontalLineToCommand():
          path.lineTo(absoluteCommand.x, currentY);
          currentX = absoluteCommand.x;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case VerticalLineToCommand():
          path.lineTo(currentX, absoluteCommand.y);
          currentY = absoluteCommand.y;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case CubicBezierCommand():
          path.cubicTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x2,
            absoluteCommand.y2,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothCubicBezierCommand():
          final cubic = absoluteCommand.toCubicBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.cubicTo(
            cubic.x1,
            cubic.y1,
            cubic.x2,
            cubic.y2,
            cubic.x,
            cubic.y,
          );
          currentX = cubic.x;
          currentY = cubic.y;
          previousCommand = cubic;

        case QuadraticBezierCommand():
          path.quadraticBezierTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothQuadraticBezierCommand():
          final quadratic = absoluteCommand.toQuadraticBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.quadraticBezierTo(
            quadratic.x1,
            quadratic.y1,
            quadratic.x,
            quadratic.y,
          );
          currentX = quadratic.x;
          currentY = quadratic.y;
          previousCommand = quadratic;

        case ArcCommand():
          if (absoluteCommand.rx <= 0 || absoluteCommand.ry <= 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
          } else {
            path.arcToPoint(
              ui.Offset(absoluteCommand.x, absoluteCommand.y),
              radius: ui.Radius.elliptical(
                absoluteCommand.rx.abs(),
                absoluteCommand.ry.abs(),
              ),
              rotation: absoluteCommand.rotation,
              largeArc: absoluteCommand.largeArc,
              clockwise: absoluteCommand.sweep,
            );
          }
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case ClosePathCommand():
          path.close();
          currentX = subPathStartX;
          currentY = subPathStartY;
          previousCommand = absoluteCommand;
      }
    }

    return path;
  }

  ui.Paint? _createFillPaint(
    SvgNode node, {
    required ui.Rect paintBounds,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final fillValue = node.getAttributeValue('fill');
    if (_isPaintNone(fillValue)) {
      return null;
    }

    final opacity = _getNumber(node, 'opacity') ?? 1.0;
    final fillOpacity = _getNumber(node, 'fill-opacity') ?? 1.0;
    final finalOpacity = (opacity * fillOpacity).clamp(0.0, 1.0);

    final paint = ui.Paint()..style = ui.PaintingStyle.fill;
    final shader = _resolvePaintServerShader(fillValue, paintBounds);
    if (shader != null) {
      paint
        ..shader = shader
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: finalOpacity);
    } else {
      final color = _resolveColorValue(fillValue) ?? const ui.Color(0xFF000000);
      paint.color = _applyOpacity(color, finalOpacity);
    }

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }
    return paint;
  }

  /// Получить ID фильтра из атрибута filter
  /// Поддерживает формат url(#filterId) или просто filterId
  String? _getFilterId(SvgNode node) {
    final filterAttr = _getString(node, 'filter');
    if (filterAttr == null || filterAttr.isEmpty) {
      return null;
    }

    // Парсим url(#filterId) формат
    final urlMatch = RegExp(r'url\(#([^)]+)\)').firstMatch(filterAttr);
    if (urlMatch != null) {
      return urlMatch.group(1);
    }

    // Или просто ID если нет url()
    return filterAttr.trim();
  }

  /// Создаёт Paint для stroke (или null если нет stroke).
  ui.Paint? _createStrokePaint(
    SvgNode node, {
    required ui.Rect paintBounds,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final strokeValue = node.getAttributeValue('stroke');
    if (strokeValue == null || _isPaintNone(strokeValue)) {
      return null;
    }

    final strokeWidth = _getNumber(node, 'stroke-width') ?? 1.0;
    final opacity = _getNumber(node, 'opacity') ?? 1.0;
    final strokeOpacity = _getNumber(node, 'stroke-opacity') ?? 1.0;
    final finalOpacity = (opacity * strokeOpacity).clamp(0.0, 1.0);

    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final shader = _resolvePaintServerShader(strokeValue, paintBounds);
    if (shader != null) {
      paint
        ..shader = shader
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: finalOpacity);
    } else {
      final strokeColor = _resolveColorValue(strokeValue);
      if (strokeColor == null) {
        return null;
      }
      paint.color = _applyOpacity(strokeColor, finalOpacity);
    }

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }
    return paint;
  }

  /// Applies stroke-dasharray / stroke-dashoffset to a path.
  ///
  /// If stroke-dasharray is not set or is 'none', returns [path] unchanged.
  /// Otherwise walks the path's PathMetrics and builds a new dashed path.
  ui.Path _buildDashedPath(ui.Path path, SvgNode node) {
    final dashArrayRaw = _getInheritedString(node, 'stroke-dasharray')?.trim();
    if (dashArrayRaw == null ||
        dashArrayRaw.isEmpty ||
        dashArrayRaw.toLowerCase() == 'none') {
      return path;
    }

    final dashes = _parseDashArray(dashArrayRaw);
    if (dashes.isEmpty || dashes.every((d) => d == 0)) {
      return path;
    }

    // SVG spec: odd-length dasharray is doubled.
    final pattern = dashes.length.isOdd ? [...dashes, ...dashes] : dashes;

    final totalDash = pattern.fold<double>(0.0, (s, d) => s + d);
    if (totalDash <= 0) return path;

    final rawOffset = _getNumber(node, 'stroke-dashoffset') ?? 0.0;
    // Normalise offset into [0, totalDash). SVG offset shifts the pattern start.
    var phase = rawOffset % totalDash;
    if (phase < 0) phase += totalDash;

    // Find which pattern index corresponds to [phase].
    var patternIndex = 0;
    var phaseAccum = 0.0;
    for (int i = 0; i < pattern.length; i++) {
      if (phaseAccum + pattern[i] > phase) {
        patternIndex = i;
        phaseAccum = phase - phaseAccum; // consumed from current segment
        break;
      }
      phaseAccum += pattern[i];
      patternIndex = i + 1;
      if (patternIndex >= pattern.length) {
        patternIndex = 0;
        phaseAccum = 0;
      }
    }

    // remaining = how much is left in the current pattern segment.
    var remaining = pattern[patternIndex] - phaseAccum;
    var drawing = patternIndex.isEven; // even indices are dash, odd are gap

    final dashedPath = ui.Path();
    for (final metric in path.computeMetrics()) {
      final pathLength = metric.length;
      if (pathLength <= 0) continue;

      var pathPos = 0.0;
      var segRemaining = remaining;
      var segDrawing = drawing;
      var segPatternIndex = patternIndex;

      while (pathPos < pathLength) {
        final segEnd = math.min(pathPos + segRemaining, pathLength);
        if (segDrawing) {
          dashedPath.addPath(
            metric.extractPath(pathPos, segEnd),
            ui.Offset.zero,
          );
        }
        final consumed = segEnd - pathPos;
        pathPos = segEnd;
        segRemaining -= consumed;

        if (segRemaining <= 1e-6) {
          // Advance to next pattern segment.
          segPatternIndex = (segPatternIndex + 1) % pattern.length;
          segDrawing = !segDrawing;
          segRemaining = pattern[segPatternIndex];
        }
      }
    }

    return dashedPath;
  }

  /// Parses stroke-dasharray value into a list of doubles.
  List<double> _parseDashArray(String value) {
    return value
        .split(RegExp(r'[\s,]+'))
        .map((s) {
          final cleaned = s.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
          return double.tryParse(cleaned) ?? 0.0;
        })
        .where((d) => d >= 0)
        .toList();
  }

  ui.Shader? _resolvePaintServerShader(
    Object? paintValue,
    ui.Rect paintBounds,
  ) {
    final gradientId = _extractPaintServerId(paintValue);
    if (gradientId == null) {
      return null;
    }

    final gradient = _resolveGradientDefinition(gradientId);
    if (gradient == null || gradient.stops.isEmpty) {
      return null;
    }

    final bounds = _normalizePaintBounds(paintBounds);
    final gradientUnits = gradient.attributes['gradientUnits']
        ?.toString()
        .trim()
        .toLowerCase();
    final isUserSpaceOnUse = gradientUnits == 'userspaceonuse';
    final tileMode = _parseTileMode(gradient.attributes['spreadMethod']);
    final matrix4 = _parseGradientTransformMatrix(
      gradient.attributes['gradientTransform'],
    );
    final colors = gradient.stops.map((s) => s.color).toList(growable: false);
    final offsets = gradient.stops.map((s) => s.offset).toList(growable: false);

    if (gradient.type == 'linearGradient') {
      final x1 = _resolveGradientCoordinate(
        gradient.attributes['x1'],
        defaultValue: 0.0,
        axis: _GradientAxis.x,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final y1 = _resolveGradientCoordinate(
        gradient.attributes['y1'],
        defaultValue: 0.0,
        axis: _GradientAxis.y,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final x2 = _resolveGradientCoordinate(
        gradient.attributes['x2'],
        defaultValue: 100.0,
        axis: _GradientAxis.x,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final y2 = _resolveGradientCoordinate(
        gradient.attributes['y2'],
        defaultValue: 0.0,
        axis: _GradientAxis.y,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );

      return ui.Gradient.linear(
        ui.Offset(x1, y1),
        ui.Offset(x2, y2),
        colors,
        offsets,
        tileMode,
        matrix4,
      );
    }

    final cx = _resolveGradientCoordinate(
      gradient.attributes['cx'],
      defaultValue: 50.0,
      axis: _GradientAxis.x,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final cy = _resolveGradientCoordinate(
      gradient.attributes['cy'],
      defaultValue: 50.0,
      axis: _GradientAxis.y,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final radius = _resolveGradientCoordinate(
      gradient.attributes['r'],
      defaultValue: 50.0,
      axis: _GradientAxis.radius,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    if (radius <= 0) {
      return null;
    }

    final hasFocal =
        gradient.attributes.containsKey('fx') ||
        gradient.attributes.containsKey('fy');
    final focalX = _resolveGradientCoordinate(
      gradient.attributes['fx'] ?? gradient.attributes['cx'],
      defaultValue: 50.0,
      axis: _GradientAxis.x,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final focalY = _resolveGradientCoordinate(
      gradient.attributes['fy'] ?? gradient.attributes['cy'],
      defaultValue: 50.0,
      axis: _GradientAxis.y,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final focalRadius = _resolveGradientCoordinate(
      gradient.attributes['fr'],
      defaultValue: 0.0,
      axis: _GradientAxis.radius,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    ).clamp(0.0, radius);

    return ui.Gradient.radial(
      ui.Offset(cx, cy),
      radius,
      colors,
      offsets,
      tileMode,
      matrix4,
      hasFocal ? ui.Offset(focalX, focalY) : null,
      focalRadius,
    );
  }

  _ResolvedGradientDefinition? _resolveGradientDefinition(
    String gradientId, {
    Set<String>? visited,
  }) {
    if (visited == null) {
      final cached = _gradientCache[gradientId];
      if (cached != null || _gradientCache.containsKey(gradientId)) {
        return cached;
      }
    }

    final localVisited = visited ?? <String>{};
    if (!localVisited.add(gradientId)) {
      return null;
    }

    final node = document.root.findById(gradientId);
    if (node == null) {
      if (visited == null) {
        _gradientCache[gradientId] = null;
      }
      return null;
    }

    if (node.tagName != 'linearGradient' && node.tagName != 'radialGradient') {
      if (visited == null) {
        _gradientCache[gradientId] = null;
      }
      return null;
    }

    _ResolvedGradientDefinition? inherited;
    final hrefId = _extractHrefId(node);
    if (hrefId != null) {
      inherited = _resolveGradientDefinition(hrefId, visited: localVisited);
    }

    final attributes = <String, Object?>{};
    if (inherited != null) {
      attributes.addAll(inherited.attributes);
    }
    for (final entry in node.attributes.entries) {
      attributes[entry.key] = entry.value.effectiveValue;
    }

    final ownStops = _parseGradientStops(node);
    final stops = ownStops.isNotEmpty ? ownStops : inherited?.stops;
    final resolved = _ResolvedGradientDefinition(
      type: node.tagName,
      attributes: attributes,
      stops: stops ?? const <_GradientStop>[],
    );

    if (visited == null) {
      _gradientCache[gradientId] = resolved;
    }
    return resolved;
  }

  List<_GradientStop> _parseGradientStops(SvgNode gradientNode) {
    final stops = <_GradientStop>[];
    for (final child in gradientNode.children) {
      if (child.tagName != 'stop') {
        continue;
      }

      final offset = _parseStopOffset(child.getAttributeValue('offset'));
      final styleStopColor = _extractStyleValue(child, 'stop-color');
      final styleStopOpacity = _extractStyleValue(child, 'stop-opacity');
      final stopColorValue =
          child.getAttributeValue('stop-color') ?? styleStopColor;
      final stopColor =
          _resolveColorValue(stopColorValue) ?? const ui.Color(0xFF000000);

      final stopOpacity =
          _parseOpacityValue(
            child.getAttributeValue('stop-opacity') ?? styleStopOpacity,
          ) ??
          1.0;
      final opacity =
          (_parseOpacityValue(child.getAttributeValue('opacity')) ?? 1.0).clamp(
            0.0,
            1.0,
          );

      stops.add(
        _GradientStop(
          offset: offset,
          color: _applyOpacity(
            stopColor,
            (stopOpacity * opacity).clamp(0.0, 1.0),
          ),
        ),
      );
    }

    if (stops.isEmpty) {
      return const <_GradientStop>[];
    }

    stops.sort((a, b) => a.offset.compareTo(b.offset));

    if (stops.length == 1) {
      final only = stops.first;
      return <_GradientStop>[
        _GradientStop(offset: 0.0, color: only.color),
        _GradientStop(offset: 1.0, color: only.color),
      ];
    }

    return stops;
  }

  String? _extractStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) {
        continue;
      }
      final key = parts.first.trim().toLowerCase();
      if (key != property) {
        continue;
      }
      final value = parts.sublist(1).join(':').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _extractPaintServerId(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final match = RegExp(
      'url\\(\\s*[\'"]?#([^\'"\\)\\s]+)[\'"]?\\s*\\)',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1);
  }

  String? _extractHrefId(SvgNode node) {
    final href =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (href == null) {
      return null;
    }

    final raw = href.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('#')) {
      return raw.substring(1);
    }

    return _extractPaintServerId(raw);
  }

  String? _extractImageHref(SvgNode node) {
    final rawHref =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (rawHref == null) {
      return null;
    }
    final href = rawHref.toString().trim();
    return href.isEmpty ? null : href;
  }

  _ImageLayout _resolveImageLayout({
    required ui.Rect viewport,
    required ui.Size imageSize,
    String? preserveAspectRatio,
  }) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return _ImageLayout(destinationRect: viewport, clipToViewport: false);
    }

    final tokens = (preserveAspectRatio ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .where((token) => token.toLowerCase() != 'defer')
        .toList();

    final alignToken = tokens.isEmpty ? 'xMidYMid' : tokens.first;
    final fitToken = tokens.length > 1 ? tokens.last.toLowerCase() : 'meet';

    if (alignToken.toLowerCase() == 'none') {
      return _ImageLayout(destinationRect: viewport, clipToViewport: false);
    }

    final scaleX = viewport.width / imageSize.width;
    final scaleY = viewport.height / imageSize.height;
    final useSlice = fitToken == 'slice';
    final scale = useSlice
        ? math.max(scaleX, scaleY)
        : math.min(scaleX, scaleY);

    final drawWidth = imageSize.width * scale;
    final drawHeight = imageSize.height * scale;

    final alignLower = alignToken.toLowerCase();
    final alignX = alignLower.contains('xmin')
        ? 0.0
        : alignLower.contains('xmax')
        ? 1.0
        : 0.5;
    final alignY = alignLower.contains('ymin')
        ? 0.0
        : alignLower.contains('ymax')
        ? 1.0
        : 0.5;

    final dx = viewport.left + (viewport.width - drawWidth) * alignX;
    final dy = viewport.top + (viewport.height - drawHeight) * alignY;

    return _ImageLayout(
      destinationRect: ui.Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
      clipToViewport: useSlice,
    );
  }

  bool _isPaintNone(Object? value) {
    final str = value?.toString().trim().toLowerCase();
    return str == 'none';
  }

  ui.Rect _normalizePaintBounds(ui.Rect bounds) {
    final width = bounds.width.abs() < 1e-6 ? 1.0 : bounds.width.abs();
    final height = bounds.height.abs() < 1e-6 ? 1.0 : bounds.height.abs();
    return ui.Rect.fromLTWH(bounds.left, bounds.top, width, height);
  }

  ui.TileMode _parseTileMode(Object? spreadMethod) {
    final value = spreadMethod?.toString().trim().toLowerCase();
    switch (value) {
      case 'repeat':
        return ui.TileMode.repeated;
      case 'reflect':
        return ui.TileMode.mirror;
      case 'pad':
      default:
        return ui.TileMode.clamp;
    }
  }

  ui.Color? _resolveColorValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is ui.Color) {
      return value;
    }
    return _parseColor(value.toString());
  }

  ui.Color _applyOpacity(ui.Color color, double opacity) {
    final alpha = (color.a * opacity).clamp(0.0, 1.0);
    return color.withValues(alpha: alpha);
  }

  double _resolveGradientCoordinate(
    Object? rawValue, {
    required double defaultValue,
    required _GradientAxis axis,
    required ui.Rect bounds,
    required bool isUserSpaceOnUse,
  }) {
    final parsed = _parseGradientLength(rawValue, defaultValue: defaultValue);
    final value = parsed.value;

    if (!isUserSpaceOnUse) {
      final ratio = parsed.isPercent
          ? value / 100.0
          : _normalizeObjectBoundingBoxValue(value, rawValue);
      switch (axis) {
        case _GradientAxis.x:
          return bounds.left + bounds.width * ratio;
        case _GradientAxis.y:
          return bounds.top + bounds.height * ratio;
        case _GradientAxis.radius:
          return math.max(bounds.width, bounds.height) * ratio;
      }
    }

    if (parsed.isPercent) {
      switch (axis) {
        case _GradientAxis.x:
          return bounds.left + bounds.width * (value / 100.0);
        case _GradientAxis.y:
          return bounds.top + bounds.height * (value / 100.0);
        case _GradientAxis.radius:
          return math.max(bounds.width, bounds.height) * (value / 100.0);
      }
    }

    return value;
  }

  double _normalizeObjectBoundingBoxValue(double value, Object? rawValue) {
    if (rawValue is num && value.abs() > 1.0 && value.abs() <= 100.0) {
      // Парсер конвертирует "50%" в 50, восстанавливаем ожидаемую долю.
      return value / 100.0;
    }
    return value;
  }

  _GradientLength _parseGradientLength(
    Object? rawValue, {
    required double defaultValue,
  }) {
    if (rawValue == null) {
      return _GradientLength(defaultValue, true);
    }

    if (rawValue is num) {
      return _GradientLength(rawValue.toDouble(), false);
    }

    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return _GradientLength(defaultValue, true);
    }

    if (raw.endsWith('%')) {
      final number = double.tryParse(raw.substring(0, raw.length - 1));
      if (number != null) {
        return _GradientLength(number, true);
      }
      return _GradientLength(defaultValue, true);
    }

    final parsed = double.tryParse(raw.replaceAll(RegExp(r'[a-zA-Z]+$'), ''));
    return _GradientLength(parsed ?? defaultValue, false);
  }

  double _parseStopOffset(Object? value) {
    final parsed = _parseGradientLength(value, defaultValue: 0.0);
    final normalized = parsed.isPercent
        ? parsed.value / 100.0
        : _normalizeObjectBoundingBoxValue(parsed.value, value);
    return normalized.clamp(0.0, 1.0);
  }

  double? _parseOpacityValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final opacity = value.toDouble();
      return opacity > 1.0 && opacity <= 100.0 ? opacity / 100.0 : opacity;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.endsWith('%')) {
      final number = double.tryParse(raw.substring(0, raw.length - 1));
      return number == null ? null : number / 100.0;
    }

    return double.tryParse(raw);
  }

  Float64List? _parseGradientTransformMatrix(Object? value) {
    final matrix = _buildTransformMatrixFromValue(value);
    return matrix?.storage;
  }

  Matrix4? _buildTransformMatrixFromValue(Object? value) {
    final transform = value?.toString();
    if (transform == null || transform.trim().isEmpty) {
      return null;
    }

    final matrix = Matrix4.identity();
    final transforms = SvgTransform.parse(transform);
    if (transforms.isEmpty) {
      return null;
    }

    for (final item in transforms) {
      switch (item.type) {
        case SvgTransformType.translate:
          final tx = item.values.isNotEmpty ? item.values[0] : 0.0;
          final ty = item.values.length > 1 ? item.values[1] : 0.0;
          final translation = Matrix4.identity()
            ..setEntry(0, 3, tx)
            ..setEntry(1, 3, ty);
          matrix.multiply(translation);
          break;
        case SvgTransformType.scale:
          final sx = item.values.isNotEmpty ? item.values[0] : 1.0;
          final sy = item.values.length > 1 ? item.values[1] : sx;
          final scale = Matrix4.identity()
            ..setEntry(0, 0, sx)
            ..setEntry(1, 1, sy);
          matrix.multiply(scale);
          break;
        case SvgTransformType.rotate:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (item.values.length >= 3) {
            final cx = item.values[1];
            final cy = item.values[2];
            final toCenter = Matrix4.identity()
              ..setEntry(0, 3, cx)
              ..setEntry(1, 3, cy);
            final fromCenter = Matrix4.identity()
              ..setEntry(0, 3, -cx)
              ..setEntry(1, 3, -cy);
            matrix
              ..multiply(toCenter)
              ..rotateZ(radians)
              ..multiply(fromCenter);
          } else {
            matrix.rotateZ(radians);
          }
          break;
        case SvgTransformType.skewX:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(0, 1, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.skewY:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(1, 0, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.matrix:
          if (item.values.length >= 6) {
            final custom = Matrix4.identity()
              ..setEntry(0, 0, item.values[0])
              ..setEntry(1, 0, item.values[1])
              ..setEntry(0, 1, item.values[2])
              ..setEntry(1, 1, item.values[3])
              ..setEntry(0, 3, item.values[4])
              ..setEntry(1, 3, item.values[5]);
            matrix.multiply(custom);
          }
          break;
      }
    }

    return matrix;
  }

  /// Получает числовое значение атрибута (с учётом анимации)
  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  Object? _getInheritedAttributeValue(SvgNode node, String attributeName) {
    SvgNode? current = node;
    while (current != null) {
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        return value;
      }
      current = current.parent;
    }
    return null;
  }

  String? _getInheritedString(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    final str = value?.toString();
    if (str == null) {
      return null;
    }
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _getInheritedNumber(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }

  ui.FontWeight _resolveFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return ui.FontWeight.normal;
    }
    switch (fontWeight.toLowerCase()) {
      case '100':
      case 'thin':
        return ui.FontWeight.w100;
      case '200':
      case 'extralight':
      case 'extra-light':
        return ui.FontWeight.w200;
      case '300':
      case 'light':
        return ui.FontWeight.w300;
      case '500':
      case 'medium':
        return ui.FontWeight.w500;
      case '600':
      case 'semibold':
      case 'semi-bold':
        return ui.FontWeight.w600;
      case '700':
      case 'bold':
        return ui.FontWeight.w700;
      case '800':
      case 'extrabold':
      case 'extra-bold':
        return ui.FontWeight.w800;
      case '900':
      case 'black':
        return ui.FontWeight.w900;
      case '400':
      case 'normal':
      default:
        return ui.FontWeight.normal;
    }
  }

  ui.FontStyle _resolveFontStyle(String? fontStyle) {
    return fontStyle?.toLowerCase() == 'italic'
        ? ui.FontStyle.italic
        : ui.FontStyle.normal;
  }

  _SvgTextAnchor _resolveTextAnchor(String? anchorValue) {
    switch (anchorValue?.trim().toLowerCase()) {
      case 'middle':
        return _SvgTextAnchor.middle;
      case 'end':
        return _SvgTextAnchor.end;
      case 'start':
      default:
        return _SvgTextAnchor.start;
    }
  }

  ui.Rect? _parseViewBox(String? viewBoxValue) {
    if (viewBoxValue == null || viewBoxValue.trim().isEmpty) {
      return null;
    }

    final values = viewBoxValue
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    if (values.length != 4 || values[2] <= 0 || values[3] <= 0) {
      return null;
    }

    return ui.Rect.fromLTWH(values[0], values[1], values[2], values[3]);
  }

  /// Получает строковое значение атрибута
  String? _getString(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    return value?.toString();
  }

  List<ui.Offset> _parsePoints(SvgNode node) {
    final pointsValue = _getString(node, 'points');
    if (pointsValue == null || pointsValue.trim().isEmpty) {
      return const <ui.Offset>[];
    }

    final numbers = pointsValue
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (numbers.length < 2) {
      return const <ui.Offset>[];
    }

    final points = <ui.Offset>[];
    for (int i = 0; i + 1 < numbers.length; i += 2) {
      points.add(ui.Offset(numbers[i], numbers[i + 1]));
    }
    return points;
  }

  /// Парсит цвет из строки
  ui.Color? _parseColor(String colorStr) {
    final str = colorStr.trim().toLowerCase();

    // none
    if (str == 'none') return null;

    // Hex colors
    if (str.startsWith('#')) {
      final hex = str.substring(1);

      if (hex.length == 3) {
        // #RGB -> #RRGGBB
        final r = int.parse(hex[0] + hex[0], radix: 16);
        final g = int.parse(hex[1] + hex[1], radix: 16);
        final b = int.parse(hex[2] + hex[2], radix: 16);
        return ui.Color.fromARGB(255, r, g, b);
      } else if (hex.length == 6) {
        // #RRGGBB
        final value = int.parse(hex, radix: 16);
        return ui.Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        // #RRGGBBAA
        final value = int.parse(hex, radix: 16);
        return ui.Color(value);
      }
    }

    // Named colors (базовые)
    const namedColors = {
      'black': ui.Color(0xFF000000),
      'white': ui.Color(0xFFFFFFFF),
      'red': ui.Color(0xFFFF0000),
      'green': ui.Color(0xFF008000),
      'blue': ui.Color(0xFF0000FF),
      'yellow': ui.Color(0xFFFFFF00),
      'cyan': ui.Color(0xFF00FFFF),
      'magenta': ui.Color(0xFFFF00FF),
      'gray': ui.Color(0xFF808080),
      'grey': ui.Color(0xFF808080),
    };

    return namedColors[str];
  }

  /// Применяет transform к canvas если атрибут задан
  void _applyTransform(ui.Canvas canvas, SvgNode node) {
    final transformStr = _getString(node, 'transform');
    if (transformStr == null || transformStr.isEmpty) return;

    // Парсим трансформации
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) return;

    // Применяем каждую трансформацию в порядке объявления
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          canvas.translate(tx, ty);

        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
          final cy = transform.values.length > 2 ? transform.values[2] : 0.0;

          // Rotate with center point
          if (cx != 0.0 || cy != 0.0) {
            canvas.translate(cx, cy);
            canvas.rotate(angle * 3.14159 / 180.0); // degrees to radians
            canvas.translate(-cx, -cy);
          } else {
            canvas.rotate(angle * 3.14159 / 180.0);
          }

        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1
              ? transform.values[1]
              : sx; // sy defaults to sx
          canvas.scale(sx, sy);

        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewX matrix: [1, tan(angle), 0]
          //               [0,     1,      0]
          //               [0,     0,      1]
          final matrix = Matrix4.identity()
            ..setEntry(0, 1, tanValue); // Set skewX component
          canvas.transform(matrix.storage);

        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewY matrix: [    1,      0, 0]
          //               [tan(angle), 1, 0]
          //               [    0,      0, 1]
          final matrix = Matrix4.identity()
            ..setEntry(1, 0, tanValue); // Set skewY component
          canvas.transform(matrix.storage);

        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            // SVG matrix(a, b, c, d, e, f) maps to:
            // [a  c  e]
            // [b  d  f]
            // [0  0  1]
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];

            final matrix = Matrix4.identity()
              ..setEntry(0, 0, a) // m11
              ..setEntry(1, 0, b) // m21
              ..setEntry(0, 1, c) // m12
              ..setEntry(1, 1, d) // m22
              ..setEntry(0, 3, e) // m14 (translateX)
              ..setEntry(1, 3, f); // m24 (translateY)
            canvas.transform(matrix.storage);
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedSvgPainter oldDelegate) {
    // Всегда перерисовываем, так как анимации могут изменить значения
    return true;
  }

  @override
  bool shouldRebuildSemantics(AnimatedSvgPainter oldDelegate) {
    return false;
  }
}

enum _GradientAxis { x, y, radius }

class _GradientLength {
  const _GradientLength(this.value, this.isPercent);

  final double value;
  final bool isPercent;
}

class _ImageLayout {
  const _ImageLayout({
    required this.destinationRect,
    required this.clipToViewport,
  });

  final ui.Rect destinationRect;
  final bool clipToViewport;
}

class _GradientStop {
  const _GradientStop({required this.offset, required this.color});

  final double offset;
  final ui.Color color;
}

class _ResolvedGradientDefinition {
  const _ResolvedGradientDefinition({
    required this.type,
    required this.attributes,
    required this.stops,
  });

  final String type;
  final Map<String, Object?> attributes;
  final List<_GradientStop> stops;
}

class _TextCursor {
  _TextCursor({required this.x, required this.y});

  double x;
  double y;
}

enum _SvgTextAnchor { start, middle, end }

class _ResolvedTextStyle {
  const _ResolvedTextStyle({
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.textAnchor,
  });

  final ui.Color color;
  final double fontSize;
  final String? fontFamily;
  final ui.FontWeight fontWeight;
  final ui.FontStyle fontStyle;
  final _SvgTextAnchor textAnchor;
}
