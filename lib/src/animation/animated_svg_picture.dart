import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  void _dispose() {
    _trace(category: 'lifecycle', message: 'Disposing AnimatedSvgPicture');
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

    return _hitTestNode(_document.root, documentPoint, Matrix4.identity());
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
    Matrix4 parentTransform,
  ) {
    final currentTransform = Matrix4.copy(parentTransform);
    _applyNodeTransform(currentTransform, node);

    // Идём с конца: последний нарисованный элемент визуально сверху
    for (int i = node.children.length - 1; i >= 0; i--) {
      final hitChild = _hitTestNode(
        node.children[i],
        documentPoint,
        currentTransform,
      );
      if (hitChild != null) {
        return hitChild;
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
        tagName == 'line';
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
      default:
        return false;
    }
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
