import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

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
       children = children ?? [];

  /// Тег элемента: 'svg', 'g', 'rect', 'circle', 'path', 'text', etc.
  final String tagName;

  /// ID элемента (атрибут id)
  final String? id;

  /// Класс элемента (атрибут class)
  final String? className;

  /// Атрибуты элемента
  final Map<String, AnimatableSvgAttribute> attributes;

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

  /// Установить атрибут
  void setAttribute(
    String name,
    Object value, {
    SvgAttributeType type = SvgAttributeType.string,
  }) {
    attributes[name] = AnimatableSvgAttribute(
      name: name,
      baseValue: value,
      type: type,
    );
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

/// Корневой документ SVG
class SvgDocument {
  /// Создаёт SVG документ
  SvgDocument({required this.root, this.viewBox, this.width, this.height});

  /// Корневой <svg> узел
  final SvgNode root;

  /// ViewBox документа (если указан)
  final ui.Rect? viewBox;

  /// Ширина документа
  final double? width;

  /// Высота документа
  final double? height;

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
