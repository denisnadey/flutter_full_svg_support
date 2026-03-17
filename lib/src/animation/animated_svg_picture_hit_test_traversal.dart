part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateHitTestTraversalExtension
    on _AnimatedSvgPictureState {
  String? _hitTestElementId(Offset localPosition) {
    if (_timeline == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final documentPoint = _localToDocumentPoint(
      localPosition,
      renderObject.size,
    );
    if (documentPoint == null) return null;

    return _hitTestNode(
      _document.root,
      documentPoint,
      Matrix4.identity(),
      useStack: const <String>{},
    );
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

  String? _hitTestNode(
    SvgNode node,
    Offset documentPoint,
    Matrix4 parentTransform, {
    required Set<String> useStack,
  }) {
    if (_isDefinitionOnlyTag(node.tagName)) {
      return null;
    }
    if (_isDisplayNone(node)) {
      return null;
    }

    final currentUseStack = useStack;
    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    if (!_isPointVisibleForNode(node, documentPoint, currentTransform)) {
      return null;
    }
    final pointerEventsNone = _isPointerEventsNone(node);

    final childTransform = Matrix4.copy(currentTransform);
    _applyForeignObjectChildTransform(childTransform, node);

    if (node.tagName == 'switch') {
      final activeChild = resolveActiveSwitchChild(node);
      if (activeChild == null) {
        return null;
      }
      return _hitTestNode(
        activeChild,
        documentPoint,
        childTransform,
        useStack: currentUseStack,
      );
    }

    // Идём с конца: последний нарисованный элемент визуально сверху
    for (int i = node.children.length - 1; i >= 0; i--) {
      final hitChild = _hitTestNode(
        node.children[i],
        documentPoint,
        childTransform,
        useStack: currentUseStack,
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
      );
      if (hitReferenced != null) {
        return hitReferenced;
      }
    }

    if (pointerEventsNone ||
        node.id == null ||
        !_isHitTestableTag(node.tagName)) {
      return null;
    }

    return _nodeContainsPoint(node, documentPoint, currentTransform)
        ? node.id
        : null;
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
