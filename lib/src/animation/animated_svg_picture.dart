import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animated_svg_controller.dart';
import 'animated_svg_painter.dart';
import 'animation_detector.dart';
import 'css_variables_calc.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'switch_processing.dart';
import 'smil/smil_parser.dart';
import 'smil/smil_timeline.dart';
import 'svg_dom.dart';
import 'svg_parser.dart';
import 'svg_transform.dart';
import 'transform_3d.dart';

part 'animated_svg_picture_pointer_events.dart';
part 'animated_svg_picture_lifecycle.dart';
part 'animated_svg_picture_images.dart';
part 'animated_svg_picture_events.dart';
part 'animated_svg_picture_utils.dart';
part 'animated_svg_picture_utils_transform.dart';
part 'animated_svg_picture_utils_attrs.dart';
part 'animated_svg_picture_utils_style.dart';
part 'animated_svg_picture_hit_test_traversal.dart';
part 'animated_svg_picture_hit_test_visibility.dart';
part 'animated_svg_picture_hit_test_use.dart';
part 'animated_svg_picture_hit_test_geometry.dart';
part 'animated_svg_picture_hit_test_text_runs.dart';
part 'animated_svg_picture_hit_test_text_path_segments.dart';
part 'animated_svg_picture_hit_test_text_layout.dart';
part 'animated_svg_picture_paths.dart';
part 'animated_svg_picture_path_parser.dart';

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

/// Information about an SVG anchor (link) element.
@immutable
class SvgLinkInfo {
  /// Creates link info.
  const SvgLinkInfo({required this.href, this.target});

  /// The link URL (from href or xlink:href attribute).
  final String href;

  /// The link target (e.g., '_blank', '_self'). May be null.
  final String? target;
}

/// Callback used for handling link taps in SVG anchor elements.
typedef SvgLinkTapCallback = void Function(SvgLinkInfo linkInfo);

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
    this.onLinkTap,
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

  /// Callback invoked when a link (<a> element) is tapped.
  /// The callback receives [SvgLinkInfo] with href and target attributes.
  final SvgLinkTapCallback? onLinkTap;

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
  SvgLinkInfo? _hoveredAnchorInfo;
  final Map<String, ui.Image> _imagesByHref = <String, ui.Image>{};
  final Set<String> _pendingImageHrefs = <String>{};
  int _imageLoadGeneration = 0;

  /// Cached hit-test paths keyed by element ID + path data hash.
  final Map<String, Path> _hitTestPathCache = <String, Path>{};

  /// Last animation time when hit-test cache was valid.
  double? _hitTestCacheTime;

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

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _markNeedsRepaint() {
    if (!mounted) {
      return;
    }
    setState(() {});
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

    // Wrap with gesture detection for event-based animations or link handling
    final needsGestureDetection =
        (_hasAnimations && _timeline != null) || widget.onLinkTap != null;
    if (needsGestureDetection) {
      svgWidget = GestureDetector(
        onTapDown: (details) => _handleTapDown(details),
        onTapUp: (_) => _handleTapUp(),
        onTapCancel: () => _handleTapUp(),
        child: MouseRegion(
          cursor: _hoveredAnchorInfo != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
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

    // Wrap with Semantics for accessibility
    final accessibleName = _document.accessibleName;
    final accessibleDescription = _document.accessibleDescription;
    final accessibleRole = _document.accessibleRole;

    if (accessibleName != null || accessibleDescription != null) {
      svgWidget = Semantics(
        label: accessibleName,
        hint: accessibleDescription,
        image: accessibleRole == 'img',
        button: accessibleRole == 'button',
        link: accessibleRole == 'link',
        excludeSemantics: false,
        child: svgWidget,
      );
    }

    return svgWidget;
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

/// SVG textPath spacing attribute values for hit-testing.
enum _TextPathSpacing { auto, exact }

class _HitTextCursor {
  _HitTextCursor({required this.x, required this.y});

  double x;
  double y;

  /// Character index for consuming multi-position attribute lists.
  int charIndex = 0;
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
  const _TextHitRun.bounds({
    required this.owner,
    required Rect this.bounds,
    this.rotation = 0.0,
    this.rotationCenter = Offset.zero,
  }) : path = null,
       pathTolerance = 0.0;

  const _TextHitRun.path({
    required this.owner,
    required Path this.path,
    required this.pathTolerance,
  }) : bounds = null,
       rotation = 0.0,
       rotationCenter = Offset.zero;

  final SvgNode owner;
  final Rect? bounds;
  final Path? path;
  final double pathTolerance;

  /// Rotation angle in degrees (for per-character rotation).
  final double rotation;

  /// Center point for rotation (baseline position).
  final Offset rotationCenter;
}
