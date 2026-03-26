import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'css_animations.dart';
import 'svg_filters.dart';

/// Тип атрибута SVG элемента для корректной интерполяции
enum SvgAttributeType {
  /// Числовое значение: x, y, width, height, opacity, stroke-width
  number,

  /// Длина с единицами измерения: px, em, %, pt, etc.
  length,

  /// Цвет: fill, stroke, stop-color
  color,

  /// Трансформация: transform attribute
  transform,

  /// Path данные: d attribute для <path>
  path,

  /// Списки точек: points для <polygon>, <polyline>
  points,

  /// Строковое значение (для discrete анимаций)
  string,

  /// Списковое значение: stroke-dasharray и подобные
  list,

  /// URL ссылка: для gradients, masks, filters
  url,
}

/// Атрибут SVG элемента, который может быть анимирован
/// Базовый immutable класс для константных значений
@immutable
class SvgAttribute {
  /// Создаёт атрибут с базовым значением
  const SvgAttribute({
    required this.name,
    required this.baseValue,
    this.type = SvgAttributeType.string,
  });

  /// Имя атрибута (например, 'x', 'y', 'fill', 'transform')
  final String name;

  /// Базовое значение из XML/CSS
  final Object baseValue;

  /// Тип атрибута (для правильной интерполяции)
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

/// Mutable атрибут с поддержкой анимированного значения
/// (не наследуется от @immutable SvgAttribute для возможности изменения состояния)
class AnimatableSvgAttribute {
  /// Создаёт анимируемый атрибут
  AnimatableSvgAttribute({
    required this.name,
    required this.baseValue,
    this.type = SvgAttributeType.string,
  });

  /// Имя атрибута
  final String name;

  /// Базовое значение
  final Object baseValue;

  /// Тип атрибута
  final SvgAttributeType type;

  /// Текущее анимированное значение (если анимация активна)
  Object? _animatedValue;

  /// Флаг: активна ли анимация в данный момент
  bool _isAnimated = false;

  /// Получить эффективное значение
  /// (animatedValue если анимация активна, иначе baseValue)
  Object get effectiveValue => _isAnimated ? _animatedValue! : baseValue;

  /// Установить анимированное значение
  void setAnimatedValue(Object? value) {
    _animatedValue = value;
    _isAnimated = value != null;
  }

  /// Сбросить анимацию (вернуться к baseValue)
  void clearAnimation() {
    _animatedValue = null;
    _isAnimated = false;
  }

  /// Активна ли анимация
  bool get isAnimated => _isAnimated;

  @override
  String toString() =>
      'AnimatableSvgAttribute($name: ${_isAnimated ? _animatedValue : baseValue}, animated: $_isAnimated)';
}

/// Узел SVG DOM дерева
class SvgNode {
  /// Создаёт SVG узел
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

  /// Title text from child <title> element (for tooltips/accessibility).
  String? titleText;

  /// Description text from child <desc> element (for accessibility).
  String? descText;

  /// ARIA label attribute value (aria-label).
  String? ariaLabel;

  /// ARIA describedby attribute value (aria-describedby).
  String? ariaDescribedby;

  /// ARIA role attribute value (role).
  String? ariaRole;

  // === Core Properties ===

  /// Тег элемента: 'svg', 'g', 'rect', 'circle', 'path', 'text', etc.
  final String tagName;

  /// ID элемента (атрибут id)
  final String? id;

  /// Класс элемента (атрибут class)
  final String? className;

  /// Атрибуты элемента
  final Map<String, AnimatableSvgAttribute> attributes;

  /// Raw attribute values for CSS selector matching
  final Map<String, String> _rawAttributes;

  /// Дочерние элементы
  final List<SvgNode> children;

  /// Родительский узел
  SvgNode? parent;

  /// Флаг: есть ли анимации в этом узле или его поддереве
  /// (для оптимизации рендеринга)
  bool hasAnimations = false;

  /// Кэшированный Picture для статичных поддеревьев
  /// (используется только если hasAnimations == false)
  ui.Picture? cachedPicture;

  /// Добавить дочерний элемент
  void addChild(SvgNode child) {
    children.add(child);
    child.parent = this;

    // Если у ребёнка есть анимации, пометить всех родителей
    if (child.hasAnimations) {
      _markHasAnimations();
    }
  }

  /// Пометить этот узел и всех родителей как имеющие анимации
  void _markHasAnimations() {
    if (!hasAnimations) {
      hasAnimations = true;
      cachedPicture?.dispose();
      cachedPicture = null;
      parent?._markHasAnimations();
    }
  }

  /// Получить атрибут по имени
  AnimatableSvgAttribute? getAttribute(String name) => attributes[name];

  /// Получить эффективное значение атрибута (с учётом анимации)
  /// Также поддерживает специальные поля 'id' и 'className'
  Object? getAttributeValue(String name) {
    // Специальные поля хранятся отдельно, не в attributes
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

  /// Установить атрибут
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

  /// Найти узел по ID в поддереве
  SvgNode? findById(String searchId) {
    if (id == searchId) return this;

    for (final child in children) {
      final found = child.findById(searchId);
      if (found != null) return found;
    }

    return null;
  }

  /// Найти все узлы с указанным классом в поддереве
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

  /// Найти все узлы с указанным тегом в поддереве
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

  /// Освободить ресурсы
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

/// Represents an SVG <view> element.
///
/// A <view> element defines an alternate view of an SVG document,
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

/// Корневой документ SVG
class SvgDocument {
  /// Создаёт SVG документ
  SvgDocument({
    required this.root,
    this.viewBox,
    this.width,
    this.height,
    this.filters,
    this.cssKeyframes,
    this.cssSelectorRules,
  }) : _pseudoClassState = SvgPseudoClassState(),
       _views = {};

  /// Корневой <svg> узел
  final SvgNode root;

  /// ViewBox документа (если указан)
  final ui.Rect? viewBox;

  /// Ширина документа
  final double? width;

  /// Высота документа
  final double? height;

  /// Коллекция фильтров в документе
  final SvgFilters? filters;

  /// CSS @keyframes анимации
  final List<CssKeyframes>? cssKeyframes;

  /// CSS selector rules (#id, .class)
  final List<CssSelectorRule>? cssSelectorRules;

  /// Pseudo-class state manager for CSS :hover, :active, :focus
  final SvgPseudoClassState _pseudoClassState;

  /// Parsed <view> elements by ID
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

  /// Register a <view> element
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
  /// Returns aria-label if present, otherwise the root <title> text.
  String? get accessibleName => root.ariaLabel ?? root.titleText;

  /// The accessible description for the entire SVG widget.
  /// Returns aria-describedby if present, otherwise the root <desc> text.
  String? get accessibleDescription => root.ariaDescribedby ?? root.descText;

  /// The ARIA role for the SVG widget.
  /// Defaults to 'img' if not specified (per SVG accessibility guidelines).
  String get accessibleRole => root.ariaRole ?? 'img';

  /// Найти узел по ID во всём документе
  SvgNode? getElementById(String id) => root.findById(id);

  /// Найти узлы по классу
  List<SvgNode> getElementsByClass(String className) =>
      root.findByClass(className);

  /// Найти узлы по тегу
  List<SvgNode> getElementsByTag(String tagName) => root.findByTag(tagName);

  /// Освободить ресурсы
  void dispose() {
    root.dispose();
  }

  @override
  String toString() =>
      'SvgDocument(${viewBox != null ? 'viewBox: $viewBox, ' : ''}${width != null ? 'width: $width, ' : ''}${height != null ? 'height: $height' : ''})';
}
