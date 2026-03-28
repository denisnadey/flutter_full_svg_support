part of 'animated_svg_picture.dart';

/// Maximum recursion depth for nested <use> elements (matching Blink).
/// This prevents infinite loops and excessive resource usage.
const int _kMaxUseRecursionDepthHitTest = 10;

/// Context for tracking pointer-events inheritance across <use> boundaries.
/// Also handles event retargeting per SVG spec - events from shadow content
/// should target the <use> element, not the referenced content.
///
/// Per SVG 2 specification:
/// - Events on content inside a <use> shadow tree should bubble up to the
///   <use> element itself
/// - Hit-test results should report the <use> element's ID (not the referenced
///   element's ID) when the SVG uses event retargeting
/// - The outermost <use> element with an ID is the event target
class _UseHitTestContext {
  const _UseHitTestContext({
    this.inheritedPointerEvents,
    this.useElementId,
    this.parentContext,
    this.useNode,
  });

  /// Pointer-events value inherited from <use> element.
  /// If null, use the referenced element's own pointer-events.
  final String? inheritedPointerEvents;

  /// The ID of the <use> element for event retargeting.
  /// Per SVG spec, events from shadow content should target the <use> element.
  final String? useElementId;

  /// The <use> element node for full context access.
  final SvgNode? useNode;

  /// Parent hit-test context for nested <use> chains.
  final _UseHitTestContext? parentContext;

  /// Creates a new context inheriting from this one.
  _UseHitTestContext copyWith({
    String? inheritedPointerEvents,
    String? useElementId,
    SvgNode? useNode,
  }) {
    return _UseHitTestContext(
      inheritedPointerEvents:
          inheritedPointerEvents ?? this.inheritedPointerEvents,
      useElementId: useElementId ?? this.useElementId,
      useNode: useNode ?? this.useNode,
      parentContext: this,
    );
  }

  /// Gets the event target ID per SVG retargeting spec.
  /// When inside a <use> shadow tree, events should target the outermost
  /// <use> element that has an ID, not the inner referenced content.
  ///
  /// This implements the SVG event retargeting behavior where events from
  /// shadow content bubble up to and are retargeted to the <use> element.
  String? getRetargetedId(String? innerElementId) {
    // First, try to get the outermost use element ID (event bubbling)
    final outermost = outermostUseElementId;
    if (outermost != null && outermost.isNotEmpty) {
      return outermost;
    }
    // If no use element has an ID, fall back to inner element
    return innerElementId;
  }

  /// Gets the outermost use element ID in the chain.
  /// For event bubbling, we need to know the outermost use element.
  String? get outermostUseElementId {
    // Walk up the parent chain to find the outermost use element with an ID
    if (parentContext != null) {
      final parentId = parentContext!.outermostUseElementId;
      if (parentId != null && parentId.isNotEmpty) {
        return parentId;
      }
    }
    return useElementId;
  }

  /// Gets all use element IDs in the chain from outermost to current.
  /// This is useful for understanding the full event bubbling path.
  List<String?> get useChainIds {
    final ids = <String?>[];
    if (parentContext != null) {
      ids.addAll(parentContext!.useChainIds);
    }
    ids.add(useElementId);
    return ids;
  }

  /// Gets the nesting depth of use contexts.
  int get depth {
    int d = 1;
    _UseHitTestContext? current = parentContext;
    while (current != null) {
      d++;
      current = current.parentContext;
    }
    return d;
  }

  /// Checks if this context or any parent context already references
  /// the given ID, which would indicate a circular reference.
  bool hasCircularReference(String targetId) {
    // Check if we've already seen this target in the use chain
    _UseHitTestContext? current = this;
    while (current != null) {
      // Get the href ID from the use node if available
      final hrefId = current.useNode != null
          ? _extractHrefIdFromNode(current.useNode!)
          : null;
      if (hrefId == targetId) {
        return true;
      }
      current = current.parentContext;
    }
    return false;
  }

  /// Extracts href ID from a use node.
  static String? _extractHrefIdFromNode(SvgNode node) {
    var href = node.getAttributeValue('href')?.toString();
    href ??= node.getAttributeValue('xlink:href')?.toString();
    if (href == null || href.isEmpty) return null;
    if (href.startsWith('#')) return href.substring(1);
    return null;
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
    if (hrefId == null || hrefId.isEmpty) {
      // Empty use (href to non-existent ID) - no hit
      return null;
    }

    // Check for circular reference in use stack
    if (useStack.contains(hrefId)) {
      // Circular reference detected - no hit, no crash
      return null;
    }

    // Check for circular reference through use context chain
    if (context != null && context.hasCircularReference(hrefId)) {
      // Circular reference in context chain - no hit, no crash
      return null;
    }

    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    if (useStack.length >= _kMaxUseRecursionDepthHitTest) {
      // Depth limit exceeded - no hit
      return null;
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      // Referenced element not found or not allowed - no hit
      return null;
    }

    // Check pointer-events on the <use> element itself
    // Per SVG spec, pointer-events on <use> affects the entire shadow tree
    final usePointerEvents = _resolvePointerEventsMode(useNode);
    if (usePointerEvents == 'none') {
      return null;
    }

    // Create context for pointer-events inheritance and event retargeting.
    // Pass the use element ID for event retargeting.
    // Events on use shadow content should bubble up to the use element.
    final useContext =
        context?.copyWith(
          inheritedPointerEvents: usePointerEvents,
          useElementId: useNode.id,
          useNode: useNode,
        ) ??
        _UseHitTestContext(
          inheritedPointerEvents: usePointerEvents,
          useElementId: useNode.id,
          useNode: useNode,
        );

    // Build transform: first apply use's transform attribute (if any),
    // then apply x/y translation for proper coordinate stacking
    final referenceTransform = Matrix4.copy(currentTransform);

    // Apply use element's transform attribute using the shared transform helper
    _applyNodeTransform(referenceTransform, useNode);

    // Apply x/y translation after any explicit transform
    referenceTransform.translateByDouble(
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
              // Apply event retargeting - return use element ID instead
              // This implements event bubbling from use content
              return useContext.getRetargetedId(hitChild);
            }
          }
          return null;
        }
        final hitResult = _hitTestNodeWithUseContext(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
          foreignObjectParent: null,
          useContext: useContext,
        );
        // Apply event retargeting - events bubble up to use element
        return hitResult != null ? useContext.getRetargetedId(hitResult) : null;
      }

      final hitResult = _hitTestNodeWithUseContext(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
        foreignObjectParent: null,
        useContext: useContext,
      );
      // Apply event retargeting - events bubble up to use element
      return hitResult != null ? useContext.getRetargetedId(hitResult) : null;
    } finally {
      referenced.parent = previousParent;
    }
  }

  /// Hit tests a node with <use> context for pointer-events inheritance.
  /// Properly handles nested use elements and text content within use shadows.
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
    // Per CSS spec: display:none elements are NOT hit-testable
    if (_isDisplayNone(node)) {
      return null;
    }
    // Per CSS spec: visibility:hidden elements are NOT hit-testable
    // But we check this at the pointer-events level for proper inheritance
    // Note: opacity:0 elements ARE still hit-testable per CSS spec

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
