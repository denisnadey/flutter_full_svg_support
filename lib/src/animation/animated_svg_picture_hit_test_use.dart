part of 'animated_svg_picture.dart';

/// Maximum recursion depth for nested <use> elements (matching Blink).
/// This prevents infinite loops and excessive resource usage.
const int _kMaxUseRecursionDepthHitTest = 10;

/// Context for tracking pointer-events inheritance across <use> boundaries.
class _UseHitTestContext {
  const _UseHitTestContext({this.inheritedPointerEvents});

  /// Pointer-events value inherited from <use> element.
  /// If null, use the referenced element's own pointer-events.
  final String? inheritedPointerEvents;

  /// Creates a new context inheriting from this one.
  _UseHitTestContext copyWith({String? inheritedPointerEvents}) {
    return _UseHitTestContext(
      inheritedPointerEvents:
          inheritedPointerEvents ?? this.inheritedPointerEvents,
    );
  }
}

extension _AnimatedSvgPictureStateHitTestUseExtension
    on _AnimatedSvgPictureState {
  String? _hitTestUseReference({
    required SvgNode useNode,
    required Offset documentPoint,
    required Matrix4 currentTransform,
    required Set<String> useStack,
    _UseHitTestContext? context,
  }) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return null;
    }

    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    if (useStack.length >= _kMaxUseRecursionDepthHitTest) {
      return null;
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return null;
    }

    // Check pointer-events on the <use> element itself
    // Per SVG spec, pointer-events on <use> affects the entire shadow tree
    final usePointerEvents = _resolvePointerEventsMode(useNode);
    if (usePointerEvents == 'none') {
      return null;
    }

    // Create context for pointer-events inheritance
    final useContext =
        context?.copyWith(inheritedPointerEvents: usePointerEvents) ??
        _UseHitTestContext(inheritedPointerEvents: usePointerEvents);

    final referenceTransform = Matrix4.copy(currentTransform)
      ..translateByDouble(
        _getNumber(useNode, 'x') ?? 0.0,
        _getNumber(useNode, 'y') ?? 0.0,
        0,
        1,
      );

    final previousParent = referenced.parent;
    referenced.parent = useNode;
    try {
      final nextUseStack = <String>{...useStack, hrefId};
      if (_isUseViewportReferenceTag(referenced.tagName)) {
        final useReferenceTransform = Matrix4.copy(referenceTransform);
        final clippedViewport = _applyUseViewportTransform(
          useReferenceTransform,
          useNode,
          referenced,
        );
        if (clippedViewport != null &&
            !_isPointInsideTransformedRect(
              documentPoint: documentPoint,
              transform: referenceTransform,
              localRect: clippedViewport,
            )) {
          return null;
        }
        if (referenced.tagName == 'symbol') {
          for (int i = referenced.children.length - 1; i >= 0; i--) {
            final hitChild = _hitTestNodeWithUseContext(
              referenced.children[i],
              documentPoint,
              useReferenceTransform,
              useStack: nextUseStack,
              foreignObjectParent: null,
              useContext: useContext,
            );
            if (hitChild != null) {
              return hitChild;
            }
          }
          return null;
        }
        return _hitTestNodeWithUseContext(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
          foreignObjectParent: null,
          useContext: useContext,
        );
      }

      return _hitTestNodeWithUseContext(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
        foreignObjectParent: null,
        useContext: useContext,
      );
    } finally {
      referenced.parent = previousParent;
    }
  }

  /// Hit tests a node with <use> context for pointer-events inheritance.
  String? _hitTestNodeWithUseContext(
    SvgNode node,
    Offset documentPoint,
    Matrix4 parentTransform, {
    required Set<String> useStack,
    required SvgNode? foreignObjectParent,
    required _UseHitTestContext useContext,
  }) {
    if (_isDefinitionOnlyTag(node.tagName)) {
      return null;
    }
    if (_isDisplayNone(node)) {
      return null;
    }

    // Check requiredExtensions for foreignObject
    if (node.tagName == 'foreignObject') {
      final requiredExtensions = node.getAttributeValue('requiredExtensions');
      if (requiredExtensions != null &&
          requiredExtensions.toString().trim().isNotEmpty) {
        return null;
      }
    }

    final currentUseStack = useStack;
    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    if (!_isPointVisibleForNode(node, documentPoint, currentTransform)) {
      return null;
    }

    // Check pointer-events with inheritance from <use>
    final nodePointerEvents = _resolvePointerEventsMode(node);
    final effectivePointerEvents =
        nodePointerEvents == 'auto' || nodePointerEvents == 'visiblepainted'
        ? useContext.inheritedPointerEvents ?? nodePointerEvents
        : nodePointerEvents;
    if (effectivePointerEvents == 'none') {
      return null;
    }

    final childTransform = Matrix4.copy(currentTransform);
    _applyForeignObjectChildTransform(childTransform, node);

    // Apply nested SVG transform within foreignObject
    if (node.tagName == 'svg' && foreignObjectParent != null) {
      _applyNestedSvgTransformInForeignObject(
        childTransform,
        node,
        foreignObjectParent,
      );
    }

    if (node.tagName == 'switch') {
      final activeChild = resolveActiveSwitchChild(node);
      if (activeChild == null) {
        return null;
      }
      return _hitTestNodeWithUseContext(
        activeChild,
        documentPoint,
        childTransform,
        useStack: currentUseStack,
        foreignObjectParent: foreignObjectParent,
        useContext: useContext,
      );
    }

    // Determine if this node establishes a foreignObject context for children
    final foParent = node.tagName == 'foreignObject'
        ? node
        : foreignObjectParent;

    // Traverse children in reverse (last painted is visually on top)
    for (int i = node.children.length - 1; i >= 0; i--) {
      final hitChild = _hitTestNodeWithUseContext(
        node.children[i],
        documentPoint,
        childTransform,
        useStack: currentUseStack,
        foreignObjectParent: foParent,
        useContext: useContext,
      );
      if (hitChild != null) {
        return hitChild;
      }
    }

    if (node.tagName == 'use') {
      final hitReferenced = _hitTestUseReference(
        useNode: node,
        documentPoint: documentPoint,
        currentTransform: currentTransform,
        useStack: currentUseStack,
        context: useContext,
      );
      if (hitReferenced != null) {
        return hitReferenced;
      }
    }

    if (effectivePointerEvents == 'none' ||
        node.id == null ||
        !_isHitTestableTag(node.tagName)) {
      return null;
    }

    return _nodeContainsPoint(node, documentPoint, currentTransform)
        ? node.id
        : null;
  }

  bool _isUseViewportReferenceTag(String tagName) {
    return tagName == 'symbol' || tagName == 'svg';
  }

  bool _isUseReferenceAllowedTag(String tagName) {
    switch (tagName) {
      case 'a':
      case 'circle':
      case 'desc':
      case 'ellipse':
      case 'g':
      case 'image':
      case 'line':
      case 'metadata':
      case 'path':
      case 'polygon':
      case 'polyline':
      case 'rect':
      case 'svg':
      case 'switch':
      case 'symbol':
      case 'text':
      case 'textPath':
      case 'title':
      case 'tref':
      case 'tspan':
      case 'use':
        return true;
      default:
        return false;
    }
  }

  Rect? _applyUseViewportTransform(
    Matrix4 matrix,
    SvgNode useNode,
    SvgNode referencedNode,
  ) {
    final viewBox = _parseViewBox(referencedNode.getAttributeValue('viewBox'));
    final width = _getNumber(useNode, 'width');
    final height = _getNumber(useNode, 'height');
    if (viewBox == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        viewBox.width <= 0 ||
        viewBox.height <= 0) {
      return null;
    }

    final viewport = Rect.fromLTWH(0, 0, width, height);
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: viewBox.size,
      preserveAspectRatio: referencedNode
          .getAttributeValue('preserveAspectRatio')
          ?.toString(),
    );
    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;
    matrix
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    return layout.clipToViewport ? viewport : null;
  }

  bool _isPointInsideTransformedRect({
    required Offset documentPoint,
    required Matrix4 transform,
    required Rect localRect,
  }) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final localPoint = MatrixUtils.transformPoint(inverse, documentPoint);
    return localRect.contains(localPoint);
  }

  Rect? _parseViewBox(Object? rawValue) {
    final viewBox = rawValue?.toString();
    if (viewBox == null || viewBox.trim().isEmpty) {
      return null;
    }
    final parts = viewBox
        .trim()
        .split(RegExp(r'[,\s]+'))
        .where((part) => part.isNotEmpty)
        .map(double.tryParse)
        .toList();
    if (parts.length < 4 || parts.take(4).any((value) => value == null)) {
      return null;
    }
    return Rect.fromLTWH(parts[0]!, parts[1]!, parts[2]!, parts[3]!);
  }
}
