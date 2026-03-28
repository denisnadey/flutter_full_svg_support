part of 'animated_svg_picture.dart';

/// Result of hit testing that includes event model information.
class _EventHitTestResult {
  const _EventHitTestResult({
    this.elementId,
    this.anchorInfo,
    this.useElementId,
    this.composedPath = const [],
    this.shadowPath = const [],
  });

  /// The ID of the hit element (the actual inner element).
  final String? elementId;

  /// Link info from the nearest <a> ancestor.
  final SvgLinkInfo? anchorInfo;

  /// The ID of the <use> element if hit is inside a use shadow tree.
  final String? useElementId;

  /// The composed path including shadow tree elements.
  /// This is the full path from root through use to the actual element.
  final List<String> composedPath;

  /// The shadow path - elements inside the <use> shadow tree only.
  /// Used for W3C composedPath() behavior.
  final List<String> shadowPath;

  /// Whether the hit is inside a <use> shadow tree.
  bool get isInsideUseShadow => useElementId != null;

  /// Returns the retargeted element ID (use element if inside shadow).
  /// Per W3C spec, events fired inside a shadow tree have their target
  /// retargeted to the shadow host (the <use> element).
  String? get retargetedElementId => useElementId ?? elementId;

  /// Returns the event path for non-composed events (retargeted).
  /// Starts from the <use> element when inside a shadow tree.
  List<String> get retargetedPath {
    if (useElementId == null) return composedPath;
    // Find the use element in the composed path and return from there
    final useIndex = composedPath.indexOf(useElementId!);
    if (useIndex >= 0) {
      return composedPath.sublist(0, useIndex + 1);
    }
    return composedPath;
  }
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
  ///
  /// Visibility handling per CSS/SVG spec:
  /// - display:none - NOT hit-testable
  /// - visibility:hidden - NOT hit-testable (checked via pointer-events)
  /// - opacity:0 - IS still hit-testable (opacity doesn't affect pointer events)
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
    // display:none elements are never hit-testable
    if (_isDisplayNone(node)) {
      return const _EventHitTestResult();
    }
    // Note: opacity:0 elements ARE still hit-testable per CSS spec

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
      // Also add to shadow path if we're inside a use shadow
      if (useContext != null) {
        useContext.addToShadowPath(node.id!);
      }
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
      // Return if we hit any element, an anchor, or are inside a use shadow
      if (hitResult.elementId != null ||
          hitResult.anchorInfo != null ||
          hitResult.useElementId != null) {
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
      // Return if we hit any element, an anchor, or are inside a use shadow
      if (hitReferenced.elementId != null ||
          hitReferenced.anchorInfo != null ||
          hitReferenced.useElementId != null) {
        return hitReferenced;
      }
    }

    if (pointerEventsNone || !_isHitTestableTag(node.tagName)) {
      return const _EventHitTestResult();
    }

    if (_nodeContainsPoint(node, documentPoint, currentTransform)) {
      // Even if the element has no ID, if we're inside a use shadow,
      // we should still return a hit result with the use element ID.
      // This allows event retargeting to work properly for elements without IDs.
      if (node.id == null && useContext?.useElementId == null) {
        return const _EventHitTestResult();
      }
      return _EventHitTestResult(
        elementId: node.id,
        anchorInfo: activeAnchor,
        useElementId: useContext?.useElementId,
        composedPath: List.of(pathBuilder),
        shadowPath: useContext?.shadowPathBuilder ?? const [],
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
    final useContext = _UseEventContext(
      useElementId: useNode.id,
      shadowPathBuilder: <String>[],
    );

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
            if (hitResult.elementId != null ||
                hitResult.anchorInfo != null ||
                hitResult.useElementId != null) {
              return _EventHitTestResult(
                elementId: hitResult.elementId,
                anchorInfo: hitResult.anchorInfo,
                useElementId: useNode.id,
                composedPath: hitResult.composedPath,
                shadowPath: useContext.shadowPathBuilder,
              );
            }
          }
          return const _EventHitTestResult();
        }
        final hitResult = _hitTestNodeWithEventPath(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
          foreignObjectParent: null,
          currentAnchor: currentAnchor,
          pathBuilder: List.of(pathBuilder),
          useContext: useContext,
        );
        if (hitResult.elementId != null ||
            hitResult.anchorInfo != null ||
            hitResult.useElementId != null) {
          return _EventHitTestResult(
            elementId: hitResult.elementId,
            anchorInfo: hitResult.anchorInfo,
            useElementId: useNode.id,
            composedPath: hitResult.composedPath,
            shadowPath: useContext.shadowPathBuilder,
          );
        }
        return hitResult;
      }

      final hitResult = _hitTestNodeWithEventPath(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
        foreignObjectParent: null,
        currentAnchor: currentAnchor,
        pathBuilder: List.of(pathBuilder),
        useContext: useContext,
      );
      if (hitResult.elementId != null ||
          hitResult.anchorInfo != null ||
          hitResult.useElementId != null) {
        return _EventHitTestResult(
          elementId: hitResult.elementId,
          anchorInfo: hitResult.anchorInfo,
          useElementId: useNode.id,
          composedPath: hitResult.composedPath,
          shadowPath: useContext.shadowPathBuilder,
        );
      }
      return hitResult;
    } finally {
      referenced.parent = previousParent;
    }
  }
}

/// Context for tracking use element during event hit testing.
class _UseEventContext {
  _UseEventContext({this.useElementId, List<String>? shadowPathBuilder})
    : shadowPathBuilder = shadowPathBuilder ?? [];

  /// The ID of the <use> element that is the shadow host.
  final String? useElementId;

  /// Builder for tracking the shadow path (elements inside the use shadow).
  final List<String> shadowPathBuilder;

  /// Adds an element ID to the shadow path.
  void addToShadowPath(String id) {
    shadowPathBuilder.add(id);
  }
}
