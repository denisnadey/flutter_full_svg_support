import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animated_svg_controller.dart';
import 'animated_svg_painter.dart';
import 'animation_detector.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'switch_processing.dart';
import 'smil/smil_parser.dart';
import 'smil/smil_timeline.dart';
import 'svg_dom.dart';
import 'svg_parser.dart';
import 'svg_transform.dart';

/// Severity level for runtime SVG trace events.
enum SvgTraceLevel {
  /// Verbose runtime details.
  debug,

  /// Normal operational events.
  info,

  /// Recoverable problems.
  warning,

  /// Hard failures.
  error,
}

/// Structured trace event emitted by [AnimatedSvgPicture].
@immutable
class SvgTraceEvent {
  /// Creates a trace event.
  const SvgTraceEvent({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data = const <String, Object?>{},
    this.error,
    this.stackTrace,
  });

  /// Event timestamp in local time.
  final DateTime timestamp;

  /// Event severity.
  final SvgTraceLevel level;

  /// High-level subsystem label (e.g. "init", "event", "tick").
  final String category;

  /// Human readable message.
  final String message;

  /// Optional structured payload.
  final Map<String, Object?> data;

  /// Optional attached exception.
  final Object? error;

  /// Optional stack trace for errors.
  final StackTrace? stackTrace;
}

/// Callback used for receiving [SvgTraceEvent] updates.
typedef SvgTraceCallback = void Function(SvgTraceEvent event);

/// Виджет для отображения анимированного SVG
///
/// API схож с SvgPicture, но поддерживает SMIL анимации.
/// Автоматически определяет наличие анимаций и создаёт AnimationController.
///
/// Пример:
/// ```dart
/// AnimatedSvgPicture.string(
///   '''<svg viewBox="0 0 100 100">
///     <rect x="0" y="0" width="20" height="20">
///       <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
///     </rect>
///   </svg>''',
///   width: 200,
///   height: 200,
/// )
/// ```
class AnimatedSvgPicture extends StatefulWidget {
  /// Создаёт анимированный SVG из строки
  const AnimatedSvgPicture.string(
    String svgString, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
    this.controller,
    this.onTrace,
    this.traceFrameTicks = false,
  }) : _svgString = svgString;

  /// XML строка SVG
  final String _svgString;

  /// Ширина виджета
  final double? width;

  /// Высота виджета
  final double? height;

  /// Как вписать SVG в размеры виджета
  final BoxFit fit;

  /// Выравнивание SVG внутри виджета
  final Alignment alignment;

  /// Фоновый цвет
  final Color? backgroundColor;

  /// Скорость воспроизведения (1.0 = нормальная, 2.0 = x2)
  final double playbackRate;

  /// Автоматически начинать воспроизведение
  final bool autoPlay;

  /// Начальное время анимации (для тестирования или предварительного просмотра)
  final Duration? initialTime;

  /// Контроллер для программного управления анимацией
  final AnimatedSvgController? controller;

  /// Optional callback for runtime diagnostics and tracing.
  final SvgTraceCallback? onTrace;

  /// Emit per-frame tick trace events. Disabled by default due to volume.
  final bool traceFrameTicks;

  @override
  State<AnimatedSvgPicture> createState() => _AnimatedSvgPictureState();
}

class _AnimatedSvgPictureState extends State<AnimatedSvgPicture>
    with TickerProviderStateMixin {
  late SvgDocument _document;
  SvgTimeline? _timeline;
  AnimationController? _controller;
  bool _hasAnimations = false;
  bool _isReversed = false;
  String? _hoveredElementId;
  final Map<String, ui.Image> _imagesByHref = <String, ui.Image>{};
  final Set<String> _pendingImageHrefs = <String>{};
  int _imageLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
    // Подписываемся на изменения контроллера
    widget.controller?.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(AnimatedSvgPicture oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Обновляем подписку на контроллер
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }

    if (widget._svgString != oldWidget._svgString) {
      // SVG изменился - полная переинициализация
      _dispose();
      _initialize();
    } else if (widget.playbackRate != oldWidget.playbackRate &&
        _timeline != null) {
      // Только скорость изменилась
      _timeline!.playbackRate = widget.playbackRate;
    } else if (widget.autoPlay != oldWidget.autoPlay) {
      // AutoPlay изменился
      if (widget.autoPlay && _controller == null && _timeline != null) {
        // Нужно создать контроллер
        final duration = _timeline!.totalDuration;
        _controller = AnimationController(vsync: this, duration: duration);
        _controller!.addListener(_onAnimationTick);
        _isReversed = widget.controller?.isReversed ?? _isReversed;
        _startPlayback();
      } else if (!widget.autoPlay && _controller != null) {
        // Нужно удалить контроллер
        _controller?.removeListener(_onAnimationTick);
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _initialize() {
    _trace(
      category: 'init',
      message: 'Initializing AnimatedSvgPicture',
      data: <String, Object?>{
        'sourceLength': widget._svgString.length,
        'autoPlay': widget.autoPlay,
        'playbackRate': widget.playbackRate,
        'initialTimeMs': widget.initialTime?.inMilliseconds,
      },
    );

    _imageLoadGeneration++;
    _disposeResolvedImages();

    try {
      // Проверяем наличие анимаций
      _hasAnimations = AnimationDetector.hasAnimations(widget._svgString);

      // Парсим SVG
      _document = SvgParser.parse(widget._svgString);
      _trace(
        category: 'init',
        message: 'SVG parsed successfully',
        data: <String, Object?>{
          'hasAnimations': _hasAnimations,
          'rootTag': _document.root.tagName,
          'rootChildren': _document.root.children.length,
          'viewBox': _document.viewBox?.toString(),
        },
      );
      _scheduleImagePreload();

      if (_hasAnimations) {
        // Парсим анимации
        final animations = SmilParser.parseAnimations(_document);
        _trace(
          category: 'init',
          message: 'Animation scan completed',
          data: <String, Object?>{'animationCount': animations.length},
        );

        if (animations.isNotEmpty) {
          // Создаём timeline
          _timeline = SvgTimeline(
            animations: animations,
            rootNode: _document.root,
          );
          _timeline!.playbackRate = widget.playbackRate;

          // Инициализируем начальное состояние анимаций (t=0 или initialTime)
          final startTime = widget.initialTime ?? Duration.zero;
          _timeline!.seek(startTime);
          _trace(
            category: 'timeline',
            message: 'Timeline initialized',
            data: <String, Object?>{
              'startTimeMs': startTime.inMilliseconds,
              'totalDurationMs': _timeline!.totalDuration.inMilliseconds,
              'activeAnimations': _timeline!.getActiveAnimations().length,
            },
          );

          // Перерисовываем первый кадр (важно для autoPlay: false)
          if (mounted) {
            setState(() {});
          }

          // Создаём AnimationController только если autoPlay
          if (widget.autoPlay) {
            final duration = _timeline!.totalDuration;

            _controller = AnimationController(vsync: this, duration: duration);
            _isReversed = widget.controller?.isReversed ?? false;

            // Устанавливаем начальное значение контроллера если задано initialTime
            if (widget.initialTime != null && duration.inMicroseconds > 0) {
              final progress =
                  widget.initialTime!.inMicroseconds / duration.inMicroseconds;
              _controller!.value = progress.clamp(0.0, 1.0);
            }

            // Слушаем обновления контроллера
            _controller!.addListener(_onAnimationTick);
            _trace(
              category: 'controller',
              message: 'Animation controller created',
              data: <String, Object?>{
                'durationMs': duration.inMilliseconds,
                'initialValue': _controller!.value,
                'isReversed': _isReversed,
              },
            );
            _startPlayback();
          } else {
            _trace(
              category: 'controller',
              message: 'Auto play disabled, controller not started',
            );
          }
        } else {
          _hasAnimations = false;
          _trace(
            category: 'init',
            level: SvgTraceLevel.warning,
            message: 'Animation markers found, but no parseable animations',
          );
        }
      } else {
        _trace(
          category: 'init',
          message: 'Static SVG detected (no animation tags)',
        );
      }
    } catch (error, stackTrace) {
      _trace(
        category: 'init',
        level: SvgTraceLevel.error,
        message: 'Failed to initialize AnimatedSvgPicture',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _hasInfiniteAnimations() {
    return _timeline?.animations.any((anim) => anim.repeatCount.isInfinite) ??
        false;
  }

  void _startPlayback() {
    if (_controller == null) return;

    if (_hasInfiniteAnimations()) {
      _controller!.stop();
      if (_isReversed && _controller!.value <= _controller!.lowerBound) {
        _controller!.value = _controller!.upperBound;
      } else if (!_isReversed &&
          _controller!.value >= _controller!.upperBound) {
        _controller!.value = _controller!.lowerBound;
      }
      _controller!.repeat(reverse: _isReversed);
      _trace(
        category: 'controller',
        message: 'Playback started in repeat mode',
        data: <String, Object?>{
          'reversed': _isReversed,
          'infinite': true,
          'value': _controller!.value,
        },
      );
      return;
    }

    if (_isReversed) {
      _controller!.reverse(from: _controller!.value);
      _trace(
        category: 'controller',
        message: 'Playback started in reverse mode',
        data: <String, Object?>{'value': _controller!.value},
      );
    } else {
      _controller!.forward(from: _controller!.value);
      _trace(
        category: 'controller',
        message: 'Playback started in forward mode',
        data: <String, Object?>{'value': _controller!.value},
      );
    }
  }

  void _onAnimationTick() {
    if (_controller == null || _timeline == null) return;

    // Конвертируем progress контроллера в время
    final elapsed = _controller!.duration! * _controller!.value;

    // Обновляем timeline
    _timeline!.seek(elapsed);

    if (widget.traceFrameTicks) {
      _trace(
        category: 'tick',
        level: SvgTraceLevel.debug,
        message: 'Frame tick',
        data: <String, Object?>{
          'controllerValue': _controller!.value,
          'elapsedMs': elapsed.inMilliseconds,
          'activeAnimations': _timeline!.getActiveAnimations().length,
        },
      );
    }

    // Перерисовываем
    setState(() {});
  }

  void _onControllerUpdate() {
    if (_timeline == null) return;

    final controller = widget.controller;
    if (controller == null) return;

    // Обработка reverse/forward
    if (_isReversed != controller.isReversed) {
      _isReversed = controller.isReversed;
      _trace(
        category: 'controller',
        message: 'Direction changed',
        data: <String, Object?>{'isReversed': _isReversed},
      );
      if (!controller.isPaused && _controller != null) {
        _startPlayback();
      }
    }

    // Обработка pause/resume
    if (controller.isPaused) {
      _controller?.stop();
      _trace(category: 'controller', message: 'Paused by external controller');
    } else if (_controller != null && !_controller!.isAnimating) {
      _trace(category: 'controller', message: 'Resumed by external controller');
      _startPlayback();
    }

    // Обработка playbackRate
    if (controller.playbackRate != _timeline!.playbackRate) {
      _timeline!.playbackRate = controller.playbackRate;
      _trace(
        category: 'controller',
        message: 'Playback rate updated',
        data: <String, Object?>{'playbackRate': controller.playbackRate},
      );
    }

    // Обработка seek
    if (controller.pendingSeek != null) {
      final targetTime = controller.pendingSeek!;
      _timeline!.seek(targetTime);

      // Обновляем значение контроллера для синхронизации
      if (_controller != null) {
        final duration = _controller!.duration!;
        if (duration.inMicroseconds > 0) {
          final progress = targetTime.inMicroseconds / duration.inMicroseconds;
          _controller!.value = progress.clamp(0.0, 1.0);
        }
      }

      controller.clearPendingSeek();
      _trace(
        category: 'controller',
        message: 'Seek applied',
        data: <String, Object?>{'targetTimeMs': targetTime.inMilliseconds},
      );
      setState(() {});
    }
  }

  void _scheduleImagePreload() {
    final hrefs = <String>{};
    _collectImageHrefs(_document.root, hrefs);
    if (hrefs.isEmpty) {
      return;
    }

    final generation = _imageLoadGeneration;
    _pendingImageHrefs
      ..clear()
      ..addAll(hrefs);

    _trace(
      category: 'image',
      message: 'Image preload scheduled',
      data: <String, Object?>{'count': hrefs.length},
    );

    for (final href in hrefs) {
      unawaited(_resolveImageByHref(href, generation));
    }
  }

  void _collectImageHrefs(SvgNode node, Set<String> hrefs) {
    if (node.tagName == 'image') {
      final href = _extractImageHref(node);
      if (href != null) {
        hrefs.add(href);
      }
    }
    for (final child in node.children) {
      _collectImageHrefs(child, hrefs);
    }
  }

  String? _extractImageHref(SvgNode node) {
    final raw =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (raw == null) {
      return null;
    }
    final href = raw.toString().trim();
    return href.isEmpty ? null : href;
  }

  Future<void> _resolveImageByHref(String href, int generation) async {
    try {
      final bytes = await _loadImageBytes(href);
      if (bytes == null || bytes.isEmpty) {
        _trace(
          category: 'image',
          level: SvgTraceLevel.warning,
          message: 'Image source is not supported or failed to load',
          data: <String, Object?>{'href': href},
        );
        return;
      }

      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        if (!mounted || generation != _imageLoadGeneration) {
          image.dispose();
          return;
        }

        final previous = _imagesByHref[href];
        if (!identical(previous, image)) {
          previous?.dispose();
        }
        _imagesByHref[href] = image;

        _trace(
          category: 'image',
          message: 'Image decoded',
          data: <String, Object?>{
            'href': href,
            'width': image.width,
            'height': image.height,
          },
        );

        setState(() {});
      } finally {
        codec.dispose();
      }
    } catch (error, stackTrace) {
      _trace(
        category: 'image',
        level: SvgTraceLevel.warning,
        message: 'Failed to decode image source',
        data: <String, Object?>{'href': href},
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (generation == _imageLoadGeneration) {
        _pendingImageHrefs.remove(href);
      }
    }
  }

  Future<Uint8List?> _loadImageBytes(String href) async {
    if (href.startsWith('data:')) {
      return _decodeDataUriBytes(href);
    }

    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final data = await NetworkAssetBundle(uri).load(uri.toString());
      return data.buffer.asUint8List();
    }

    final data = await rootBundle.load(href);
    return data.buffer.asUint8List();
  }

  Uint8List? _decodeDataUriBytes(String href) {
    final commaIndex = href.indexOf(',');
    if (commaIndex <= 5) {
      return null;
    }

    final metadata = href.substring(5, commaIndex).toLowerCase();
    final payload = href.substring(commaIndex + 1);

    try {
      if (metadata.contains(';base64')) {
        return Uint8List.fromList(base64.decode(payload));
      }
      final decoded = Uri.decodeComponent(payload);
      return Uint8List.fromList(decoded.codeUnits);
    } catch (_) {
      return null;
    }
  }

  void _disposeResolvedImages() {
    for (final image in _imagesByHref.values) {
      image.dispose();
    }
    _imagesByHref.clear();
    _pendingImageHrefs.clear();
  }

  void _dispose() {
    _trace(category: 'lifecycle', message: 'Disposing AnimatedSvgPicture');
    _imageLoadGeneration++;
    _disposeResolvedImages();
    widget.controller?.removeListener(_onControllerUpdate);
    _controller?.removeListener(_onAnimationTick);
    _controller?.dispose();
    _controller = null;
    _timeline = null;
    _hoveredElementId = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget svgWidget = CustomPaint(
      painter: AnimatedSvgPainter(
        document: _document,
        backgroundColor: widget.backgroundColor,
        imagesByHref: _imagesByHref,
      ),
      size: Size.infinite,
    );

    // Wrap with gesture detection for event-based animations
    if (_hasAnimations && _timeline != null) {
      svgWidget = GestureDetector(
        onTapDown: (details) => _handleTapDown(details),
        child: MouseRegion(
          onEnter: (event) => _handleMouseEnter(event.localPosition),
          onExit: (_) => _handleMouseExit(),
          onHover: (event) => _handleMouseHover(event.localPosition),
          child: svgWidget,
        ),
      );
    }

    // Оборачиваем в SizedBox если указаны размеры
    if (widget.width != null || widget.height != null) {
      svgWidget = SizedBox(
        width: widget.width,
        height: widget.height,
        child: svgWidget,
      );
    }

    return svgWidget;
  }

  /// Обработать клик с координатами (может триггерить клик на элемент)
  void _handleTapDown(TapDownDetails details) {
    final targetId = _hitTestElementId(details.localPosition);
    _trace(
      category: 'event',
      message: 'Tap detected',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': targetId,
      },
    );
    if (targetId != null) {
      _timeline?.triggerEvent(targetId, 'click');
    }
    // Поддерживаем document-level click как fallback/всплытие
    _timeline?.triggerEvent(null, 'click');
    setState(() {});
  }

  /// Обработать вход мыши в область SVG
  void _handleMouseEnter(Offset position) {
    _timeline?.triggerEvent(null, 'mouseover');
    _trace(
      category: 'event',
      message: 'Mouse entered widget bounds',
      data: <String, Object?>{'x': position.dx, 'y': position.dy},
    );
    _updateHoveredElement(position);
  }

  /// Обработать выход мыши из области SVG
  void _handleMouseExit() {
    if (_hoveredElementId != null) {
      _timeline?.triggerEvent(_hoveredElementId, 'mouseout');
      _trace(
        category: 'event',
        message: 'Mouse out from hovered element',
        data: <String, Object?>{'targetId': _hoveredElementId},
      );
      _hoveredElementId = null;
    }
    _timeline?.triggerEvent(null, 'mouseout');
    _trace(category: 'event', message: 'Mouse exited widget bounds');
    setState(() {});
  }

  /// Обработать движение мыши над SVG
  void _handleMouseHover(Offset position) {
    _updateHoveredElement(position);
  }

  void _updateHoveredElement(Offset position) {
    final hitElementId = _hitTestElementId(position);
    if (hitElementId == _hoveredElementId) {
      return;
    }

    if (_hoveredElementId != null) {
      _timeline?.triggerEvent(_hoveredElementId, 'mouseout');
    }
    if (hitElementId != null) {
      _timeline?.triggerEvent(hitElementId, 'mouseover');
    }

    _hoveredElementId = hitElementId;
    _trace(
      category: 'event',
      level: SvgTraceLevel.debug,
      message: 'Hovered element changed',
      data: <String, Object?>{
        'targetId': _hoveredElementId,
        'x': position.dx,
        'y': position.dy,
      },
    );
    setState(() {});
  }

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
        tagName == 'filter';
  }

  bool _isPointVisibleForNode(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final localPoint = MatrixUtils.transformPoint(inverse, documentPoint);
    return _isPointVisibleInNodeSpace(node, localPoint);
  }

  bool _isPointVisibleInNodeSpace(SvgNode node, Offset localPoint) {
    if (!_isPointInsideClipPath(node, localPoint)) {
      return false;
    }
    if (!_isPointInsideMask(node, localPoint)) {
      return false;
    }
    if (!_isPointInsideForeignObjectViewport(node, localPoint)) {
      return false;
    }
    return true;
  }

  bool _isPointInsideClipPath(SvgNode node, Offset localPoint) {
    final clipValue = _extractStyleValue(node, 'clip-path');
    final clipId = _extractUrlId(clipValue ?? node.getAttributeValue('clip-path'));
    if (clipId == null || clipId.isEmpty) {
      return true;
    }
    final clipNode = _document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return true;
    }
    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: clipNode.getAttributeValue('clipPathUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }
    final clipPath = _buildContainerGeometryPath(
      clipNode,
      rootTransform: rootTransform,
    );
    if (clipPath == null) {
      return true;
    }
    return clipPath.contains(localPoint);
  }

  bool _isPointInsideMask(SvgNode node, Offset localPoint) {
    final maskValue = _extractStyleValue(node, 'mask');
    final maskId = _extractUrlId(maskValue ?? node.getAttributeValue('mask'));
    if (maskId == null || maskId.isEmpty) {
      return true;
    }
    final maskNode = _document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return true;
    }
    final maskRegion = _resolveMaskRegionRectForNodeSpace(
      targetNode: node,
      maskNode: maskNode,
    );
    if (maskRegion != null && !maskRegion.contains(localPoint)) {
      return false;
    }
    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: maskNode.getAttributeValue('maskContentUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }
    final maskPath = _buildContainerGeometryPath(
      maskNode,
      rootTransform: rootTransform,
    );
    if (maskPath == null) {
      return true;
    }
    return maskPath.contains(localPoint);
  }

  Matrix4? _resolveContainerRootTransformForUnits({
    required SvgNode targetNode,
    required String? unitsValue,
    required String defaultValue,
  }) {
    final normalized = (unitsValue ?? defaultValue).trim().toLowerCase();
    if (normalized != 'objectboundingbox') {
      return Matrix4.identity();
    }
    final localBounds = _computeNodeLocalBounds(targetNode);
    if (localBounds == null ||
        localBounds.width.abs() < 1e-6 ||
        localBounds.height.abs() < 1e-6) {
      return null;
    }
    return Matrix4.identity()
      ..setEntry(0, 0, localBounds.width)
      ..setEntry(1, 1, localBounds.height)
      ..setEntry(0, 3, localBounds.left)
      ..setEntry(1, 3, localBounds.top);
  }

  Rect? _resolveMaskRegionRectForNodeSpace({
    required SvgNode targetNode,
    required SvgNode maskNode,
  }) {
    final units =
        (maskNode.getAttributeValue('maskUnits')?.toString() ??
                'objectBoundingBox')
            .trim()
            .toLowerCase();
    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBounds(targetNode);
      if (targetBounds == null) {
        return null;
      }
      final x = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('x'));
      final y = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('y'));
      final width = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('width'),
      );
      final height = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('height'),
      );
      final resolvedX = x ?? -0.1;
      final resolvedY = y ?? -0.1;
      final resolvedWidth = width ?? 1.2;
      final resolvedHeight = height ?? 1.2;
      if (resolvedWidth <= 0 || resolvedHeight <= 0) {
        return null;
      }
      return Rect.fromLTWH(
        targetBounds.left + resolvedX * targetBounds.width,
        targetBounds.top + resolvedY * targetBounds.height,
        targetBounds.width * resolvedWidth,
        targetBounds.height * resolvedHeight,
      );
    }

    final x = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'x',
      horizontal: true,
      isSize: false,
      defaultRaw: '-10%',
    );
    final y = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'y',
      horizontal: false,
      isSize: false,
      defaultRaw: '-10%',
    );
    final width = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'width',
      horizontal: true,
      isSize: true,
      defaultRaw: '120%',
    );
    final height = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'height',
      horizontal: false,
      isSize: true,
      defaultRaw: '120%',
    );
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(x, y, width, height);
  }

  double? _resolveMaskUserSpaceLength({
    required SvgNode maskNode,
    required String attributeName,
    required bool horizontal,
    required bool isSize,
    required String defaultRaw,
  }) {
    final rawValue = maskNode.getAttributeValue(attributeName) ?? defaultRaw;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      final viewport = _resolveMaskUnitsViewportRect();
      if (percent == null || viewport == null) {
        return null;
      }
      final dimension = horizontal ? viewport.width : viewport.height;
      final value = dimension * percent / 100.0;
      if (isSize) {
        return value;
      }
      final origin = horizontal ? viewport.left : viewport.top;
      return origin + value;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  Rect? _resolveMaskUnitsViewportRect() {
    final viewBox = _document.viewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final root = _document.root;
    final width = _getNumber(root, 'width');
    final height = _getNumber(root, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(0, 0, width, height);
  }

  double? _parseObjectBoundingBoxValue(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return null;
      }
      return percent / 100.0;
    }
    return double.tryParse(raw);
  }

  bool _isPointInsideForeignObjectViewport(SvgNode node, Offset localPoint) {
    if (node.tagName != 'foreignObject') {
      return true;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return false;
    }
    return Rect.fromLTWH(x, y, width, height).contains(localPoint);
  }

  String? _hitTestUseReference({
    required SvgNode useNode,
    required Offset documentPoint,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return null;
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return null;
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
            final hitChild = _hitTestNode(
              referenced.children[i],
              documentPoint,
              useReferenceTransform,
              useStack: nextUseStack,
            );
            if (hitChild != null) {
              return hitChild;
            }
          }
          return null;
        }
        return _hitTestNode(
          referenced,
          documentPoint,
          useReferenceTransform,
          useStack: nextUseStack,
        );
      }

      return _hitTestNode(
        referenced,
        documentPoint,
        referenceTransform,
        useStack: nextUseStack,
      );
    } finally {
      referenced.parent = previousParent;
    }
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

  String? _extractUrlId(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }
    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }

  bool _nodeContainsPoint(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final point = MatrixUtils.transformPoint(inverse, documentPoint);
    final pointerEvents = _resolvePointerEventsMode(node);
    final visibilityHidden = _isVisibilityHidden(node);

    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromLTWH(x, y, width, height).contains(point);
        }
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? rx;
        final rect = Rect.fromLTWH(x, y, width, height);
        final rectPath = Path();
        if (rx > 0 || ry > 0) {
          rectPath.addRRect(RRect.fromRectXY(rect, rx, ry));
        } else {
          rectPath.addRect(rect);
        }
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            rectPath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(rectPath, point, tolerance);
        }
        return false;
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromCircle(center: Offset(cx, cy), radius: r).contains(
            point,
          );
        }
        final circlePath = Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            circlePath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(circlePath, point, tolerance);
        }
        return false;
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ).contains(point);
        }
        final ellipsePath = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: rx * 2,
              height: ry * 2,
            ),
          );
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            ellipsePath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(ellipsePath, point, tolerance);
        }
        return false;
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        if (pointerEvents == 'bounding-box') {
          final bounds = Rect.fromLTRB(
            math.min(x1, x2),
            math.min(y1, y2),
            math.max(x1, x2),
            math.max(y1, y2),
          );
          // Degenerate line bounds are inflated by stroke tolerance so
          // vertical/horizontal lines remain hit-testable.
          final tolerance = _strokeTolerance(node);
          return bounds.inflate(tolerance).contains(point);
        }
        if (!_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          return false;
        }
        final tolerance = _strokeTolerance(node);
        final distance = _distanceToSegment(
          point,
          Offset(x1, y1),
          Offset(x2, y2),
        );
        return distance <= tolerance;
      case 'image':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 ||
            height <= 0 ||
            !_pointerEventsAllowsBoundingBox(
              pointerEvents,
              visibilityHidden: visibilityHidden,
            )) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'foreignObject':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 ||
            height <= 0 ||
            !_pointerEventsAllowsBoundingBox(
              pointerEvents,
              visibilityHidden: visibilityHidden,
            )) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'path':
        final path = _buildPathGeometry(node);
        if (path == null) {
          return false;
        }
        if (pointerEvents == 'bounding-box') {
          return path.getBounds().contains(point);
        }

        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            path.contains(point)) {
          return true;
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(path, point, tolerance);
        }
        return false;
      case 'polygon':
        final polygonPoints = _parsePoints(node);
        if (polygonPoints.length < 3) return false;

        final polygonPath = Path()
          ..moveTo(polygonPoints.first.dx, polygonPoints.first.dy);
        for (int i = 1; i < polygonPoints.length; i++) {
          polygonPath.lineTo(polygonPoints[i].dx, polygonPoints[i].dy);
        }
        polygonPath.close();
        if (pointerEvents == 'bounding-box') {
          return polygonPath.getBounds().contains(point);
        }

        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            polygonPath.contains(point)) {
          return true;
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          for (int i = 0; i < polygonPoints.length; i++) {
            final a = polygonPoints[i];
            final b = polygonPoints[(i + 1) % polygonPoints.length];
            if (_distanceToSegment(point, a, b) <= tolerance) {
              return true;
            }
          }
        }
        return false;
      case 'polyline':
        final polylinePoints = _parsePoints(node);
        if (polylinePoints.length < 2) return false;
        if (pointerEvents == 'bounding-box') {
          final polylinePath = Path()
            ..moveTo(polylinePoints.first.dx, polylinePoints.first.dy);
          for (int i = 1; i < polylinePoints.length; i++) {
            polylinePath.lineTo(polylinePoints[i].dx, polylinePoints[i].dy);
          }
          return polylinePath.getBounds().contains(point);
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          for (int i = 0; i < polylinePoints.length - 1; i++) {
            if (_distanceToSegment(
                  point,
                  polylinePoints[i],
                  polylinePoints[i + 1],
                ) <=
                tolerance) {
              return true;
            }
          }
        }

        if (_pointerEventsAllowsFill(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final polylinePath = Path()
            ..moveTo(polylinePoints.first.dx, polylinePoints.first.dy);
          for (int i = 1; i < polylinePoints.length; i++) {
            polylinePath.lineTo(polylinePoints[i].dx, polylinePoints[i].dy);
          }
          return polylinePath.contains(point);
        }
        return false;
      case 'text':
      case 'tspan':
        return _textNodeContainsPoint(
          node,
          point,
          pointerEvents: pointerEvents,
          visibilityHidden: visibilityHidden,
        );
      case 'textPath':
        return _textPathContainsPoint(
          node,
          point,
          pointerEvents: pointerEvents,
          visibilityHidden: visibilityHidden,
        );
      default:
        return false;
    }
  }

  bool _textNodeContainsPoint(
    SvgNode node,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    return _textRunsContainPoint(
      node,
      point,
      pointerEvents: pointerEvents,
      visibilityHidden: visibilityHidden,
    );
  }

  bool _textPathContainsPoint(
    SvgNode textPathNode,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    return _textRunsContainPoint(
      textPathNode,
      point,
      pointerEvents: pointerEvents,
      visibilityHidden: visibilityHidden,
    );
  }

  bool _textRunsContainPoint(
    SvgNode node,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    final textRoot = _findTextLayoutRoot(node);
    if (textRoot == null) {
      return false;
    }
    final runs = _buildTextHitRuns(textRoot);
    final allowBoundingBox = _pointerEventsAllowsBoundingBox(
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    final allowFill = _pointerEventsAllowsFill(
      node,
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    final allowStroke = _pointerEventsAllowsStroke(
      node,
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    if (!allowBoundingBox && !allowFill && !allowStroke) {
      return false;
    }

    for (final run in runs) {
      if (!_isNodeOrDescendant(run.owner, node)) {
        continue;
      }
      if (allowBoundingBox && _textRunBoundingBoxContainsPoint(run, point)) {
        return true;
      }
      final containsForFill = _textRunContainsPoint(run, point);
      if (allowFill && containsForFill) {
        return true;
      }
      if (allowStroke && _textRunStrokeContainsPoint(run, point, node)) {
        return true;
      }
    }
    return false;
  }

  bool _textRunBoundingBoxContainsPoint(_TextHitRun run, Offset point) {
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(point);
    }
    final path = run.path;
    if (path != null) {
      return path.getBounds().contains(point);
    }
    return false;
  }

  bool _textRunContainsPoint(_TextHitRun run, Offset point) {
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(point);
    }
    final path = run.path;
    if (path != null) {
      // TextPath hit-runs are represented as path segments; use tolerance-based
      // containment for baseline parity in fill/bounding-box modes.
      return _pathStrokeContains(path, point, run.pathTolerance);
    }
    return false;
  }

  bool _textRunStrokeContainsPoint(
    _TextHitRun run,
    Offset point,
    SvgNode styleNode,
  ) {
    final bounds = run.bounds;
    if (bounds != null) {
      final boundsPath = Path()..addRect(bounds);
      return _pathStrokeContains(boundsPath, point, _strokeTolerance(styleNode));
    }
    final path = run.path;
    if (path != null) {
      final tolerance = math.max(_strokeTolerance(styleNode), run.pathTolerance);
      return _pathStrokeContains(path, point, tolerance);
    }
    return false;
  }

  SvgNode? _findTextLayoutRoot(SvgNode node) {
    SvgNode? current = node;
    while (current != null) {
      if (current.tagName == 'text') {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  bool _isNodeOrDescendant(SvgNode node, SvgNode ancestor) {
    SvgNode? current = node;
    while (current != null) {
      if (identical(current, ancestor)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  List<_TextHitRun> _buildTextHitRuns(SvgNode textRoot) {
    if (textRoot.tagName != 'text') {
      return const <_TextHitRun>[];
    }
    final startX = _getNumber(textRoot, 'x') ?? 0.0;
    final startY = _getNumber(textRoot, 'y') ?? 0.0;
    final cursor = _HitTextCursor(x: startX, y: startY);
    final runs = <_TextHitRun>[];
    _appendTextNodeHitRuns(textRoot, cursor, runs);
    return runs;
  }

  void _appendTextNodeHitRuns(
    SvgNode node,
    _HitTextCursor cursor,
    List<_TextHitRun> runs,
  ) {
    final x = _getNumber(node, 'x');
    final y = _getNumber(node, 'y');
    final dx = _getNumber(node, 'dx') ?? 0.0;
    final dy = _getNumber(node, 'dy') ?? 0.0;

    if (x != null) {
      cursor.x = x;
    }
    if (y != null) {
      cursor.y = y;
    }
    cursor
      ..x += dx
      ..y += dy;

    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      var metrics = _measureText(text, node);
      final targetLength = _resolveTextLength(node);
      final lengthAdjust = _resolveTextLengthAdjust(node);
      final glyphCount = text.runes.length;
      if (targetLength != null && targetLength > 0 && metrics.width > 0) {
        if (lengthAdjust == _TextLengthAdjust.spacing && glyphCount > 1) {
          final extraSpacing =
              (targetLength - metrics.width) / (glyphCount - 1);
          metrics = _measureText(
            text,
            node,
            additionalLetterSpacing: extraSpacing,
          );
        } else {
          metrics = metrics.copyWith(width: targetLength);
        }
      }
      var left = cursor.x;
      switch (_resolveTextAnchor(node)) {
        case _TextAnchor.middle:
          left -= metrics.width / 2;
          break;
        case _TextAnchor.end:
          left -= metrics.width;
          break;
        case _TextAnchor.start:
          break;
      }
      final top = _resolveTextTopFromBaseline(
        node: node,
        baselineY: cursor.y,
        metrics: metrics,
      );
      runs.add(
        _TextHitRun.bounds(
          owner: node,
          bounds: Rect.fromLTWH(left, top, metrics.width, metrics.height),
        ),
      );
      cursor.x += metrics.width;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _appendTextNodeHitRuns(child, cursor, runs);
      } else if (child.tagName == 'textPath') {
        final consumed = _appendTextPathHitRuns(child, runs);
        cursor.x += consumed;
      }
    }
  }

  double _appendTextPathHitRuns(SvgNode textPathNode, List<_TextHitRun> runs) {
    final path = _resolveTextPathGeometry(textPathNode);
    if (path == null) {
      return 0.0;
    }
    final metricIterator = path.computeMetrics().iterator;
    if (!metricIterator.moveNext()) {
      return 0.0;
    }
    final metric = metricIterator.current;
    if (metric.length <= 0) {
      return 0.0;
    }

    double offset = _parseTextPathStartOffset(textPathNode, metric.length);
    var consumed = 0.0;

    final directText = _extractTextContent(textPathNode);
    if (directText != null && directText.isNotEmpty) {
      final textConsumed = _appendTextPathSegmentRuns(
        owner: textPathNode,
        styleNode: textPathNode,
        text: directText,
        metric: metric,
        startOffset: offset,
        runs: runs,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    for (final child in textPathNode.children) {
      if (child.tagName != 'tspan') {
        continue;
      }
      final childText = _extractTextContent(child);
      if (childText == null || childText.isEmpty) {
        continue;
      }
      final textConsumed = _appendTextPathSegmentRuns(
        owner: child,
        styleNode: child,
        text: childText,
        metric: metric,
        startOffset: offset,
        runs: runs,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }

  double _appendTextPathSegmentRuns({
    required SvgNode owner,
    required SvgNode styleNode,
    required String text,
    required ui.PathMetric metric,
    required double startOffset,
    required List<_TextHitRun> runs,
  }) {
    final glyphs = text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (glyphs.isEmpty) {
      return 0.0;
    }

    final glyphMetrics = glyphs
        .map((glyph) => _measureText(glyph, styleNode))
        .toList(growable: false);
    final widths = glyphMetrics
        .map((metrics) => metrics.width)
        .toList(growable: false);
    final letterSpacing =
        (_getInheritedNumber(styleNode, 'letter-spacing') ?? 0.0).clamp(
          -1024.0,
          1024.0,
        );
    final wordSpacing = (_getInheritedNumber(styleNode, 'word-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);
    final advances = <double>[];
    for (int i = 0; i < glyphs.length; i++) {
      final spacing = _spacingAfterGlyphForHit(
        glyph: glyphs[i],
        isLast: i == glyphs.length - 1,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
      );
      advances.add(widths[i] + spacing);
    }
    final displayWidths = List<double>.from(widths);
    final displayAdvances = List<double>.from(advances);
    var totalWidth = displayAdvances.fold<double>(
      0.0,
      (sum, width) => sum + width,
    );
    final targetLength = _resolveTextLength(styleNode);
    final lengthAdjust = _resolveTextLengthAdjust(styleNode);
    if (targetLength != null && targetLength > 0 && totalWidth > 0) {
      if (lengthAdjust == _TextLengthAdjust.spacing && glyphs.length > 1) {
        final extraSpacing = (targetLength - totalWidth) / (glyphs.length - 1);
        for (int i = 0; i < displayAdvances.length - 1; i++) {
          displayAdvances[i] += extraSpacing;
        }
      } else {
        final scaleX = targetLength / totalWidth;
        for (int i = 0; i < displayWidths.length; i++) {
          displayWidths[i] *= scaleX;
          displayAdvances[i] *= scaleX;
        }
      }
      totalWidth = displayAdvances.fold<double>(
        0.0,
        (sum, width) => sum + width,
      );
    }

    var drawOffset = startOffset;
    switch (_resolveTextAnchor(styleNode)) {
      case _TextAnchor.middle:
        drawOffset -= totalWidth / 2;
        break;
      case _TextAnchor.end:
        drawOffset -= totalWidth;
        break;
      case _TextAnchor.start:
        break;
    }

    var consumed = 0.0;
    var cursor = drawOffset;
    final metricLength = metric.length;
    final fontSize = (_getInheritedNumber(styleNode, 'font-size') ?? 16.0)
        .clamp(1.0, 4096.0);
    for (int i = 0; i < widths.length; i++) {
      final glyphWidth = displayWidths[i];
      final glyphAdvance = displayAdvances[i];
      final start = cursor;
      final end = cursor + glyphWidth;
      final clampedStart = start.clamp(0.0, metricLength).toDouble();
      final clampedEnd = end.clamp(0.0, metricLength).toDouble();
      if (clampedEnd > clampedStart) {
        var glyphPath = metric.extractPath(clampedStart, clampedEnd);
        final tangent = metric.getTangentForOffset(
          ((clampedStart + clampedEnd) / 2).clamp(0.0, metricLength),
        );
        if (tangent != null) {
          final centerOffset = _resolveTextPathCenterOffset(
            node: styleNode,
            metrics: glyphMetrics[i],
          );
          if (centerOffset != 0.0) {
            final normal = Offset(
              -math.sin(tangent.angle),
              math.cos(tangent.angle),
            );
            glyphPath = glyphPath.shift(
              Offset(normal.dx * centerOffset, normal.dy * centerOffset),
            );
          }
        }
        final glyphTolerance = (glyphMetrics[i].height / 2)
            .clamp(fontSize / 3, fontSize)
            .toDouble();
        runs.add(
          _TextHitRun.path(
            owner: owner,
            path: glyphPath,
            pathTolerance: glyphTolerance,
          ),
        );
      }

      cursor += glyphAdvance;
      consumed += glyphAdvance;
      if (cursor > metricLength + fontSize) {
        break;
      }
    }

    return consumed;
  }

  _TextMeasure _measureText(
    String text,
    SvgNode node, {
    double additionalLetterSpacing = 0.0,
  }) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fontFamily = _getInheritedString(node, 'font-family');
    final fontWeight = _resolveFontWeight(
      _getInheritedString(node, 'font-weight'),
    );
    final fontStyle = _resolveFontStyle(
      _getInheritedString(node, 'font-style'),
    );
    final letterSpacing =
        ((_getInheritedNumber(node, 'letter-spacing') ?? 0.0) +
                additionalLetterSpacing)
            .clamp(-1024.0, 1024.0);
    final wordSpacing = (_getInheritedNumber(node, 'word-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    return _TextMeasure(
      width: painter.width,
      height: painter.height,
      alphabeticBaseline: baseline,
      fontSize: fontSize,
    );
  }

  double? _resolveTextLength(SvgNode node) {
    final value = node.getAttributeValue('textLength');
    if (value == null) {
      return null;
    }
    if (value is num) {
      final length = value.toDouble();
      return length > 0 ? length : null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  _TextLengthAdjust _resolveTextLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _TextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _TextLengthAdjust.spacingAndGlyphs
        : _TextLengthAdjust.spacing;
  }

  double _resolveTextTopFromBaseline({
    required SvgNode node,
    required double baselineY,
    required _TextMeasure metrics,
  }) {
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      metrics.fontSize,
    );
    final baselineRef = _resolveBaselineReference(
      dominantBaseline: dominantBaseline,
      metrics: metrics,
    );
    final shiftedBaselineY = baselineY - baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  double _resolveTextPathCenterOffset({
    required SvgNode node,
    required _TextMeasure metrics,
  }) {
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      metrics.fontSize,
    );
    final baselineRef = _resolveBaselineReference(
      dominantBaseline: dominantBaseline,
      metrics: metrics,
    );
    return -baselineRef - baselineShift + metrics.height / 2;
  }

  _TextDominantBaseline _resolveDominantBaseline(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'middle':
      case 'central':
        return _TextDominantBaseline.central;
      case 'text-before-edge':
      case 'before-edge':
      case 'hanging':
        return _TextDominantBaseline.textBeforeEdge;
      case 'text-after-edge':
      case 'after-edge':
      case 'ideographic':
        return _TextDominantBaseline.textAfterEdge;
      case 'alphabetic':
      default:
        return _TextDominantBaseline.alphabetic;
    }
  }

  double _resolveBaselineReference({
    required _TextDominantBaseline dominantBaseline,
    required _TextMeasure metrics,
  }) {
    return switch (dominantBaseline) {
      _TextDominantBaseline.alphabetic => metrics.alphabeticBaseline,
      _TextDominantBaseline.central => metrics.height / 2,
      _TextDominantBaseline.textBeforeEdge => 0.0,
      _TextDominantBaseline.textAfterEdge => metrics.height,
    };
  }

  double _resolveBaselineShift(Object? rawValue, double fontSize) {
    if (rawValue == null) {
      return 0.0;
    }
    if (rawValue is num) {
      return rawValue.toDouble().clamp(-4096.0, 4096.0);
    }
    final value = rawValue.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'baseline') {
      return 0.0;
    }
    if (value == 'sub') {
      return -fontSize * 0.6;
    }
    if (value == 'super') {
      return fontSize * 0.6;
    }
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (fontSize * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

  double _spacingAfterGlyphForHit({
    required String glyph,
    required bool isLast,
    required double letterSpacing,
    required double wordSpacing,
  }) {
    if (isLast) {
      return 0.0;
    }
    var spacing = letterSpacing;
    if (glyph == ' ' || glyph == '\u00A0') {
      spacing += wordSpacing;
    }
    return spacing;
  }

  _TextAnchor _resolveTextAnchor(SvgNode node) {
    final textAnchor = _getInheritedString(node, 'text-anchor')?.toLowerCase();
    switch (textAnchor) {
      case 'middle':
        return _TextAnchor.middle;
      case 'end':
        return _TextAnchor.end;
      case 'start':
      default:
        return _TextAnchor.start;
    }
  }

  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) {
      return 0.0;
    }

    if (raw is num) {
      return raw.toDouble().clamp(0.0, pathLength);
    }

    final value = raw.toString().trim();
    if (value.isEmpty) {
      return 0.0;
    }

    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }

    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }

  Path? _buildPathGeometry(SvgNode node) {
    final pathData = node.getAttributeValue('d')?.toString();
    if (pathData == null || pathData.isEmpty) {
      return null;
    }

    final path = _buildPath(pathData);
    if (path == null) {
      return null;
    }

    _applyPathFillType(path, node);
    return path;
  }

  Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) {
          return null;
        }
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? rx;
        if (rx > 0 || ry > 0) {
          return Path()..addRRect(
            RRect.fromRectXY(Rect.fromLTWH(x, y, width, height), rx, ry),
          );
        }
        return Path()..addRect(Rect.fromLTWH(x, y, width, height));
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) {
          return null;
        }
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) {
          return null;
        }
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        return Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      case 'polygon':
        final points = _parsePoints(node);
        if (points.length < 3) {
          return null;
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        path.close();
        _applyPathFillType(path, node);
        return path;
      case 'polyline':
        final points = _parsePoints(node);
        if (points.length < 2) {
          return null;
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        _applyPathFillType(path, node);
        return path;
      case 'path':
        return _buildPathGeometry(node);
      default:
        return null;
    }
  }

  Rect? _computeNodeLocalBounds(SvgNode node) {
    final path = _buildGeometryPath(node);
    if (path == null) {
      return null;
    }
    final bounds = path.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }
    return bounds;
  }

  Path? _buildContainerGeometryPath(
    SvgNode containerNode, {
    Matrix4? rootTransform,
  }) {
    final path = Path();
    final added = _appendContainerGeometry(
      target: path,
      node: containerNode,
      currentTransform: rootTransform ?? Matrix4.identity(),
      useStack: <String>{},
    );
    return added ? path : null;
  }

  bool _appendContainerGeometry({
    required Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    _applyNodeTransform(matrix, node);

    switch (node.tagName) {
      case 'clipPath':
      case 'mask':
      case 'g':
      case 'svg':
      case 'symbol':
        var added = false;
        for (final child in node.children) {
          if (_appendContainerGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
          )) {
            added = true;
          }
        }
        return added;
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null) {
          return false;
        }
        return _appendContainerGeometry(
          target: target,
          node: activeChild,
          currentTransform: matrix,
          useStack: useStack,
        );
      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return false;
        }
        final referenced = _document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return false;
        }
        final translated = Matrix4.copy(matrix)
          ..translateByDouble(
            _getNumber(node, 'x') ?? 0.0,
            _getNumber(node, 'y') ?? 0.0,
            0,
            1,
          );
        final nextUseStack = <String>{...useStack, hrefId};
        if (_isUseViewportReferenceTag(referenced.tagName)) {
          final useReferenceTransform = Matrix4.copy(translated);
          _applyUseViewportTransform(useReferenceTransform, node, referenced);
          return _appendContainerGeometry(
            target: target,
            node: referenced,
            currentTransform: useReferenceTransform,
            useStack: nextUseStack,
          );
        }
        return _appendContainerGeometry(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
        );
      default:
        final geometry = _buildGeometryPath(node);
        if (geometry == null) {
          return false;
        }
        target.addPath(geometry.transform(matrix.storage), Offset.zero);
        return true;
    }
  }

  Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') {
      return null;
    }

    final path = _buildPathGeometry(referenced);
    if (path == null) {
      return null;
    }

    final transformAttr = referenced.getAttributeValue('transform');
    if (transformAttr == null || transformAttr.toString().trim().isEmpty) {
      return path;
    }
    final matrix = Matrix4.identity();
    _applyNodeTransform(matrix, referenced);
    return path.transform(matrix.storage);
  }

  void _applyPathFillType(Path path, SvgNode node) {
    final fillRule = node
        .getAttributeValue('fill-rule')
        ?.toString()
        .toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? PathFillType.evenOdd
        : PathFillType.nonZero;
  }

  Path? _buildPath(String pathData) {
    List<PathCommand> commands;
    try {
      commands = PathParser().parse(pathData);
    } catch (_) {
      return null;
    }

    if (commands.isEmpty) {
      return null;
    }

    final path = Path();
    double currentX = 0.0;
    double currentY = 0.0;
    double subPathStartX = 0.0;
    double subPathStartY = 0.0;
    PathCommand? previousCommand;

    for (final command in commands) {
      final absoluteCommand = command.toAbsolute(currentX, currentY);

      switch (absoluteCommand) {
        case MoveToCommand():
          path.moveTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          subPathStartX = currentX;
          subPathStartY = currentY;
          previousCommand = absoluteCommand;

        case LineToCommand():
          path.lineTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case HorizontalLineToCommand():
          path.lineTo(absoluteCommand.x, currentY);
          currentX = absoluteCommand.x;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case VerticalLineToCommand():
          path.lineTo(currentX, absoluteCommand.y);
          currentY = absoluteCommand.y;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case CubicBezierCommand():
          path.cubicTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x2,
            absoluteCommand.y2,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothCubicBezierCommand():
          final cubic = absoluteCommand.toCubicBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.cubicTo(
            cubic.x1,
            cubic.y1,
            cubic.x2,
            cubic.y2,
            cubic.x,
            cubic.y,
          );
          currentX = cubic.x;
          currentY = cubic.y;
          previousCommand = cubic;

        case QuadraticBezierCommand():
          path.quadraticBezierTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothQuadraticBezierCommand():
          final quadratic = absoluteCommand.toQuadraticBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.quadraticBezierTo(
            quadratic.x1,
            quadratic.y1,
            quadratic.x,
            quadratic.y,
          );
          currentX = quadratic.x;
          currentY = quadratic.y;
          previousCommand = quadratic;

        case ArcCommand():
          if (absoluteCommand.rx <= 0 || absoluteCommand.ry <= 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
          } else {
            path.arcToPoint(
              Offset(absoluteCommand.x, absoluteCommand.y),
              radius: Radius.elliptical(
                absoluteCommand.rx.abs(),
                absoluteCommand.ry.abs(),
              ),
              rotation: absoluteCommand.rotation,
              largeArc: absoluteCommand.largeArc,
              clockwise: absoluteCommand.sweep,
            );
          }
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case ClosePathCommand():
          path.close();
          currentX = subPathStartX;
          currentY = subPathStartY;
          previousCommand = absoluteCommand;
      }
    }

    return path;
  }

  bool _pathStrokeContains(Path path, Offset point, double tolerance) {
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) {
        continue;
      }

      final stepCount = math.max(1, (length / 2.0).ceil());
      Offset? previous;
      for (int step = 0; step <= stepCount; step++) {
        final tangent = metric.getTangentForOffset(length * step / stepCount);
        if (tangent == null) {
          continue;
        }
        final current = tangent.position;
        if (previous != null &&
            _distanceToSegment(point, previous, current) <= tolerance) {
          return true;
        }
        previous = current;
      }
    }
    return false;
  }

  void _applyForeignObjectChildTransform(Matrix4 matrix, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    matrix.translateByDouble(x, y, 0, 1);
  }

  void _applyNodeTransform(Matrix4 matrix, SvgNode node) {
    final transformAttr = node.getAttributeValue('transform')?.toString();
    if (transformAttr == null || transformAttr.isEmpty) return;

    final transforms = SvgTransform.parse(transformAttr);
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          matrix.translateByDouble(tx, ty, 0, 1);
          break;
        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1 ? transform.values[1] : sx;
          matrix.scaleByDouble(sx, sy, 1, 1);
          break;
        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (transform.values.length >= 3) {
            final cx = transform.values[1];
            final cy = transform.values[2];
            matrix
              ..translateByDouble(cx, cy, 0, 1)
              ..rotateZ(radians)
              ..translateByDouble(-cx, -cy, 0, 1);
          } else {
            matrix.rotateZ(radians);
          }
          break;
        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(0, 1, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(1, 0, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];
            final custom = Matrix4.identity()
              ..setEntry(0, 0, a)
              ..setEntry(1, 0, b)
              ..setEntry(0, 1, c)
              ..setEntry(1, 1, d)
              ..setEntry(0, 3, e)
              ..setEntry(1, 3, f);
            matrix.multiply(custom);
          }
          break;
      }
    }
  }

  String? _extractHrefId(SvgNode node) {
    final href =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (href == null) {
      return null;
    }

    final raw = href.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }

    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }

  String? _extractStyleValue(SvgNode node, String property) {
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
      final value = parts.sublist(1).join(':').trim();
      final normalizedValue = value
          .replaceFirst(
            RegExp(r'\s*!important\s*$', caseSensitive: false),
            '',
          )
          .trim();
      if (normalizedValue.isNotEmpty) {
        return normalizedValue;
      }
    }
    return null;
  }

  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  Object? _getInheritedAttributeValue(SvgNode node, String attributeName) {
    final normalizedName = attributeName.trim().toLowerCase();
    SvgNode? current = node;
    while (current != null) {
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        return styleValue;
      }
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        return value;
      }
      current = current.parent;
    }
    return null;
  }

  String? _getInheritedString(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    final str = value?.toString();
    if (str == null) {
      return null;
    }
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _getInheritedNumber(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }

  String? _extractTextContent(SvgNode node) {
    final raw = node.getAttributeValue('__text')?.toString();
    if (raw == null) {
      return null;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  FontWeight _resolveFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return FontWeight.normal;
    }
    switch (fontWeight.toLowerCase()) {
      case '100':
      case 'thin':
        return FontWeight.w100;
      case '200':
      case 'extralight':
      case 'extra-light':
        return FontWeight.w200;
      case '300':
      case 'light':
        return FontWeight.w300;
      case '500':
      case 'medium':
        return FontWeight.w500;
      case '600':
      case 'semibold':
      case 'semi-bold':
        return FontWeight.w600;
      case '700':
      case 'bold':
        return FontWeight.w700;
      case '800':
      case 'extrabold':
      case 'extra-bold':
        return FontWeight.w800;
      case '900':
      case 'black':
        return FontWeight.w900;
      case '400':
      case 'normal':
      default:
        return FontWeight.normal;
    }
  }

  FontStyle _resolveFontStyle(String? fontStyle) {
    return fontStyle?.toLowerCase() == 'italic'
        ? FontStyle.italic
        : FontStyle.normal;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared == 0) {
      return (p - a).distance;
    }

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(
      0.0,
      1.0,
    );
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  List<Offset> _parsePoints(SvgNode node) {
    final value = node.getAttributeValue('points')?.toString();
    if (value == null || value.trim().isEmpty) {
      return const <Offset>[];
    }

    final numbers = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (numbers.length < 2) {
      return const <Offset>[];
    }

    final points = <Offset>[];
    for (int i = 0; i + 1 < numbers.length; i += 2) {
      points.add(Offset(numbers[i], numbers[i + 1]));
    }
    return points;
  }

  bool _isFillEnabled(SvgNode node) {
    final fill = _getInheritedAttributeValue(node, 'fill');
    return !_isPaintNone(fill);
  }

  bool _hasStroke(SvgNode node) {
    final stroke = _getInheritedAttributeValue(node, 'stroke');
    return stroke != null && !_isPaintNone(stroke);
  }

  double _strokeTolerance(SvgNode node) {
    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    return (strokeWidth / 2).clamp(1.0, 8.0);
  }

  bool _isPaintNone(Object? value) {
    if (value is Color && value.a <= 0) {
      return true;
    }
    final str = value?.toString().trim().toLowerCase();
    return str == 'none';
  }

  bool _isPointerEventsNone(SvgNode node) {
    return _resolvePointerEventsMode(node) == 'none';
  }

  bool _isVisibilityHidden(SvgNode node) {
    final visibility = _getInheritedString(node, 'visibility')?.toLowerCase();
    return visibility == 'hidden' || visibility == 'collapse';
  }

  bool _isDisplayNone(SvgNode node) {
    final styleValue = _extractStyleValue(node, 'display');
    final rawValue = styleValue ?? node.getAttributeValue('display');
    final display = rawValue?.toString().trim().toLowerCase();
    return display == 'none';
  }

  String _resolvePointerEventsMode(SvgNode node) {
    final raw = _resolveInheritedPointerEvents(node);
    if (raw == null || raw.isEmpty || raw == 'auto') {
      return 'visiblepainted';
    }
    switch (raw) {
      case 'none':
      case 'visiblepainted':
      case 'visiblefill':
      case 'visiblestroke':
      case 'visible':
      case 'painted':
      case 'fill':
      case 'stroke':
      case 'all':
      case 'bounding-box':
        return raw;
      default:
        return 'visiblepainted';
    }
  }

  bool _pointerEventsAllowsFill(
    SvgNode node,
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'visiblepainted':
        if (visibilityHidden) {
          return false;
        }
        return _isFillEnabled(node);
      case 'visiblefill':
      case 'visible':
        return !visibilityHidden;
      case 'visiblestroke':
        return false;
      case 'painted':
        return _isFillEnabled(node);
      case 'fill':
      case 'all':
      case 'bounding-box':
        return true;
      case 'none':
      case 'stroke':
        return false;
      default:
        return _isFillEnabled(node);
    }
  }

  bool _pointerEventsAllowsStroke(
    SvgNode node,
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'visiblepainted':
        if (visibilityHidden) {
          return false;
        }
        return _hasStroke(node);
      case 'visiblestroke':
      case 'visible':
        return !visibilityHidden;
      case 'visiblefill':
        return false;
      case 'painted':
        return _hasStroke(node);
      case 'stroke':
      case 'all':
      case 'bounding-box':
        return true;
      case 'none':
      case 'fill':
        return false;
      default:
        return _hasStroke(node);
    }
  }

  bool _pointerEventsAllowsBoundingBox(
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'none':
      case 'stroke':
      case 'visiblestroke':
        return false;
      case 'visible':
      case 'visiblepainted':
      case 'visiblefill':
        return !visibilityHidden;
      default:
        return true;
    }
  }

  String? _resolveInheritedPointerEvents(SvgNode node) {
    SvgNode? current = node;
    while (current != null) {
      final styleValue = _extractStyleValue(current, 'pointer-events');
      final raw = styleValue ?? current.getAttributeValue('pointer-events');
      final normalized = raw?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        current = current.parent;
        continue;
      }
      if (normalized == 'inherit') {
        current = current.parent;
        continue;
      }
      return normalized;
    }
    return null;
  }

  void _trace({
    required String category,
    required String message,
    SvgTraceLevel level = SvgTraceLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final callback = widget.onTrace;
    if (callback == null) {
      return;
    }
    callback(
      SvgTraceEvent(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Запустить анимацию
  void play() {
    _controller?.forward();
  }

  /// Остановить анимацию
  void pause() {
    _controller?.stop();
  }

  /// Перейти к началу
  void reset() {
    _controller?.reset();
    _timeline?.reset();
  }

  /// Перейти к конкретному времени
  void seekTo(Duration time) {
    if (_controller == null || _timeline == null) return;

    final progress =
        time.inMicroseconds / _timeline!.totalDuration.inMicroseconds;
    _controller!.value = progress.clamp(0.0, 1.0);
  }
}

enum _TextAnchor { start, middle, end }

enum _TextLengthAdjust { spacing, spacingAndGlyphs }

class _HitTextCursor {
  _HitTextCursor({required this.x, required this.y});

  double x;
  double y;
}

class _TextMeasure {
  const _TextMeasure({
    required this.width,
    required this.height,
    required this.alphabeticBaseline,
    required this.fontSize,
  });

  final double width;
  final double height;
  final double alphabeticBaseline;
  final double fontSize;

  _TextMeasure copyWith({
    double? width,
    double? height,
    double? alphabeticBaseline,
    double? fontSize,
  }) {
    return _TextMeasure(
      width: width ?? this.width,
      height: height ?? this.height,
      alphabeticBaseline: alphabeticBaseline ?? this.alphabeticBaseline,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

enum _TextDominantBaseline {
  alphabetic,
  central,
  textBeforeEdge,
  textAfterEdge,
}

class _TextHitRun {
  const _TextHitRun.bounds({required this.owner, required Rect this.bounds})
    : path = null,
      pathTolerance = 0.0;

  const _TextHitRun.path({
    required this.owner,
    required Path this.path,
    required this.pathTolerance,
  }) : bounds = null;

  final SvgNode owner;
  final Rect? bounds;
  final Path? path;
  final double pathTolerance;
}
