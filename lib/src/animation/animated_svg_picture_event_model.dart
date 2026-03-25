part of 'animated_svg_picture.dart';

/// Result of hit testing that includes event model information.
class _EventHitTestResult {
  const _EventHitTestResult({
    this.elementId,
    this.anchorInfo,
    this.useElementId,
    this.composedPath = const [],
  });

  /// The ID of the hit element (the actual inner element).
  final String? elementId;

  /// Link info from the nearest <a> ancestor.
  final SvgLinkInfo? anchorInfo;

  /// The ID of the <use> element if hit is inside a use shadow tree.
  final String? useElementId;

  /// The composed path including shadow tree elements.
  final List<String> composedPath;

  /// Whether the hit is inside a <use> shadow tree.
  bool get isInsideUseShadow => useElementId != null;

  /// Returns the retargeted element ID (use element if inside shadow).
  String? get retargetedElementId => useElementId ?? elementId;
}

extension _AnimatedSvgPictureStateEventModelExtension
    on _AnimatedSvgPictureState {
  /// Performs hit testing with full event model support including use retargeting.
  _EventHitTestResult _hitTestWithEventModel(Offset localPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return const _EventHitTestResult();
    }

    _prepareHitTestCache(_timeline?.currentTime.inMicroseconds.toDouble());

    final documentPoint = _localToDocumentPoint(
      localPosition,
      renderObject.size,
    );
    if (documentPoint == null) return const _EventHitTestResult();

    final pathBuilder = <String>[];
    return _hitTestNodeWithEventPath(
      _document.root,
      documentPoint,
      Matrix4.identity(),
      useStack: const <String>{},
      foreignObjectParent: null,
      currentAnchor: null,
      pathBuilder: pathBuilder,
      useContext: null,
    );
  }

  /// Hit tests with event path tracking for proper W3C event model.
  _EventHitTestResult _hitTestNodeWithEventPath(
    SvgNode node,
    Offset documentPoint,
    Matrix4 parentTransform, {
    required Set<String> useStack,
    required SvgNode? foreignObjectParent,
    required SvgLinkInfo? currentAnchor,
    required List<String> pathBuilder,
    required _UseEventContext? useContext,
  }) {
    if (_isDefinitionOnlyTag(node.tagName)) {
      return const _EventHitTestResult();
    }
    if (_isDisplayNone(node)) {
      return const _EventHitTestResult();
    }

    if (node.tagName == 'foreignObject') {
      final requiredExtensions = node.getAttributeValue('requiredExtensions');
      if (requiredExtensions != null &&
          requiredExtensions.toString().trim().isNotEmpty) {
        return const _EventHitTestResult();
      }
    }

    var activeAnchor = currentAnchor;
    if (node.tagName == 'a') {
      final anchorInfo = _extractAnchorInfo(node);
      if (anchorInfo != null) {
        activeAnchor = anchorInfo;
      }
    }

    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    if (!_isPointVisibleForNode(node, documentPoint, currentTransform)) {
      return const _EventHitTestResult();
    }
    final pointerEventsNone = _isPointerEventsNone(node);

    final childTransform = Matrix4.copy(currentTransform);
    _applyForeignObjectChildTransform(childTransform, node);

    if (node.tagName == 'svg' && foreignObjectParent != null) {
      _applyNestedSvgTransformInForeignObject(
        childTransform,
        node,
        foreignObjectParent,
      );
    }

    // Add to path if has ID
    if (node.id != null) {
      pathBuilder.add(node.id!);
    }

    if (node.tagName == 'switch') {
      final activeChild = resolveActiveSwitchChild(node);
      if (activeChild == null) {
        return const _EventHitTestResult();
      }
      return _hitTestNodeWithEventPath(
        activeChild,
        documentPoint,
        childTransform,
        useStack: useStack,
        foreignObjectParent: foreignObjectParent,
        currentAnchor: activeAnchor,
        pathBuilder: pathBuilder,
        useContext: useContext,
      );
    }

    final foParent = node.tagName == 'foreignObject'
        ? node
        : foreignObjectParent;

    // Traverse children in reverse (last painted is visually on top)
    for (int i = node.children.length - 1; i >= 0; i--) {
      final hitResult = _hitTestNodeWithEventPath(
        node.children[i],
        documentPoint,
        childTransform,
        useStack: useStack,
        foreignObjectParent: foParent,
        currentAnchor: activeAnchor,
        pathBuilder: List.of(pathBuilder),
        useContext: useContext,
      );
      if (hitResult.elementId != null || hitResult.anchorInfo != null) {
        return hitResult;
      }
    }

    if (node.tagName == 'use') {
      final hitReferenced = _hitTestUseReferenceWithEventPath(
        useNode: node,
        documentPoint: documentPoint,
        currentTransform: currentTransform,
        useStack: useStack,
        currentAnchor: activeAnchor,
        pathBuilder: List.of(pathBuilder),
      );
      if (hitReferenced.elementId != null || hitReferenced.anchorInfo != null) {
        return hitReferenced;
      }
    }

    if (pointerEventsNone ||
        node.id == null ||
        !_isHitTestableTag(node.tagName)) {
      return const _EventHitTestResult();
    }

    if (_nodeContainsPoint(node, documentPoint, currentTransform)) {
      return _EventHitTestResult(
        elementId: node.id,
        anchorInfo: activeAnchor,
        useElementId: useContext?.useElementId,
        composedPath: List.of(pathBuilder),
      );
    }
    return const _EventHitTestResult();
  }

  /// Hit tests use reference with event path tracking.
  _EventHitTestResult _hitTestUseReferenceWithEventPath({
    required SvgNode useNode,
    required Offset documentPoint,
    required Matrix4 currentTransform,
    required Set<String> useStack,
    required SvgLinkInfo? currentAnchor,
    required List<String> pathBuilder,
  }) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return const _EventHitTestResult();
    }

    if (useStack.length >= _kMaxUseRecursionDepthHitTest) {
      return const _EventHitTestResult();
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return const _EventHitTestResult();
    }

    final usePointerEvents = _resolvePointerEventsMode(useNode);
    if (usePointerEvents == 'none') {
      return const _EventHitTestResult();
    }

    // Create use context for event retargeting
    final useContext = _UseEventContext(useElementId: useNode.id);

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
          return const _EventHitTestResult();
        }
        if (referenced.tagName == 'symbol') {
          for (int i = referenced.children.length - 1; i >= 0; i--) {
            final hitResult = _hitTestNodeWithEventPath(
              referenced.children[i],
              documentPoint,
              useReferenceTransform,
              useStack: nextUseStack,
              foreignObjectParent: null,
              currentAnchor: currentAnchor,
              pathBuilder: List.of(pathBuilder),
              useContext: useContext,
            );
            if (hitResult.elementId != null || hitResult.anchorInfo != null) {
              return hitResult;
            }
          }
          return const _EventHitTestResult();
        }
        return _hitTestNodeWithEventPath(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
          foreignObjectParent: null,
          currentAnchor: currentAnchor,
          pathBuilder: List.of(pathBuilder),
          useContext: useContext,
        );
      }

      return _hitTestNodeWithEventPath(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
        foreignObjectParent: null,
        currentAnchor: currentAnchor,
        pathBuilder: List.of(pathBuilder),
        useContext: useContext,
      );
    } finally {
      referenced.parent = previousParent;
    }
  }
}

/// Context for tracking use element during event hit testing.
class _UseEventContext {
  const _UseEventContext({this.useElementId});

  /// The ID of the <use> element that is the shadow host.
  final String? useElementId;
}
