part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterClipMaskUnitsExtension on AnimatedSvgPainter {
  ui.Path? _buildMaskUnitsRegionPath({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();
    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (targetBounds == null) {
        return null;
      }
      // Edge case: zero width or height - nothing to mask
      if (targetBounds.width.abs() < _kMinBoundingBoxDimension ||
          targetBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }
      final x = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('x'));
      final y = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('y'));
      final width = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('width'),
      );
      final height = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('height'),
      );
      final resolvedX = x ?? -0.1;
      final resolvedY = y ?? -0.1;
      final resolvedWidth = width ?? 1.2;
      final resolvedHeight = height ?? 1.2;
      if (resolvedWidth <= 0 || resolvedHeight <= 0) {
        return null;
      }
      // Handle very small target bounds by using safe dimensions
      final safeWidth = targetBounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.width;
      final safeHeight = targetBounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.height;
      final rect = ui.Rect.fromLTWH(
        targetBounds.left + resolvedX * safeWidth,
        targetBounds.top + resolvedY * safeHeight,
        safeWidth * resolvedWidth,
        safeHeight * resolvedHeight,
      );
      return ui.Path()..addRect(rect);
    }

    final x = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'x',
      horizontal: true,
      isSize: false,
      defaultRaw: '-10%',
    );
    final y = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'y',
      horizontal: false,
      isSize: false,
      defaultRaw: '-10%',
    );
    final width = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'width',
      horizontal: true,
      isSize: true,
      defaultRaw: '120%',
    );
    final height = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'height',
      horizontal: false,
      isSize: true,
      defaultRaw: '120%',
    );
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    return ui.Path()..addRect(ui.Rect.fromLTWH(x, y, width, height));
  }

  double? _resolveMaskUserSpaceLength({
    required SvgNode maskNode,
    required String attributeName,
    required bool horizontal,
    required bool isSize,
    required String defaultRaw,
  }) {
    final rawValue = maskNode.getAttributeValue(attributeName) ?? defaultRaw;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      final viewport = _resolveMaskUnitsViewportRect();
      if (percent == null || viewport == null) {
        return null;
      }
      final dimension = horizontal ? viewport.width : viewport.height;
      final value = dimension * percent / 100.0;
      if (isSize) {
        return value;
      }
      final origin = horizontal ? viewport.left : viewport.top;
      return origin + value;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  ui.Rect? _resolveMaskUnitsViewportRect() {
    final viewBox = document.viewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final root = document.root;
    final width = _getNumber(root, 'width');
    final height = _getNumber(root, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return ui.Rect.fromLTWH(0, 0, width, height);
  }

  double? _parseObjectBoundingBoxValue(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return null;
      }
      return percent / 100.0;
    }
    return double.tryParse(raw);
  }
}
