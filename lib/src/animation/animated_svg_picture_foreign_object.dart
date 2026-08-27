part of 'animated_svg_picture.dart';

/// Information about a foreignObject element for custom rendering.
@immutable
class SvgForeignObjectInfo {
  /// Creates foreignObject info.
  const SvgForeignObjectInfo({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.children = const <SvgNode>[],
  });

  /// The element ID (from id attribute). May be null.
  final String? id;

  /// X position in SVG coordinate space.
  final double x;

  /// Y position in SVG coordinate space.
  final double y;

  /// Width in SVG coordinate space.
  final double width;

  /// Height in SVG coordinate space.
  final double height;

  /// Child nodes within the foreignObject (for inspection).
  final List<SvgNode> children;
}

/// Callback for custom foreignObject rendering.
/// Return a Widget to render custom content, or null to use default behavior (skip).
/// The widget will be positioned within the foreignObject bounds.
typedef SvgForeignObjectBuilder =
    Widget? Function(BuildContext context, SvgForeignObjectInfo info);

extension _AnimatedSvgPictureStateForeignObjectExtension
    on _AnimatedSvgPictureState {
  /// Builds the SVG widget with foreignObject overlay widgets.
  Widget _buildWithForeignObjectOverlay(
    BuildContext context,
    Widget svgWidget, {
    required bool useFittedBox,
    required ui.Size? intrinsicSize,
  }) {
    // When the painted SVG is scaled by a FittedBox, the overlay must live in
    // the same pre-transform coordinate space (the intrinsic canvas size) so
    // both layers receive the identical fit/alignment transform.
    if (useFittedBox) {
      final viewport = intrinsicSize;
      if (viewport == null || viewport.width <= 0 || viewport.height <= 0) {
        return svgWidget;
      }
      return SvgLengthResolutionContext.runWithRootViewport(
        viewport,
        () => _buildOverlayStack(context, svgWidget, viewport),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = ui.Size(constraints.maxWidth, constraints.maxHeight);
        if (!viewport.width.isFinite ||
            !viewport.height.isFinite ||
            viewport.width <= 0 ||
            viewport.height <= 0) {
          return svgWidget;
        }

        // Resolve foreignObject geometry and invoke the builder inside the
        // negotiated root viewport so percentage lengths use the embedding
        // size, matching the painter and hit-test paths.
        return SvgLengthResolutionContext.runWithRootViewport(
          viewport,
          () => _buildOverlayStack(context, svgWidget, viewport),
        );
      },
    );
  }

  Widget _buildOverlayStack(
    BuildContext context,
    Widget svgWidget,
    ui.Size viewport,
  ) {
    final foreignObjects = <SvgForeignObjectInfo>[];
    _collectForeignObjects(_document.root, foreignObjects);
    if (foreignObjects.isEmpty) {
      return svgWidget;
    }

    final overlayWidgets = <SvgForeignObjectInfo, Widget>{};
    for (final foInfo in foreignObjects) {
      final foWidget = widget.foreignObjectBuilder!(context, foInfo);
      if (foWidget != null) {
        overlayWidgets[foInfo] = foWidget;
      }
    }
    if (overlayWidgets.isEmpty) {
      return svgWidget;
    }

    final viewBox = _effectiveRootViewBox();
    final layout = viewBox == null
        ? null
        : resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, viewport.width, viewport.height),
            sourceSize: viewBox.size,
            preserveAspectRatio: _document.activePreserveAspectRatio,
          );

    final positionedWidgets = <Widget>[];
    for (final entry in overlayWidgets.entries) {
      final foInfo = entry.key;
      final foWidget = entry.value;

      final double left;
      final double top;
      final double width;
      final double height;
      if (layout == null) {
        // No effective viewBox: document coordinates map 1:1 to the viewport,
        // mirroring the painter's identity transform.
        left = foInfo.x;
        top = foInfo.y;
        width = foInfo.width;
        height = foInfo.height;
      } else {
        final scaleX = layout.destinationRect.width / viewBox!.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        left = layout.destinationRect.left + (foInfo.x - viewBox.left) * scaleX;
        top = layout.destinationRect.top + (foInfo.y - viewBox.top) * scaleY;
        width = foInfo.width * scaleX;
        height = foInfo.height * scaleY;
      }

      positionedWidgets.add(
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: foWidget,
        ),
      );
    }

    return Stack(children: [svgWidget, ...positionedWidgets]);
  }

  /// The root viewBox used to map document coordinates into widget pixels.
  ///
  /// Mirrors the painter's `_computeViewBoxTransform`: an explicit viewBox
  /// wins, then a synthesized one from the document's declared width/height,
  /// and finally null for a dimensionless root (identity mapping).
  ui.Rect? _effectiveRootViewBox() {
    final viewBox = _document.activeViewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final docWidth = _document.width;
    final docHeight = _document.height;
    if (docWidth != null &&
        docHeight != null &&
        docWidth > 0 &&
        docHeight > 0) {
      return ui.Rect.fromLTWH(0, 0, docWidth, docHeight);
    }
    return null;
  }

  /// Collects all foreignObject elements from the SVG tree.
  void _collectForeignObjects(SvgNode node, List<SvgForeignObjectInfo> result) {
    if (node.tagName == 'foreignObject') {
      // Check if foreignObject should render (no unsupported requiredExtensions)
      final requiredExtensions = node.getAttributeValue('requiredExtensions');
      if (requiredExtensions != null &&
          requiredExtensions.toString().trim().isNotEmpty) {
        // Has unsupported extensions - skip
        return;
      }

      final x =
          resolveSvgLength(
            node,
            _document,
            'x',
            reference: SvgLengthReference.horizontal,
          ) ??
          0.0;
      final y =
          resolveSvgLength(
            node,
            _document,
            'y',
            reference: SvgLengthReference.vertical,
          ) ??
          0.0;
      final width =
          resolveSvgLength(
            node,
            _document,
            'width',
            reference: SvgLengthReference.horizontal,
          ) ??
          0.0;
      final height =
          resolveSvgLength(
            node,
            _document,
            'height',
            reference: SvgLengthReference.vertical,
          ) ??
          0.0;

      if (width > 0 && height > 0) {
        result.add(
          SvgForeignObjectInfo(
            id: node.id,
            x: x,
            y: y,
            width: width,
            height: height,
            children: node.children,
          ),
        );
      }
    }

    // Don't recurse into defs
    if (node.tagName == 'defs') {
      return;
    }

    for (final child in node.children) {
      _collectForeignObjects(child, result);
    }
  }
}
