import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'css_animations.dart';
import 'svg_filters.dart';

/// Type of an SVG element attribute for correct interpolation
enum SvgAttributeType {
  /// Numeric value: x, y, width, height, opacity, stroke-width
  number,

  /// Length with units: px, em, %, pt, etc.
  length,

  /// Color: fill, stroke, stop-color
  color,

  /// Transformation: transform attribute
  transform,

  /// Path data: d attribute for `<path>`
  path,

  /// Point lists: points for `<polygon>`, `<polyline>`
  points,

  /// String value (for discrete animations)
  string,

  /// List value: stroke-dasharray and similar
  list,

  /// URL reference: for gradients, masks, filters
  url,
}

/// An SVG element attribute that can be animated
/// Base immutable class for constant values
@immutable
class SvgAttribute {
  /// Creates an attribute with a base value
  const SvgAttribute({
    required this.name,
    required this.baseValue,
    this.type = SvgAttributeType.string,
  });

  /// Attribute name (e.g. 'x', 'y', 'fill', 'transform')
  final String name;

  /// Base value from XML/CSS
  final Object baseValue;

  /// Attribute type (for correct interpolation)
  final SvgAttributeType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgAttribute &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          baseValue == other.baseValue &&
          type == other.type;

  @override
  int get hashCode => Object.hash(name, baseValue, type);

  @override
  String toString() => 'SvgAttribute($name: $baseValue, type: $type)';
}

/// Mutable attribute with support for an animated value
/// (does not extend @immutable SvgAttribute to allow state mutation)
class AnimatableSvgAttribute {
  /// Creates an animatable attribute
  AnimatableSvgAttribute({
    required this.name,
    required this.baseValue,
    this.type = SvgAttributeType.string,
  });

  /// Attribute name
  final String name;

  /// Base value
  final Object baseValue;

  /// Attribute type
  final SvgAttributeType type;

  /// Current animated value (if animation is active)
  Object? _animatedValue;

  /// Flag: whether an animation is currently active
  bool _isAnimated = false;

  /// Get the effective value
  /// (animatedValue if animation is active, otherwise baseValue)
  Object get effectiveValue => _isAnimated ? _animatedValue! : baseValue;

  /// Set the animated value
  void setAnimatedValue(Object? value) {
    _animatedValue = value;
    _isAnimated = value != null;
  }

  /// Reset the animation (return to baseValue)
  void clearAnimation() {
    _animatedValue = null;
    _isAnimated = false;
  }

  /// Whether the animation is active
  bool get isAnimated => _isAnimated;

  @override
  String toString() =>
      'AnimatableSvgAttribute($name: ${_isAnimated ? _animatedValue : baseValue}, animated: $_isAnimated)';
}

/// A node in the SVG DOM tree
class SvgNode {
  /// Creates an SVG node
  SvgNode({
    required this.tagName,
    this.id,
    this.className,
    Map<String, AnimatableSvgAttribute>? attributes,
    List<SvgNode>? children,
    this.parent,
  }) : attributes = attributes ?? {},
       children = children ?? [],
       _rawAttributes = {};

  // === Accessibility Properties ===

  /// Title text from child `<title>` element (for tooltips/accessibility).
  String? titleText;

  /// Description text from child `<desc>` element (for accessibility).
  String? descText;

  /// ARIA label attribute value (aria-label).
  String? ariaLabel;

  /// ARIA describedby attribute value (aria-describedby).
  String? ariaDescribedby;

  /// ARIA role attribute value (role).
  String? ariaRole;

  // === Core Properties ===

  /// Element tag: 'svg', 'g', 'rect', 'circle', 'path', 'text', etc.
  final String tagName;

  /// Element ID (id attribute)
  final String? id;

  /// Element class (class attribute) — mutable so JS can update it.
  String? className;

  /// Element attributes
  final Map<String, AnimatableSvgAttribute> attributes;

  /// Raw attribute values for CSS selector matching
  final Map<String, String> _rawAttributes;

  /// Child elements
  final List<SvgNode> children;

  /// Parent node
  SvgNode? parent;

  /// Flag: whether there are animations in this node or its subtree
  /// (used for rendering optimization)
  bool hasAnimations = false;

  /// Cached Picture for static subtrees
  /// (used only when hasAnimations == false)
  ui.Picture? cachedPicture;

  /// Add a child element
  void addChild(SvgNode child) {
    children.add(child);
    child.parent = this;

    // If the child has animations, mark all ancestors
    if (child.hasAnimations) {
      _markHasAnimations();
    }
  }

  /// Mark this node and all ancestors as having animations
  void _markHasAnimations() {
    if (!hasAnimations) {
      hasAnimations = true;
      cachedPicture?.dispose();
      cachedPicture = null;
      parent?._markHasAnimations();
    }
  }

  /// Get an attribute by name
  AnimatableSvgAttribute? getAttribute(String name) => attributes[name];

  /// Get the effective attribute value (taking animation into account)
  /// Also supports the special fields 'id' and 'className'
  Object? getAttributeValue(String name) {
    // Special fields are stored separately, not in attributes
    if (name == 'id') return id;
    if (name == 'className' || name == 'class') return className;
    return attributes[name]?.effectiveValue;
  }

  /// Get raw (original string) attribute value for CSS selector matching
  String? getRawAttributeValue(String name) {
    if (name == 'id') return id;
    if (name == 'className' || name == 'class') return className;
    return _rawAttributes[name];
  }

  /// Set an attribute
  void setAttribute(
    String name,
    Object value, {
    SvgAttributeType type = SvgAttributeType.string,
    String? rawValue,
  }) {
    attributes[name] = AnimatableSvgAttribute(
      name: name,
      baseValue: value,
      type: type,
    );
    // Store raw value if provided, otherwise use string representation
    _rawAttributes[name] =
        rawValue ?? (value is String ? value : value.toString());
  }

  /// Find a node by ID within the subtree
  SvgNode? findById(String searchId) {
    if (id == searchId) return this;

    for (final child in children) {
      final found = child.findById(searchId);
      if (found != null) return found;
    }

    return null;
  }

  /// Find all nodes with the given class within the subtree
  List<SvgNode> findByClass(String searchClass) {
    final result = <SvgNode>[];

    if (className?.split(' ').contains(searchClass) ?? false) {
      result.add(this);
    }

    for (final child in children) {
      result.addAll(child.findByClass(searchClass));
    }

    return result;
  }

  /// Find all nodes with the given tag within the subtree
  List<SvgNode> findByTag(String searchTag) {
    final result = <SvgNode>[];

    if (tagName == searchTag) {
      result.add(this);
    }

    for (final child in children) {
      result.addAll(child.findByTag(searchTag));
    }

    return result;
  }

  /// Release resources
  void dispose() {
    cachedPicture?.dispose();
    cachedPicture = null;

    for (final child in children) {
      child.dispose();
    }
  }

  @override
  String toString() =>
      'SvgNode($tagName${id != null ? '#$id' : ''}${className != null ? '.$className' : ''})';
}

/// Manages CSS pseudo-class state for SVG elements.
///
/// Tracks which elements are in :hover, :active, and :focus states.
class SvgPseudoClassState {
  /// Set of element IDs currently being hovered.
  final Set<String> _hoveredIds = {};

  /// Set of element IDs currently active (pressed).
  final Set<String> _activeIds = {};

  /// The ID of the currently focused element.
  String? _focusedId;

  /// The ID of the previously focused element (for blur events).
  String? _previousFocusedId;

  /// Callback for focus changes (oldId, newId).
  void Function(String? oldId, String? newId)? onFocusChange;

  /// Get set of hovered element IDs.
  Set<String> get hoveredIds => Set.unmodifiable(_hoveredIds);

  /// Get set of active element IDs.
  Set<String> get activeIds => Set.unmodifiable(_activeIds);

  /// Get the focused element ID.
  String? get focusedId => _focusedId;

  /// Get the previously focused element ID.
  String? get previousFocusedId => _previousFocusedId;

  /// Set hover state for an element.
  void setHovered(String id, bool isHovered) {
    if (isHovered) {
      _hoveredIds.add(id);
    } else {
      _hoveredIds.remove(id);
    }
  }

  /// Set active (pressed) state for an element.
  void setActive(String id, bool isActive) {
    if (isActive) {
      _activeIds.add(id);
    } else {
      _activeIds.remove(id);
    }
  }

  /// Set focus to an element (clears focus from any other).
  /// Returns true if focus actually changed.
  bool setFocus(String? id) {
    if (_focusedId == id) return false;

    _previousFocusedId = _focusedId;
    final oldId = _focusedId;
    _focusedId = id;

    // Notify about focus change
    onFocusChange?.call(oldId, id);

    return true;
  }

  /// Check if an element has hover state.
  bool isHovered(String id) => _hoveredIds.contains(id);

  /// Check if an element has active state.
  bool isActive(String id) => _activeIds.contains(id);

  /// Check if an element has focus state.
  bool isFocused(String id) => _focusedId == id;

  /// Clear all states.
  void clear() {
    _hoveredIds.clear();
    _activeIds.clear();
    _focusedId = null;
    _previousFocusedId = null;
  }

  /// Clear hover state from all elements.
  void clearHover() {
    _hoveredIds.clear();
  }

  /// Clear active state from all elements.
  void clearActive() {
    _activeIds.clear();
  }

  /// Clear focus state.
  void clearFocus() {
    if (_focusedId != null) {
      _previousFocusedId = _focusedId;
      final oldId = _focusedId;
      _focusedId = null;
      onFocusChange?.call(oldId, null);
    }
  }
}

/// Tags that are naturally focusable.
const Set<String> focusableTags = {'a', 'text', 'textPath', 'tspan'};

/// Check if an SVG element is focusable.
bool isFocusableElement(SvgNode node) {
  // Check if element has tabindex attribute
  final tabindex = node.getAttributeValue('tabindex');
  if (tabindex != null) {
    final parsed = int.tryParse(tabindex.toString());
    // tabindex >= 0 makes element focusable
    // tabindex = -1 makes element programmatically focusable but not via tab
    if (parsed != null && parsed >= -1) return true;
  }

  // Check if it's a naturally focusable tag
  if (focusableTags.contains(node.tagName)) return true;

  return false;
}

/// Represents an SVG `<view>` element.
///
/// A `<view>` element defines an alternate view of an SVG document,
/// with its own viewBox and preserveAspectRatio.
class SvgViewElement {
  const SvgViewElement({this.id, this.viewBox, this.preserveAspectRatio});

  /// ID of the view element (used in fragment identifiers).
  final String? id;

  /// The viewBox for this view.
  final ui.Rect? viewBox;

  /// The preserveAspectRatio for this view.
  final String? preserveAspectRatio;

  @override
  String toString() =>
      'SvgViewElement(id: $id, viewBox: $viewBox, preserveAspectRatio: $preserveAspectRatio)';
}

/// Root SVG document
class SvgDocument {
  /// Creates an SVG document
  SvgDocument({
    required this.root,
    this.viewBox,
    this.width,
    this.height,
    this.filters,
    this.cssKeyframes,
    this.cssSelectorRules,
    this.cssFontFaceRules,
    this.scripts,
  }) : _pseudoClassState = SvgPseudoClassState(),
       _views = {},
       _fontRegistry = SvgFontRegistry();

  /// Root `<svg>` node
  final SvgNode root;

  /// Document viewBox (if specified)
  final ui.Rect? viewBox;

  /// Document width
  final double? width;

  /// Document height
  final double? height;

  /// Collection of filters in the document
  final SvgFilters? filters;

  /// CSS @keyframes animations
  final List<CssKeyframes>? cssKeyframes;

  /// CSS selector rules (#id, .class)
  final List<CssSelectorRule>? cssSelectorRules;

  /// CSS @font-face rules for embedded fonts.
  final List<CssFontFaceRule>? cssFontFaceRules;

  /// Inline JS scripts extracted from <script> elements.
  final List<String>? scripts;

  /// Pseudo-class state manager for CSS :hover, :active, :focus
  final SvgPseudoClassState _pseudoClassState;

  /// Font registry for managing embedded fonts.
  final SvgFontRegistry _fontRegistry;

  /// Parsed `<view>` elements by ID
  final Map<String, SvgViewElement> _views;

  /// Current active view ID (from fragment identifier or programmatic switch)
  String? _activeViewId;

  /// Get the current pseudo-class state manager.
  SvgPseudoClassState get pseudoClassState => _pseudoClassState;

  /// Get the currently active viewBox (considering active view)
  ui.Rect? get activeViewBox {
    if (_activeViewId != null) {
      final view = _views[_activeViewId];
      if (view != null) {
        return view.viewBox;
      }
    }
    return viewBox;
  }

  /// Get the currently active preserveAspectRatio (considering active view)
  String? get activePreserveAspectRatio {
    if (_activeViewId != null) {
      final view = _views[_activeViewId];
      if (view != null) {
        return view.preserveAspectRatio;
      }
    }
    return root.getAttributeValue('preserveAspectRatio')?.toString();
  }

  /// Register a `<view>` element
  void registerView(SvgViewElement view) {
    if (view.id != null) {
      _views[view.id!] = view;
    }
  }

  /// Get a view by ID
  SvgViewElement? getView(String id) => _views[id];

  /// Get all registered view IDs
  Iterable<String> get viewIds => _views.keys;

  /// Switch to a specific view by ID
  /// Returns true if the view was found and activated.
  bool switchToView(String? viewId) {
    if (viewId == null) {
      _activeViewId = null;
      return true;
    }
    if (_views.containsKey(viewId)) {
      _activeViewId = viewId;
      return true;
    }
    return false;
  }

  /// Get the currently active view ID
  String? get activeViewId => _activeViewId;

  // === Accessibility Properties ===

  /// The accessible name for the entire SVG widget.
  /// Returns aria-label if present, otherwise the root `<title>` text.
  String? get accessibleName => root.ariaLabel ?? root.titleText;

  /// The accessible description for the entire SVG widget.
  /// Returns aria-describedby if present, otherwise the root `<desc>` text.
  String? get accessibleDescription => root.ariaDescribedby ?? root.descText;

  /// The ARIA role for the SVG widget.
  /// Defaults to 'img' if not specified (per SVG accessibility guidelines).
  String get accessibleRole => root.ariaRole ?? 'img';

  /// Find a node by ID in the entire document
  SvgNode? getElementById(String id) => root.findById(id);

  /// Find nodes by class
  List<SvgNode> getElementsByClass(String className) =>
      root.findByClass(className);

  /// Find nodes by tag
  List<SvgNode> getElementsByTag(String tagName) => root.findByTag(tagName);

  // === Font Registration ===

  /// Get the font registry for this document.
  SvgFontRegistry get fontRegistry => _fontRegistry;

  /// Check if a font family name is registered.
  bool isFontRegistered(String fontFamily) =>
      _fontRegistry.isRegistered(fontFamily);

  /// Get the set of registered font family names.
  Set<String> get registeredFontFamilies =>
      _fontRegistry.registeredFontFamilies;

  /// Registers all embedded @font-face fonts from the SVG document.
  ///
  /// This should be called once before rendering the SVG to ensure
  /// embedded fonts are available. The method is async because font
  /// loading with Flutter's FontLoader requires awaiting the load.
  ///
  /// [fontLoader] is an optional callback for resolving external font URLs.
  ///
  /// Returns true if fonts were registered successfully (or no fonts
  /// needed to be registered), false if there were errors.
  Future<bool> registerEmbeddedFonts({SvgFontLoader? fontLoader}) async {
    if (cssFontFaceRules == null || cssFontFaceRules!.isEmpty) {
      return true;
    }

    await _fontRegistry.registerFonts(
      cssFontFaceRules!,
      fontLoader: fontLoader,
    );
    return _fontRegistry.errors.isEmpty;
  }

  /// Get any errors that occurred during font registration.
  List<String> get fontRegistrationErrors => _fontRegistry.errors;

  /// Release resources
  void dispose() {
    root.dispose();
  }

  @override
  String toString() =>
      'SvgDocument(${viewBox != null ? 'viewBox: $viewBox, ' : ''}${width != null ? 'width: $width, ' : ''}${height != null ? 'height: $height' : ''})';
}
