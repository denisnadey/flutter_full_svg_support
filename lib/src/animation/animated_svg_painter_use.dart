part of 'animated_svg_painter.dart';

/// Maximum recursion depth for nested <use> elements (matching Blink).
/// This prevents infinite loops and excessive resource usage.
const int _kMaxUseRecursionDepth = 10;

/// Global CSS rules available during painting.
/// Set by the painter when rendering begins.
List<CssSelectorRule>? _currentDocumentCssRules;

/// CSS properties that are inherited by default per CSS/SVG specification.
/// Non-inherited properties (like opacity, transform, display) should NOT
/// flow through <use> boundaries.
const Set<String> _cssInheritablePropertiesForUse = {
  // Color properties
  'color',

  // Font properties
  'font',
  'font-family',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'font-feature-settings',
  'font-variation-settings',

  // Text properties
  'letter-spacing',
  'line-height',
  'text-align',
  'text-indent',
  'text-transform',
  'white-space',
  'word-spacing',
  'word-break',
  'word-wrap',
  'overflow-wrap',
  'direction',
  'writing-mode',
  'text-orientation',
  'dominant-baseline',
  'alignment-baseline',
  'baseline-shift',

  // SVG specific inheritable properties
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-opacity',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'marker',
  'marker-start',
  'marker-mid',
  'marker-end',
  'paint-order',
  'color-interpolation',
  'color-interpolation-filters',
  'color-rendering',
  'shape-rendering',
  'text-rendering',
  'image-rendering',

  // Visibility
  'visibility',
  'pointer-events',
  'cursor',

  // Text decoration (partially inheritable)
  'text-decoration',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',

  // Text emphasis
  'text-emphasis',
  'text-emphasis-color',
  'text-emphasis-position',
  'text-emphasis-style',
};

/// CSS properties that cross foreignObject boundaries.
/// These are the same inheritable properties that CSS defines,
/// which flow from SVG context into foreignObject HTML content.
/// Note: foreignObject establishes a new stacking context, so
/// non-inherited properties (transform, opacity, clip-path, etc.)
/// do NOT cross the boundary.
const Set<String> cssInheritablePropertiesForForeignObject =
    _cssInheritablePropertiesForUse;

/// Context for tracking inherited CSS properties across <use> element boundaries.
///
/// Per SVG spec, presentation attributes and inherited CSS properties on a
/// <use> element should be visible to the referenced content. This context
/// captures those inherited values and makes them available during rendering
/// of the referenced subtree.
///
/// Cascade priority (highest to lowest):
/// 1. Inline style on referenced element (with !important taking absolute priority)
/// 2. CSS rules from <style> blocks (by specificity, then source order)
/// 3. Presentation attributes on referenced element
/// 4. Inherited from <use> element's style attribute (for inheritable props only)
/// 5. Inherited from <use> element's presentation attributes (for inheritable props)
/// 6. Inherited from use's ancestors (DOM tree)
/// 7. Inherited from parent use context (nested use chains)
///
/// IMPORTANT: Only inheritable CSS properties should flow through <use> boundaries.
/// Non-inherited properties (opacity, transform, display, clip-path, mask, filter)
/// should NOT cascade to referenced content.
///
/// ID Namespace Scoping:
/// When multiple <use> elements reference the same content, internal IDs (for
/// filters, gradients, clip-paths) are scoped per-use instance to avoid conflicts.
/// Each use context tracks its unique instance ID for proper ID resolution.
///
/// Shadow Boundary Behavior:
/// Per SVG 2 spec, <use> creates a shadow-like scope:
/// - CSS selectors with combinators (>, ~, +, space) stop at shadow boundary
/// - Inherited CSS properties flow through the boundary
/// - Original definition context CSS rules still apply to referenced elements
class _UseInheritanceContext {
  _UseInheritanceContext({
    required this.useNode,
    this.parentContext,
    this.cssRules,
    this.shadowRootId,
  }) : instanceId = _generateInstanceId();

  /// Global counter for generating unique instance IDs.
  static int _instanceCounter = 0;

  /// Generates a unique instance ID for ID namespace scoping.
  static String _generateInstanceId() {
    _instanceCounter++;
    return '__use_${_instanceCounter}__';
  }

  /// Resets the instance counter (useful for testing).
  // ignore: unused_element
  static void resetInstanceCounter() {
    _instanceCounter = 0;
  }

  /// The <use> element providing inherited properties.
  final SvgNode useNode;

  /// Parent inheritance context for nested <use> chains.
  final _UseInheritanceContext? parentContext;

  /// CSS rules from the document's <style> blocks.
  /// Used to resolve CSS class/id rules on referenced elements.
  final List<CssSelectorRule>? cssRules;

  /// ID of the referenced element (shadow root).
  /// Used for tracking shadow DOM boundaries in selector matching.
  final String? shadowRootId;

  /// Unique instance ID for this use context.
  /// Used for ID namespace scoping when multiple uses reference same content.
  final String instanceId;

  /// Gets the depth of nested use contexts.
  int get depth => parentContext == null ? 1 : 1 + parentContext!.depth;

  /// Accumulated x/y transform stack for nested uses.
  /// Each level adds its own x/y offset.
  Matrix4 get accumulatedTransform {
    final matrix = Matrix4.identity();

    // Start with parent context transform if nested
    if (parentContext != null) {
      matrix.multiply(parentContext!.accumulatedTransform);
    }

    // Add this use's x/y offset
    final x = useNode.getAttributeValue('x');
    final y = useNode.getAttributeValue('y');
    final xVal = x is num ? x.toDouble() : double.tryParse(x?.toString() ?? '');
    final yVal = y is num ? y.toDouble() : double.tryParse(y?.toString() ?? '');

    if (xVal != null || yVal != null) {
      matrix.translateByDouble(xVal ?? 0.0, yVal ?? 0.0, 0.0, 1.0);
    }

    return matrix;
  }

  /// Gets the inherited value for a property, checking the use chain.
  /// Returns null if the property is not inheritable or not set on any
  /// use element in the chain.
  ///
  /// Per SVG spec, only inheritable CSS properties should flow through
  /// <use> boundaries. Non-inherited properties stay on the <use> element
  /// itself and do not cascade to referenced content.
  Object? getInheritedValue(String property) {
    final normalizedProp = property.trim().toLowerCase();

    // Per SVG spec: only inheritable properties flow through <use> boundaries.
    // Non-inherited properties (opacity, transform, display, etc.) should NOT
    // cascade to the referenced content.
    //
    // CSS custom properties (starting with --) are always inherited.
    if (!normalizedProp.startsWith('--') &&
        !_cssInheritablePropertiesForUse.contains(normalizedProp)) {
      return null;
    }

    // Check style attribute first (highest specificity)
    final styleValue = _extractStyleValueFromNode(useNode, normalizedProp);
    if (styleValue != null) {
      return styleValue;
    }

    // Check presentation attribute
    final attrValue = useNode.getAttributeValue(property);
    if (attrValue != null) {
      return attrValue;
    }

    // Check DOM ancestors of the use element
    SvgNode? ancestor = useNode.parent;
    while (ancestor != null) {
      final ancestorStyleValue = _extractStyleValueFromNode(
        ancestor,
        normalizedProp,
      );
      if (ancestorStyleValue != null) {
        return ancestorStyleValue;
      }
      final ancestorAttrValue = ancestor.getAttributeValue(property);
      if (ancestorAttrValue != null) {
        return ancestorAttrValue;
      }
      ancestor = ancestor.parent;
    }

    // Check parent context (for nested use chains)
    return parentContext?.getInheritedValue(property);
  }

  /// Resolves a CSS property from document style rules for a given node.
  /// This handles CSS class and id selectors that should apply to the
  /// referenced element.
  ///
  /// Per SVG spec cascade order:
  /// 1. Inline style on referenced element (highest)
  /// 2. Document CSS rules matching referenced element
  /// 3. Presentation attributes on referenced element
  /// 4. Use element inherited values
  String? resolveCssRuleValue(SvgNode node, String property) {
    if (cssRules == null || cssRules!.isEmpty) {
      return null;
    }

    final normalizedProperty = property.trim().toLowerCase();
    final resolver = CssCascadeResolver(cssRules: cssRules!);
    return resolver.resolveOwnProperty(node, normalizedProperty);
  }

  /// Resolves a CSS property with full cascade, including use context.
  /// This method implements the complete cascade order:
  /// 1. Inline style on node (with !important check)
  /// 2. CSS rules matching node (by specificity)
  /// 3. Presentation attributes on node
  /// 4. Inherited from use element (for inheritable properties)
  ///
  /// Returns null if the property is not set anywhere in the cascade.
  String? resolvePropertyWithCascade(SvgNode node, String property) {
    final normalizedProperty = property.trim().toLowerCase();

    // 1. Check inline style on node first (highest priority except !important)
    final inlineValue = _extractStyleValueFromNode(node, normalizedProperty);
    if (inlineValue != null) {
      // Check for !important - it wins everything
      if (inlineValue.contains('!important')) {
        return inlineValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
      }
    }

    // 2. Check CSS rules from <style> (respects shadow boundary)
    String? cssRuleValue;
    if (cssRules != null && cssRules!.isNotEmpty) {
      final resolver = CssCascadeResolver(cssRules: cssRules!);
      // Pass shadow boundary info for proper combinator matching
      cssRuleValue = resolver.resolveOwnProperty(node, normalizedProperty);
    }

    // 3. Check presentation attribute on node
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();

    // Determine winner between inline, CSS rule, and presentation attribute
    // Inline (non-important) > CSS rule > presentation attribute
    if (inlineValue != null) {
      return inlineValue;
    }
    if (cssRuleValue != null) {
      return cssRuleValue;
    }
    if (attrValue != null) {
      return attrValue;
    }

    // 4. Check inherited from use context (for inheritable properties)
    final inheritedValue = getInheritedValue(normalizedProperty);
    return inheritedValue?.toString();
  }

  /// Resolves a CSS property for use shadow boundary with full cascade.
  /// This handles the special case where CSS rules from the original
  /// definition context still apply to the referenced element.
  ///
  /// Per SVG 2 spec and CSS cascade:
  /// 1. Inline styles on referenced elements (with !important taking absolute priority)
  /// 2. CSS rules from <style> apply normally (respecting shadow boundary for combinators)
  /// 3. Presentation attributes on referenced elements
  /// 4. Use element's style attribute (for inheritable properties only)
  /// 5. Use element's presentation attributes (for inheritable properties only)
  /// 6. Inherited from use's ancestors
  String? resolvePropertyWithShadowCascade(SvgNode node, String property) {
    final normalizedProperty = property.trim().toLowerCase();

    // 1. Check inline style on referenced element (highest priority except !important)
    final inlineValue = _extractStyleValueFromNode(node, normalizedProperty);
    if (inlineValue != null) {
      final hasImportant = inlineValue.contains('!important');
      final cleanValue = inlineValue
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      // !important wins everything
      if (hasImportant && cleanValue.isNotEmpty) {
        return cleanValue;
      }
    }

    // 2. CSS rules from original definition context
    String? cssRuleValue;
    if (cssRules != null && cssRules!.isNotEmpty) {
      final resolver = CssCascadeResolver(cssRules: cssRules!);
      // Use resolveOwnProperty which handles specificity properly
      cssRuleValue = resolver.resolveOwnProperty(node, normalizedProperty);
    }

    // CSS rule value exists - check if inline value exists
    if (cssRuleValue != null) {
      // Non-important inline beats CSS rules (inline has higher specificity)
      if (inlineValue != null) {
        final cleanInlineValue = inlineValue
            .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
            .trim();
        if (cleanInlineValue.isNotEmpty) {
          return cleanInlineValue;
        }
      }
      // CSS rule wins
      return cssRuleValue;
    }

    // Only inline value exists (no CSS rule)
    if (inlineValue != null) {
      final cleanInlineValue = inlineValue
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (cleanInlineValue.isNotEmpty) {
        return cleanInlineValue;
      }
    }

    // 3. Presentation attribute on referenced element
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();
    if (attrValue != null && attrValue.trim().isNotEmpty) {
      return attrValue;
    }

    // 4 & 5. Use element's inherited values (for inheritable properties only)
    // Presentation attrs on <use> override inherited values but NOT inline/CSS
    if (_cssInheritablePropertiesForUse.contains(normalizedProperty) ||
        normalizedProperty.startsWith('--')) {
      // Check use element's style attribute first
      final useStyleValue = _extractStyleValueFromNode(
        useNode,
        normalizedProperty,
      );
      if (useStyleValue != null) {
        return useStyleValue
            .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
            .trim();
      }

      // Check use element's presentation attributes
      final useAttrValue = useNode.getAttributeValue(normalizedProperty);
      if (useAttrValue != null) {
        return useAttrValue.toString();
      }
    }

    // 6. Inherited from use's ancestors
    final inheritedValue = getInheritedValue(normalizedProperty);
    return inheritedValue?.toString();
  }

  /// Gets the outermost use node ID for event retargeting.
  /// Per SVG spec, events from shadow content should target the <use> element.
  String? get retargetedEventId {
    // Return the outermost use element's ID
    final root = rootContext;
    return root.useNode.id;
  }

  /// Gets all use element IDs in the chain from outermost to current.
  /// Useful for event bubbling through nested use elements.
  List<String?> get useChainIds {
    final ids = <String?>[];
    _UseInheritanceContext? current = this;
    while (current != null) {
      ids.insert(0, current.useNode.id);
      current = current.parentContext;
    }
    return ids;
  }

  /// Gets a CSS custom property value from the use chain.
  /// Custom properties are always inherited.
  /// This method also checks the DOM ancestors of the use element.
  String? getCustomProperty(String name) {
    final normalizedName = name.trim();
    if (!normalizedName.startsWith('--')) {
      return null;
    }

    // Check style attribute for custom property on the use element
    final styleValue = _extractStyleValueFromNode(useNode, normalizedName);
    if (styleValue != null) {
      return styleValue;
    }

    // Check DOM ancestors of the use element for custom property.
    // CSS custom properties are inherited, so they cascade through the DOM.
    SvgNode? ancestor = useNode.parent;
    while (ancestor != null) {
      final ancestorValue = _extractStyleValueFromNode(
        ancestor,
        normalizedName,
      );
      if (ancestorValue != null) {
        return ancestorValue;
      }
      // Also check if ancestor has cssCustomProperties store
      if (ancestor.cssCustomProperties.has(normalizedName)) {
        return ancestor.cssCustomProperties.get(normalizedName);
      }
      ancestor = ancestor.parent;
    }

    // Check parent use context (for nested use chains)
    return parentContext?.getCustomProperty(normalizedName);
  }

  /// Checks if this use context or any parent context already references
  /// the given ID, which would indicate a circular reference.
  bool hasCircularReference(String targetId) {
    if (shadowRootId == targetId) {
      return true;
    }
    return parentContext?.hasCircularReference(targetId) ?? false;
  }

  /// Gets the full use context chain from root to current as a list.
  /// Useful for debugging and understanding the inheritance chain.
  List<_UseInheritanceContext> get contextChain {
    final chain = <_UseInheritanceContext>[];
    _UseInheritanceContext? current = this;
    while (current != null) {
      chain.insert(0, current);
      current = current.parentContext;
    }
    return chain;
  }

  /// Gets a scoped ID that is unique to this use instance.
  /// This is used for internal references (gradients, filters, etc.) to
  /// avoid conflicts when the same content is referenced by multiple uses.
  String getScopedId(String originalId) {
    return '${instanceId}$originalId';
  }

  /// Gets the root use context (the outermost use in nested chains).
  _UseInheritanceContext get rootContext {
    return parentContext?.rootContext ?? this;
  }

  /// Checks if this context is nested (has a parent context).
  bool get isNested => parentContext != null;

  /// Gets the accumulated viewBox transforms for nested symbol references.
  /// Each symbol in the chain may have its own viewBox transform.
  Matrix4 get accumulatedViewBoxTransform {
    final matrix = Matrix4.identity();

    // Start with parent context viewBox transform if nested
    if (parentContext != null) {
      matrix.multiply(parentContext!.accumulatedViewBoxTransform);
    }

    return matrix;
  }

  /// Applies viewBox transform to accumulated transform for symbol references.
  /// Returns combined matrix with viewBox scaling.
  Matrix4 applyViewBoxTransform(Matrix4 viewBoxMatrix) {
    final combined = Matrix4.copy(accumulatedTransform);
    combined.multiply(viewBoxMatrix);
    return combined;
  }

  /// Gets the total nesting level considering both use and symbol nesting.
  int get totalNestingLevel {
    int level = 1;
    _UseInheritanceContext? current = parentContext;
    while (current != null) {
      level++;
      current = current.parentContext;
    }
    return level;
  }

  /// Gets the transform to apply for animation coordinate inheritance.
  /// This includes the x/y offset and any explicit transform on the use element.
  Matrix4? getUseTransform() {
    final x = useNode.getAttributeValue('x');
    final y = useNode.getAttributeValue('y');
    final transformStr = useNode.getAttributeValue('transform')?.toString();

    final xVal = x is num ? x.toDouble() : double.tryParse(x?.toString() ?? '');
    final yVal = y is num ? y.toDouble() : double.tryParse(y?.toString() ?? '');

    if (xVal == null && yVal == null && transformStr == null) {
      return null;
    }

    final matrix = Matrix4.identity();

    // Apply explicit transform first (if any)
    if (transformStr != null && transformStr.isNotEmpty) {
      // Note: Transform parsing is done elsewhere; this is for documentation
      // The transform is applied at the canvas level before painting
    }

    // Then apply x/y translation
    if (xVal != null || yVal != null) {
      matrix.translateByDouble(xVal ?? 0.0, yVal ?? 0.0, 0.0, 1.0);
    }

    return matrix;
  }

  /// Extracts a property value from an inline style attribute.
  static String? _extractStyleValueFromNode(SvgNode node, String property) {
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
      var value = parts.sublist(1).join(':').trim();
      value = value
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (value.isEmpty) {
        continue;
      }
      return value;
    }
    return null;
  }
}

extension AnimatedSvgPainterUseExtension on AnimatedSvgPainter {
  /// Checks if foreignObject should be rendered based on requiredExtensions.
  /// Per SVG spec, if requiredExtensions is specified and not supported,
  /// the foreignObject should not render (allowing <switch> fallback pattern).
  bool _shouldRenderForeignObject(SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return true;
    }

    // Check requiredExtensions - if specified, foreignObject should not render
    // as we don't support any foreign extensions in this implementation.
    final requiredExtensions = node.getAttributeValue('requiredExtensions');
    if (requiredExtensions != null &&
        requiredExtensions.toString().trim().isNotEmpty) {
      return false;
    }

    return true;
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

    // Check overflow attribute - default for foreignObject is hidden
    final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
    if (overflow != 'visible') {
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height), doAntiAlias: true);
    }
  }

  /// Applies nested SVG viewport transform within foreignObject.
  /// When foreignObject contains an <svg> element, the inner SVG establishes
  /// its own coordinate system with its own viewBox/viewport.
  void _applyNestedSvgViewportInForeignObject(
    ui.Canvas canvas,
    SvgNode svgNode,
    SvgNode? foreignObjectParent,
  ) {
    if (svgNode.tagName != 'svg' || foreignObjectParent == null) {
      return;
    }
    if (foreignObjectParent.tagName != 'foreignObject') {
      return;
    }

    // Get foreignObject viewport dimensions
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }

    // Get nested SVG attributes
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    var svgWidth = _getNumber(svgNode, 'width');
    var svgHeight = _getNumber(svgNode, 'height');

    // Default width/height to 100% of foreignObject viewport
    svgWidth ??= foWidth;
    svgHeight ??= foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }

    // Translate to SVG position
    if (svgX != 0 || svgY != 0) {
      canvas.translate(svgX, svgY);
    }

    // Apply viewBox transform if present
    final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final viewBox = _parseForeignObjectViewBox(viewBoxAttr);
      if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          sourceSize: ui.Size(viewBox.width, viewBox.height),
          preserveAspectRatio: svgNode
              .getAttributeValue('preserveAspectRatio')
              ?.toString(),
        );

        // Compute viewBox to viewport transform
        final scaleX = layout.destinationRect.width / viewBox.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        final translateX = layout.destinationRect.left - viewBox.left * scaleX;
        final translateY = layout.destinationRect.top - viewBox.top * scaleY;

        final transform = Matrix4.identity()
          ..translateByDouble(translateX, translateY, 0, 1)
          ..scaleByDouble(scaleX, scaleY, 1, 1);
        canvas.transform(transform.storage);

        // Clip if slice mode or overflow hidden
        final overflow = svgNode
            .getAttributeValue('overflow')
            ?.toString()
            .toLowerCase();
        if (layout.clipToViewport || overflow != 'visible') {
          canvas.clipRect(
            ui.Rect.fromLTWH(
              viewBox.left,
              viewBox.top,
              viewBox.width,
              viewBox.height,
            ),
            doAntiAlias: true,
          );
        }
      }
    } else {
      // No viewBox - clip to SVG dimensions if overflow is hidden
      final overflow = svgNode
          .getAttributeValue('overflow')
          ?.toString()
          .toLowerCase();
      if (overflow != 'visible') {
        canvas.clipRect(
          ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          doAntiAlias: true,
        );
      }
    }
  }

  ui.Rect? _parseForeignObjectViewBox(String viewBoxStr) {
    final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;
    final minX = double.tryParse(parts[0]);
    final minY = double.tryParse(parts[1]);
    final width = double.tryParse(parts[2]);
    final height = double.tryParse(parts[3]);
    if (minX == null || minY == null || width == null || height == null) {
      return null;
    }
    return ui.Rect.fromLTWH(minX, minY, width, height);
  }

  void _paintUse(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final hrefId = _extractHrefId(node);
    if (hrefId == null || hrefId.isEmpty) {
      // Empty use (href to non-existent ID) renders nothing
      return;
    }

    // Check for circular reference in use stack
    if (useStack.contains(hrefId)) {
      // Circular reference detected - render nothing, no crash
      return;
    }

    // Check for circular reference through use context chain
    if (useContext != null && useContext.hasCircularReference(hrefId)) {
      // Circular reference in context chain - render nothing, no crash
      return;
    }

    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    // This prevents excessive resource usage from deeply nested use chains.
    if (useStack.length >= _kMaxUseRecursionDepth) {
      // Depth limit exceeded - render nothing
      return;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      // Referenced element not found or not allowed - render nothing
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;

    canvas.save();

    // Apply use element's transform first (if any)
    final transformStr = node.getAttributeValue('transform')?.toString();
    if (transformStr != null && transformStr.isNotEmpty) {
      final transformMatrix = _buildTransformMatrixFromValue(transformStr);
      if (transformMatrix != null) {
        canvas.transform(transformMatrix.storage);
      }
    }

    // Then apply x/y translation
    canvas.translate(x, y);

    // Create inheritance context for this use boundary.
    // This allows CSS properties set on <use> to be inherited by referenced content.
    // Also pass CSS rules from document for proper class/id resolution.
    // Include the shadow root ID for circular reference tracking.
    final currentUseContext = _UseInheritanceContext(
      useNode: node,
      parentContext: useContext,
      cssRules: _currentDocumentCssRules ?? useContext?.cssRules,
      shadowRootId: hrefId,
    );

    // Apply opacity from use element to the shadow tree
    // opacity on use element propagates to shadow tree via saveLayer
    final opacityValue = node.getAttributeValue('opacity');
    final opacity = opacityValue != null
        ? (double.tryParse(opacityValue.toString()) ?? 1.0).clamp(0.0, 1.0)
        : 1.0;

    if (opacity < 1.0) {
      // Use saveLayer for opacity compositing
      final layerPaint = ui.Paint()
        ..color = ui.Color.fromARGB((opacity * 255).round(), 255, 255, 255);
      canvas.saveLayer(null, layerPaint);
    }

    final previousParent = referenced.parent;
    referenced.parent = node;
    try {
      final nextUseStack = <String>{...useStack, hrefId};
      if (referenced.tagName == 'symbol') {
        _paintSymbolReference(
          canvas,
          useNode: node,
          symbolNode: referenced,
          useStack: nextUseStack,
          useContext: currentUseContext,
        );
      } else if (referenced.tagName == 'svg') {
        _paintSvgUseReference(
          canvas,
          useNode: node,
          svgNode: referenced,
          useStack: nextUseStack,
          useContext: currentUseContext,
        );
      } else {
        _paintNodeWithUseContext(
          canvas,
          referenced,
          useStack: nextUseStack,
          useContext: currentUseContext,
        );
      }
    } finally {
      referenced.parent = previousParent;
    }

    // Restore opacity layer if we applied one
    if (opacity < 1.0) {
      canvas.restore();
    }

    canvas.restore();
  }

  void _paintSymbolReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode symbolNode,
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final viewportTransform = _resolveUseViewportTransform(
      useNode: useNode,
      referenceNode: symbolNode,
    );

    // Apply symbol viewport transform and clipping
    if (viewportTransform != null) {
      if (viewportTransform.clipRect != null) {
        canvas.clipRect(viewportTransform.clipRect!, doAntiAlias: true);
      }
      canvas.transform(viewportTransform.matrix.storage);
    } else {
      // Per SVG spec, symbol's default overflow is 'hidden'.
      // Apply clipping based on use element's width/height if specified,
      // or based on symbol's viewBox.
      _applySymbolOverflowClipping(canvas, useNode, symbolNode);
    }

    for (final child in symbolNode.children) {
      _paintNodeWithUseContext(
        canvas,
        child,
        useStack: useStack,
        useContext: useContext,
      );
    }
  }

  /// Applies overflow clipping for symbol elements.
  /// Symbol's default overflow is 'hidden' per SVG spec.
  void _applySymbolOverflowClipping(
    ui.Canvas canvas,
    SvgNode useNode,
    SvgNode symbolNode,
  ) {
    final overflow = _getInheritedString(symbolNode, 'overflow')?.toLowerCase();
    if (overflow == 'visible') {
      return; // No clipping needed
    }

    // Default is hidden - apply clipping based on use width/height or viewBox
    final useWidth = _getNumber(useNode, 'width');
    final useHeight = _getNumber(useNode, 'height');

    if (useWidth != null &&
        useHeight != null &&
        useWidth > 0 &&
        useHeight > 0) {
      canvas.clipRect(
        ui.Rect.fromLTWH(0, 0, useWidth, useHeight),
        doAntiAlias: true,
      );
      return;
    }

    // Fall back to symbol's viewBox for clipping
    final viewBox = _parseViewBox(_getString(symbolNode, 'viewBox'));
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      canvas.clipRect(viewBox, doAntiAlias: true);
    }
  }

  void _paintSvgUseReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode svgNode,
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final viewportTransform = _resolveUseViewportTransform(
      useNode: useNode,
      referenceNode: svgNode,
    );
    if (viewportTransform != null) {
      if (viewportTransform.clipRect != null) {
        canvas.clipRect(viewportTransform.clipRect!, doAntiAlias: true);
      }
      canvas.transform(viewportTransform.matrix.storage);
    }

    _paintNodeWithUseContext(
      canvas,
      svgNode,
      useStack: useStack,
      useContext: useContext,
    );
  }

  /// Paints a node with use inheritance context for proper CSS cascade.
  /// This method handles the inheritance of CSS properties from <use>
  /// elements to their referenced content.
  void _paintNodeWithUseContext(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    _paintNodeImplWithUseContext(
      this,
      canvas,
      node,
      useStack: useStack,
      useContext: useContext,
    );
  }

  void _paintSwitch(
    ui.Canvas canvas,
    SvgNode switchNode, {
    required Set<String> useStack,
  }) {
    final activeChild = resolveActiveSwitchChild(switchNode);
    if (activeChild == null) {
      return;
    }
    _paintNode(canvas, activeChild, useStack: useStack);
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
      case 'marker':
      case 'use':
      case 'text':
      case 'tspan':
      case 'textPath':
      case 'image':
      case 'switch':
        return false;
      case 'foreignObject':
        // Check requiredExtensions - if specified, don't render children
        if (!_shouldRenderForeignObject(node)) {
          return false;
        }
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return width > 0 && height > 0;
      default:
        return true;
    }
  }
}
