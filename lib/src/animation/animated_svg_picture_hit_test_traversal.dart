part of 'animated_svg_picture.dart';

/// Result of hit testing that includes both the element ID and anchor info.
class _HitTestResult {
  const _HitTestResult({
    this.elementId,
    this.anchorInfo,
  });

  /// The ID of the hit element, if any.
  final String? elementId;

  /// Link info from the nearest <a> ancestor, if the hit element is inside an anchor.
  final SvgLinkInfo? anchorInfo;
}

extension _AnimatedSvgPictureStateHitTestTraversalExtension
    on _AnimatedSvgPictureState {

  /// Extracts link info from an anchor node.
  SvgLinkInfo? _extractAnchorInfo(SvgNode node) {
    if (node.tagName != 'a') return null;

    final href =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (href == null) return null;

    final hrefString = href.toString().trim();
    if (hrefString.isEmpty) return null;

    final target = node.getAttributeValue('target')?.toString();

    return SvgLinkInfo(href: hrefString, target: target);
  }

  Offset? _localToDocumentPoint(Offset localPosition, Size size) {
    final transform = _computeViewBoxTransform(size);
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return null;
    }
    return MatrixUtils.transformPoint(inverse, localPosition);
  }

  Matrix4 _computeViewBoxTransform(Size size) {
    final viewBox = _document.viewBox;
    if (viewBox == null) {
      return Matrix4.identity();
    }

    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final translateX =
        (size.width - viewBox.width * scale) / 2 - viewBox.left * scale;
    final translateY =
        (size.height - viewBox.height * scale) / 2 - viewBox.top * scale;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Hit tests with anchor tracking - returns both element ID and anchor info.
  _HitTestResult _hitTestNodeWithAnchor(
    SvgNode node,
    Offset documentPoint,
    Matrix4 parentTransform, {
    required Set<String> useStack,
    required SvgNode? foreignObjectParent,
    required SvgLinkInfo? currentAnchor,
  }) {
    if (_isDefinitionOnlyTag(node.tagName)) {
      return const _HitTestResult();
    }
    if (_isDisplayNone(node)) {
      return const _HitTestResult();
    }

    // Check requiredExtensions for foreignObject
    if (node.tagName == 'foreignObject') {
      final requiredExtensions = node.getAttributeValue('requiredExtensions');
      if (requiredExtensions != null &&
          requiredExtensions.toString().trim().isNotEmpty) {
        return const _HitTestResult();
      }
    }

    // Update anchor context if this is an <a> element (inner anchor takes precedence)
    var activeAnchor = currentAnchor;
    if (node.tagName == 'a') {
      final anchorInfo = _extractAnchorInfo(node);
      if (anchorInfo != null) {
        activeAnchor = anchorInfo;
      }
    }

    final currentUseStack = useStack;
    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    if (!_isPointVisibleForNode(node, documentPoint, currentTransform)) {
      return const _HitTestResult();
    }
    final pointerEventsNone = _isPointerEventsNone(node);

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
        return const _HitTestResult();
      }
      return _hitTestNodeWithAnchor(
        activeChild,
        documentPoint,
        childTransform,
        useStack: currentUseStack,
        foreignObjectParent: foreignObjectParent,
        currentAnchor: activeAnchor,
      );
    }

    // Determine if this node establishes a foreignObject context for children
    final foParent = node.tagName == 'foreignObject'
        ? node
        : foreignObjectParent;

    // Traverse children in reverse (last painted is visually on top)
    for (int i = node.children.length - 1; i >= 0; i--) {
      final hitResult = _hitTestNodeWithAnchor(
        node.children[i],
        documentPoint,
        childTransform,
        useStack: currentUseStack,
        foreignObjectParent: foParent,
        currentAnchor: activeAnchor,
      );
      if (hitResult.elementId != null || hitResult.anchorInfo != null) {
        return hitResult;
      }
    }

    if (node.tagName == 'use') {
      final hitReferenced = _hitTestUseReferenceWithAnchor(
        useNode: node,
        documentPoint: documentPoint,
        currentTransform: currentTransform,
        useStack: currentUseStack,
        currentAnchor: activeAnchor,
      );
      if (hitReferenced.elementId != null || hitReferenced.anchorInfo != null) {
        return hitReferenced;
      }
    }

    if (pointerEventsNone ||
        node.id == null ||
        !_isHitTestableTag(node.tagName)) {
      return const _HitTestResult();
    }

    if (_nodeContainsPoint(node, documentPoint, currentTransform)) {
      return _HitTestResult(elementId: node.id, anchorInfo: activeAnchor);
    }
    return const _HitTestResult();
  }

  /// Hit tests use reference with anchor tracking.
  _HitTestResult _hitTestUseReferenceWithAnchor({
    required SvgNode useNode,
    required Offset documentPoint,
    required Matrix4 currentTransform,
    required Set<String> useStack,
    required SvgLinkInfo? currentAnchor,
  }) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return const _HitTestResult();
    }

    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    if (useStack.length >= _kMaxUseRecursionDepthHitTest) {
      return const _HitTestResult();
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return const _HitTestResult();
    }

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
        // Check viewport clipping for slice mode
        if (clippedViewport != null &&
            !_isPointInsideTransformedRect(
              documentPoint: documentPoint,
              transform: referenceTransform,
              localRect: clippedViewport,
            )) {
          return const _HitTestResult();
        }
        // Handle symbol specially - iterate children directly since symbol
        // is a definition-only tag that would be rejected by _hitTestNodeWithAnchor
        if (referenced.tagName == 'symbol') {
          for (int i = referenced.children.length - 1; i >= 0; i--) {
            final hitResult = _hitTestNodeWithAnchor(
              referenced.children[i],
              documentPoint,
              useReferenceTransform,
              useStack: nextUseStack,
              foreignObjectParent: null,
              currentAnchor: currentAnchor,
            );
            if (hitResult.elementId != null || hitResult.anchorInfo != null) {
              return hitResult;
            }
          }
          return const _HitTestResult();
        }
        return _hitTestNodeWithAnchor(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
          foreignObjectParent: null,
          currentAnchor: currentAnchor,
        );
      }

      return _hitTestNodeWithAnchor(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
        foreignObjectParent: null,
        currentAnchor: currentAnchor,
      );
    } finally {
      referenced.parent = previousParent;
    }
  }

  bool _isHitTestableTag(String tagName) {
    return tagName == 'rect' ||
        tagName == 'circle' ||
        tagName == 'ellipse' ||
        tagName == 'path' ||
        tagName == 'polygon' ||
        tagName == 'polyline' ||
        tagName == 'line' ||
        tagName == 'image' ||
        tagName == 'foreignObject' ||
        tagName == 'text' ||
        tagName == 'tspan' ||
        tagName == 'textPath';
  }

  bool _isDefinitionOnlyTag(String tagName) {
    return tagName == 'defs' ||
        tagName == 'symbol' ||
        tagName == 'linearGradient' ||
        tagName == 'radialGradient' ||
        tagName == 'stop' ||
        tagName == 'clipPath' ||
        tagName == 'mask' ||
        tagName == 'pattern' ||
        tagName == 'filter' ||
        tagName == 'marker';
  }

}
