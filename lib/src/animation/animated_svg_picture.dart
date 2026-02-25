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
      ..translate(translateX, translateY)
      ..scale(scale, scale);
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

    final currentUseStack = useStack;
    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    if (!_isPointVisibleForNode(node, documentPoint, currentTransform)) {
      return null;
    }

    final childTransform = Matrix4.copy(currentTransform);
    _applyForeignObjectChildTransform(childTransform, node);

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

    if (node.id == null || !_isHitTestableTag(node.tagName)) {
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
    final clipId = _extractUrlId(node.getAttributeValue('clip-path'));
    if (clipId == null || clipId.isEmpty) {
      return true;
    }
    final clipNode = _document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return true;
    }
    final clipPath = _buildContainerGeometryPath(clipNode);
    if (clipPath == null) {
      return true;
    }
    return clipPath.contains(localPoint);
  }

  bool _isPointInsideMask(SvgNode node, Offset localPoint) {
    final maskId = _extractUrlId(node.getAttributeValue('mask'));
    if (maskId == null || maskId.isEmpty) {
      return true;
    }
    final maskNode = _document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return true;
    }
    final maskPath = _buildContainerGeometryPath(maskNode);
    if (maskPath == null) {
      return true;
    }
    return maskPath.contains(localPoint);
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
    if (referenced == null) {
      return null;
    }

    final referenceTransform = Matrix4.copy(currentTransform)
      ..translate(
        _getNumber(useNode, 'x') ?? 0.0,
        _getNumber(useNode, 'y') ?? 0.0,
      );

    final nextUseStack = <String>{...useStack, hrefId};
    if (referenced.tagName == 'symbol') {
      final symbolTransform = Matrix4.copy(referenceTransform);
      _applySymbolUseTransform(symbolTransform, useNode, referenced);
      for (int i = referenced.children.length - 1; i >= 0; i--) {
        final hitChild = _hitTestNode(
          referenced.children[i],
          documentPoint,
          symbolTransform,
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
      referenceTransform,
      useStack: nextUseStack,
    );
  }

  void _applySymbolUseTransform(
    Matrix4 matrix,
    SvgNode useNode,
    SvgNode symbolNode,
  ) {
    final viewBox = _parseViewBox(symbolNode.getAttributeValue('viewBox'));
    final width = _getNumber(useNode, 'width');
    final height = _getNumber(useNode, 'height');
    if (viewBox == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        viewBox.width <= 0 ||
        viewBox.height <= 0) {
      return;
    }

    final scaleX = width / viewBox.width;
    final scaleY = height / viewBox.height;
    final scale = math.min(scaleX, scaleY);
    final translateX =
        (width - viewBox.width * scale) / 2 - viewBox.left * scale;
    final translateY =
        (height - viewBox.height * scale) / 2 - viewBox.top * scale;
    matrix
      ..translate(translateX, translateY)
      ..scale(scale, scale);
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

    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) return false;
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return false;
        return (point - Offset(cx, cy)).distance <= r;
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return false;
        final dx = (point.dx - cx) / rx;
        final dy = (point.dy - cy) / ry;
        return dx * dx + dy * dy <= 1.0;
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        final strokeWidth = _getNumber(node, 'stroke-width') ?? 1.0;
        final tolerance = (strokeWidth / 2).clamp(1.0, 8.0);
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
        if (width <= 0 || height <= 0) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'foreignObject':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'path':
        final path = _buildPathGeometry(node);
        if (path == null) {
          return false;
        }

        if (_isFillEnabled(node) && path.contains(point)) {
          return true;
        }

        if (_hasStroke(node)) {
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

        if (_isFillEnabled(node) && polygonPath.contains(point)) {
          return true;
        }

        if (_hasStroke(node)) {
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

        if (_hasStroke(node)) {
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

        if (_isFillEnabled(node)) {
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
        return _textNodeContainsPoint(node, point);
      case 'textPath':
        return _textPathContainsPoint(node, point);
      default:
        return false;
    }
  }

  bool _textNodeContainsPoint(SvgNode node, Offset point) {
    final textBounds = _computeTextBounds(node);
    if (textBounds != null && textBounds.contains(point)) {
      return true;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan' && _textNodeContainsPoint(child, point)) {
        return true;
      }
      if (child.tagName == 'textPath' && _textPathContainsPoint(child, point)) {
        return true;
      }
    }

    return false;
  }

  bool _textPathContainsPoint(SvgNode textPathNode, Offset point) {
    final path = _resolveTextPathGeometry(textPathNode);
    if (path == null) {
      return false;
    }
    final fontSize = (_getInheritedNumber(textPathNode, 'font-size') ?? 16.0)
        .clamp(1.0, 4096.0);
    final tolerance = (fontSize / 2).clamp(2.0, 32.0);
    return _pathStrokeContains(path, point, tolerance);
  }

  Rect? _computeTextBounds(SvgNode node) {
    final text = _extractTextContent(node);
    if (text == null || text.isEmpty) {
      return null;
    }

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

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final x =
        (_getInheritedNumber(node, 'x') ?? 0.0) +
        (_getNumber(node, 'dx') ?? 0.0);
    final y =
        (_getInheritedNumber(node, 'y') ?? 0.0) +
        (_getNumber(node, 'dy') ?? 0.0);
    final textAnchor = _getInheritedString(node, 'text-anchor')?.toLowerCase();

    var left = x;
    if (textAnchor == 'middle') {
      left -= painter.width / 2;
    } else if (textAnchor == 'end') {
      left -= painter.width;
    }

    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final top = y - baseline;
    return Rect.fromLTWH(left, top, painter.width, painter.height);
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

  Path? _buildContainerGeometryPath(SvgNode containerNode) {
    final path = Path();
    var added = false;
    for (final child in containerNode.children) {
      final childGeometry = _buildGeometryPath(child);
      if (childGeometry == null) {
        continue;
      }
      final transform = Matrix4.identity();
      _applyNodeTransform(transform, child);
      path.addPath(childGeometry.transform(transform.storage), Offset.zero);
      added = true;
    }
    return added ? path : null;
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
    matrix.translate(x, y);
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
          matrix.translate(tx, ty);
          break;
        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1 ? transform.values[1] : sx;
          matrix.scale(sx, sy);
          break;
        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (transform.values.length >= 3) {
            final cx = transform.values[1];
            final cy = transform.values[2];
            matrix
              ..translate(cx, cy)
              ..rotateZ(radians)
              ..translate(-cx, -cy);
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
    SvgNode? current = node;
    while (current != null) {
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
    final fill = node
        .getAttributeValue('fill')
        ?.toString()
        .trim()
        .toLowerCase();
    return fill == null || fill != 'none';
  }

  bool _hasStroke(SvgNode node) {
    final stroke = node
        .getAttributeValue('stroke')
        ?.toString()
        .trim()
        .toLowerCase();
    return stroke != null && stroke != 'none';
  }

  double _strokeTolerance(SvgNode node) {
    final strokeWidth = _getNumber(node, 'stroke-width') ?? 1.0;
    return (strokeWidth / 2).clamp(1.0, 8.0);
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
