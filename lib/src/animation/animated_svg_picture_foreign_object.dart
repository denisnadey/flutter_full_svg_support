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
    Widget svgWidget,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate position based on viewBox transform
        final viewBox = _document.activeViewBox;
        if (viewBox == null ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return svgWidget;
        }

        // Calculate scale to fit viewBox in widget size
        final scaleX = constraints.maxWidth / viewBox.width;
        final scaleY = constraints.maxHeight / viewBox.height;
        final scale = math.min(scaleX, scaleY);

        // Calculate centering offset
        final offsetX =
            (constraints.maxWidth - viewBox.width * scale) / 2 -
            viewBox.left * scale;
        final offsetY =
            (constraints.maxHeight - viewBox.height * scale) / 2 -
            viewBox.top * scale;

        final positionedWidgets = <Widget>[];
        for (final entry in overlayWidgets.entries) {
          final foInfo = entry.key;
          final foWidget = entry.value;

          // Transform foreignObject position to widget coordinates
          final left = foInfo.x * scale + offsetX;
          final top = foInfo.y * scale + offsetY;
          final width = foInfo.width * scale;
          final height = foInfo.height * scale;

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
      },
    );
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
          _parseNumberForForeignObject(node.getAttributeValue('x')) ?? 0.0;
      final y =
          _parseNumberForForeignObject(node.getAttributeValue('y')) ?? 0.0;
      final width =
          _parseNumberForForeignObject(node.getAttributeValue('width')) ?? 0.0;
      final height =
          _parseNumberForForeignObject(node.getAttributeValue('height')) ?? 0.0;

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

  double? _parseNumberForForeignObject(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    final cleaned = str.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }
}
