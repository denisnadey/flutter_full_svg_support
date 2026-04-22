part of 'animated_svg_painter.dart';

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
  ///
  /// Per SVG spec, each use element's x/y attributes contribute a translation,
  /// and its transform attribute is composed on top. These stack correctly
  /// for deeply nested use references (3+ levels).
  Matrix4 get accumulatedTransform {
    final matrix = Matrix4.identity();

    // First apply parent's accumulated transform
    if (parentContext != null) {
      matrix.multiply(parentContext!.accumulatedTransform);
    }

    // Then apply this use element's transform attribute if present
    final transformStr = useNode.getAttributeValue('transform')?.toString();
    if (transformStr != null && transformStr.isNotEmpty) {
      final transformMatrix = _parseTransformAttribute(transformStr);
      if (transformMatrix != null) {
        matrix.multiply(transformMatrix);
      }
    }

    // Finally apply x/y translation
    final x = useNode.getAttributeValue('x');
    final y = useNode.getAttributeValue('y');
    final xVal = x is num ? x.toDouble() : double.tryParse(x?.toString() ?? '');
    final yVal = y is num ? y.toDouble() : double.tryParse(y?.toString() ?? '');
    if (xVal != null || yVal != null) {
      matrix.translateByDouble(xVal ?? 0.0, yVal ?? 0.0, 0.0, 1.0);
    }

    return matrix;
  }

  /// Parses a transform attribute string into a Matrix4.
  /// Returns null if the string is invalid or empty.
  static Matrix4? _parseTransformAttribute(String value) {
    if (value.trim().isEmpty) return null;

    final result = Matrix4.identity();
    // Match transform functions: name(params)
    final regex = RegExp(r'(\w+)\s*\(([^)]+)\)');

    for (final match in regex.allMatches(value)) {
      final funcName = match.group(1)?.toLowerCase();
      final params = match.group(2);
      if (funcName == null || params == null) continue;

      // Parse comma/space separated numbers
      final numbers = params
          .split(RegExp(r'[,\s]+'))
          .map((s) => double.tryParse(s.trim()))
          .where((n) => n != null)
          .cast<double>()
          .toList();

      switch (funcName) {
        case 'translate':
          if (numbers.isNotEmpty) {
            final tx = numbers[0];
            final ty = numbers.length > 1 ? numbers[1] : 0.0;
            result.translateByDouble(tx, ty, 0.0, 1.0);
          }
        case 'scale':
          if (numbers.isNotEmpty) {
            final sx = numbers[0];
            final sy = numbers.length > 1 ? numbers[1] : sx;
            result.scaleByDouble(sx, sy, 1.0, 1.0);
          }
        case 'rotate':
          if (numbers.isNotEmpty) {
            final angle = numbers[0] * (3.141592653589793 / 180.0);
            if (numbers.length >= 3) {
              final cx = numbers[1];
              final cy = numbers[2];
              result.translateByDouble(cx, cy, 0.0, 1.0);
              result.rotateZ(angle);
              result.translateByDouble(-cx, -cy, 0.0, 1.0);
            } else {
              result.rotateZ(angle);
            }
          }
        case 'skewx':
          if (numbers.isNotEmpty) {
            final angle = numbers[0] * (3.141592653589793 / 180.0);
            final skewMatrix = Matrix4.identity();
            skewMatrix.setEntry(0, 1, angle);
            result.multiply(skewMatrix);
          }
        case 'skewy':
          if (numbers.isNotEmpty) {
            final angle = numbers[0] * (3.141592653589793 / 180.0);
            final skewMatrix = Matrix4.identity();
            skewMatrix.setEntry(1, 0, angle);
            result.multiply(skewMatrix);
          }
        case 'matrix':
          if (numbers.length >= 6) {
            final m = Matrix4.identity();
            m.setEntry(0, 0, numbers[0]);
            m.setEntry(1, 0, numbers[1]);
            m.setEntry(0, 1, numbers[2]);
            m.setEntry(1, 1, numbers[3]);
            m.setEntry(0, 3, numbers[4]);
            m.setEntry(1, 3, numbers[5]);
            result.multiply(m);
          }
      }
    }

    return result;
  }

  /// Composes transforms from nested use chain with a new viewBox transform.
  Matrix4 composeNestedTransform({
    required Matrix4 viewBoxMatrix,
    double useX = 0.0,
    double useY = 0.0,
    Matrix4? useTransform,
  }) {
    final combined = Matrix4.identity();
    if (parentContext != null) {
      combined.multiply(parentContext!.accumulatedTransform);
    }
    if (useTransform != null) {
      combined.multiply(useTransform);
    }
    if (useX != 0.0 || useY != 0.0) {
      combined.translateByDouble(useX, useY, 0.0, 1.0);
    }
    combined.multiply(viewBoxMatrix);
    return combined;
  }

  /// Gets the inherited value for a property, checking the use chain.
  ///
  /// Per SVG spec, inherited CSS properties flow through <use> shadow boundaries.
  /// This method traverses the use chain from innermost to outermost, allowing
  /// each level to override or inherit from its parent.
  ///
  /// For nested use-within-use, the cascade chain is maintained through all
  /// levels via parentContext, ensuring proper inheritance resolution.
  Object? getInheritedValue(String property) {
    final normalizedProp = property.trim().toLowerCase();

    // Only allow inheritable properties to flow through use boundaries
    if (!normalizedProp.startsWith('--') &&
        !_cssInheritablePropertiesForUse.contains(normalizedProp)) {
      return null;
    }

    // Check this use element's style attribute
    final styleValue = _extractStyleValueFromNode(useNode, normalizedProp);
    if (styleValue != null) {
      return styleValue;
    }

    // Check this use element's presentation attribute
    final attrValue = useNode.getAttributeValue(property);
    if (attrValue != null) {
      return attrValue;
    }

    // Walk up DOM ancestors of this use element
    SvgNode? ancestor = useNode.parent;
    int ancestorDepth = 0;
    const maxAncestorDepth = 100; // Prevent infinite loops

    while (ancestor != null && ancestorDepth < maxAncestorDepth) {
      ancestorDepth++;

      // Stop at another use element - defer to parent context
      if (ancestor.tagName.toLowerCase() == 'use') {
        break;
      }

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

    // Recursively check parent use context for nested use chains
    return parentContext?.getInheritedValue(property);
  }

  /// Gets the inherited value for visibility, with special cascade handling.
  ///
  /// Per SVG spec, visibility cascades through use boundaries but respects
  /// the 'inherit' keyword which explicitly requests parent value.
  String? getInheritedVisibility() {
    final visibility = _extractStyleValueFromNode(useNode, 'visibility');
    if (visibility != null && visibility.toLowerCase() != 'inherit') {
      return visibility;
    }
    final attrValue = useNode.getAttributeValue('visibility')?.toString();
    if (attrValue != null &&
        attrValue.isNotEmpty &&
        attrValue.toLowerCase() != 'inherit') {
      return attrValue;
    }
    // Walk ancestors
    SvgNode? ancestor = useNode.parent;
    while (ancestor != null) {
      final ancestorVisibility = _extractStyleValueFromNode(
        ancestor,
        'visibility',
      );
      if (ancestorVisibility != null &&
          ancestorVisibility.toLowerCase() != 'inherit') {
        return ancestorVisibility;
      }
      final ancestorAttr = ancestor.getAttributeValue('visibility')?.toString();
      if (ancestorAttr != null &&
          ancestorAttr.isNotEmpty &&
          ancestorAttr.toLowerCase() != 'inherit') {
        return ancestorAttr;
      }
      ancestor = ancestor.parent;
    }
    return parentContext?.getInheritedVisibility();
  }

  /// Checks if visibility is hidden in the use context chain.
  ///
  /// Per SVG spec, if any ancestor in the use chain has visibility:hidden,
  /// the content is hidden unless a descendant explicitly overrides.
  bool isVisibilityHidden() {
    final visibility = getInheritedVisibility()?.toLowerCase();
    return visibility == 'hidden' || visibility == 'collapse';
  }

  /// Gets the inherited value for display property.
  ///
  /// Note: display:none does NOT inherit in CSS, but we track it through
  /// use boundaries because if a <use> element has display:none, its
  /// entire shadow content should not render.
  String? getUseDisplayValue() {
    final display = _extractStyleValueFromNode(useNode, 'display');
    if (display != null) {
      return display;
    }
    final attrValue = useNode.getAttributeValue('display')?.toString();
    if (attrValue != null && attrValue.isNotEmpty) {
      return attrValue;
    }
    // display does NOT cascade through use boundaries per CSS spec
    return null;
  }

  /// Checks if the use element has display:none.
  bool isDisplayNone() {
    final display = getUseDisplayValue()?.toLowerCase();
    return display == 'none';
  }

  /// Resolves a CSS property from document style rules for a given node.
  String? resolveCssRuleValue(SvgNode node, String property) {
    if (cssRules == null || cssRules!.isEmpty) {
      return null;
    }
    final normalizedProperty = property.trim().toLowerCase();
    final resolver = CssCascadeResolver(cssRules: cssRules!);
    return resolver.resolveFromStyleRulesOnly(node, normalizedProperty);
  }

  /// Resolves a CSS property with full cascade, including use context.
  String? resolvePropertyWithCascade(SvgNode node, String property) {
    final normalizedProperty = property.trim().toLowerCase();
    final inlineValue = _extractStyleValueFromNode(node, normalizedProperty);
    if (inlineValue != null) {
      if (inlineValue.contains('!important')) {
        return inlineValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
      }
    }
    String? cssRuleValue;
    if (cssRules != null && cssRules!.isNotEmpty) {
      final resolver = CssCascadeResolver(cssRules: cssRules!);
      cssRuleValue = resolver.resolveFromStyleRulesOnly(
        node,
        normalizedProperty,
      );
    }
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();
    if (inlineValue != null) {
      return inlineValue;
    }
    if (cssRuleValue != null) {
      return cssRuleValue;
    }
    if (attrValue != null) {
      return attrValue;
    }
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
    final inlineValue = _extractStyleValueFromNode(node, normalizedProperty);
    if (inlineValue != null) {
      final hasImportant = inlineValue.contains('!important');
      final cleanValue = inlineValue
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (hasImportant && cleanValue.isNotEmpty) {
        return cleanValue;
      }
    }
    String? cssRuleValue;
    if (cssRules != null && cssRules!.isNotEmpty) {
      final resolver = CssCascadeResolver(cssRules: cssRules!);
      cssRuleValue = resolver.resolveFromStyleRulesOnly(
        node,
        normalizedProperty,
      );
    }
    if (cssRuleValue != null) {
      if (inlineValue != null) {
        final cleanInlineValue = inlineValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
        if (cleanInlineValue.isNotEmpty) {
          return cleanInlineValue;
        }
      }
      return cssRuleValue;
    }
    if (inlineValue != null) {
      final cleanInlineValue = inlineValue
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (cleanInlineValue.isNotEmpty) {
        return cleanInlineValue;
      }
    }
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();
    if (attrValue != null && attrValue.trim().isNotEmpty) {
      return attrValue;
    }
    if (_cssInheritablePropertiesForUse.contains(normalizedProperty) ||
        normalizedProperty.startsWith('--')) {
      final useStyleValue = _extractStyleValueFromNode(
        useNode,
        normalizedProperty,
      );
      if (useStyleValue != null) {
        return useStyleValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
      }
      final useAttrValue = useNode.getAttributeValue(normalizedProperty);
      if (useAttrValue != null) {
        return useAttrValue.toString();
      }
    }
    final inheritedValue = getInheritedValue(normalizedProperty);
    return inheritedValue?.toString();
  }

  /// Gets the outermost use node ID for event retargeting.
  ///
  /// Per SVG spec, events from elements inside a use shadow tree should be
  /// retargeted to the use element itself when bubbling past the shadow boundary.
  /// For nested use chains, this returns the outermost use element's ID.
  String? get retargetedEventId {
    final root = rootContext;
    return root.useNode.id;
  }

  /// Gets the event target chain for bubbling through use shadow boundaries.
  ///
  /// When an event originates from content inside a use shadow tree,
  /// it should bubble through each use element in the chain. This method
  /// returns the list of use elements from innermost to outermost.
  List<SvgNode> get eventRetargetChain {
    final chain = <SvgNode>[];
    _UseInheritanceContext? current = this;
    while (current != null) {
      chain.add(current.useNode);
      current = current.parentContext;
    }
    return chain;
  }

  /// Determines if an event from the given element should be retargeted.
  ///
  /// Returns true if the element is inside the use shadow tree and events
  /// from it should be retargeted to the use element when bubbling.
  bool shouldRetargetEventFrom(SvgNode element) {
    // Events from any element within this use context's shadow tree
    // should be retargeted to the use element
    return true;
  }

  /// Gets the retargeted event target for an event originating from
  /// the given element within this use shadow tree.
  ///
  /// For simple cases, this returns the use element itself.
  /// For nested use, this returns the appropriate use element based on
  /// which shadow boundary the event is crossing.
  SvgNode getRetargetedEventTarget(SvgNode sourceElement) {
    return useNode;
  }

  /// Gets all use element IDs in the chain from outermost to current.
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
  String? getCustomProperty(String name) {
    final normalizedName = name.trim();
    if (!normalizedName.startsWith('--')) {
      return null;
    }
    final styleValue = _extractStyleValueFromNode(useNode, normalizedName);
    if (styleValue != null) {
      return styleValue;
    }
    SvgNode? ancestor = useNode.parent;
    while (ancestor != null) {
      final ancestorValue = _extractStyleValueFromNode(
        ancestor,
        normalizedName,
      );
      if (ancestorValue != null) {
        return ancestorValue;
      }
      if (ancestor.cssCustomProperties.has(normalizedName)) {
        return ancestor.cssCustomProperties.get(normalizedName);
      }
      ancestor = ancestor.parent;
    }
    return parentContext?.getCustomProperty(normalizedName);
  }

  /// Gets the inherited pointer-events value through use boundaries.
  ///
  /// Per SVG spec, pointer-events on a <use> element affects the entire
  /// shadow tree. This cascades correctly through nested use elements.
  String? getInheritedPointerEvents() {
    final pointerEvents = _extractStyleValueFromNode(useNode, 'pointer-events');
    if (pointerEvents != null && pointerEvents.toLowerCase() != 'inherit') {
      return pointerEvents;
    }
    final attrValue = useNode.getAttributeValue('pointer-events')?.toString();
    if (attrValue != null &&
        attrValue.isNotEmpty &&
        attrValue.toLowerCase() != 'inherit') {
      return attrValue;
    }
    // Walk ancestors
    SvgNode? ancestor = useNode.parent;
    while (ancestor != null) {
      final ancestorEvents = _extractStyleValueFromNode(
        ancestor,
        'pointer-events',
      );
      if (ancestorEvents != null && ancestorEvents.toLowerCase() != 'inherit') {
        return ancestorEvents;
      }
      final ancestorAttr = ancestor
          .getAttributeValue('pointer-events')
          ?.toString();
      if (ancestorAttr != null &&
          ancestorAttr.isNotEmpty &&
          ancestorAttr.toLowerCase() != 'inherit') {
        return ancestorAttr;
      }
      ancestor = ancestor.parent;
    }
    return parentContext?.getInheritedPointerEvents();
  }

  /// Checks if pointer-events is 'none' in the use context chain.
  bool isPointerEventsNone() {
    final pointerEvents = getInheritedPointerEvents()?.toLowerCase();
    return pointerEvents == 'none';
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
  Matrix4 get accumulatedViewBoxTransform {
    final matrix = Matrix4.identity();
    if (parentContext != null) {
      matrix.multiply(parentContext!.accumulatedViewBoxTransform);
    }
    return matrix;
  }

  /// Applies viewBox transform to accumulated transform for symbol references.
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
