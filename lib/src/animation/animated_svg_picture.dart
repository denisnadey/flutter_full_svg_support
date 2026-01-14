import 'package:flutter/material.dart';

import 'animated_svg_controller.dart';
import 'animated_svg_painter.dart';
import 'animation_detector.dart';
import 'smil/smil_parser.dart';
import 'smil/smil_timeline.dart';
import 'svg_dom.dart';
import 'svg_parser.dart';

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

  @override
  State<AnimatedSvgPicture> createState() => _AnimatedSvgPictureState();
}

class _AnimatedSvgPictureState extends State<AnimatedSvgPicture>
    with TickerProviderStateMixin {
  late SvgDocument _document;
  SvgTimeline? _timeline;
  AnimationController? _controller;
  bool _hasAnimations = false;

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

        final hasInfiniteAnimations = _timeline!.animations.any(
          (anim) => anim.repeatCount.isInfinite,
        );

        if (hasInfiniteAnimations) {
          _controller!.repeat();
        } else {
          _controller!.forward();
        }
      } else if (!widget.autoPlay && _controller != null) {
        // Нужно удалить контроллер
        _controller?.removeListener(_onAnimationTick);
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _initialize() {
    // Проверяем наличие анимаций
    _hasAnimations = AnimationDetector.hasAnimations(widget._svgString);

    // Парсим SVG
    _document = SvgParser.parse(widget._svgString);

    if (_hasAnimations) {
      // Парсим анимации
      final animations = SmilParser.parseAnimations(_document);

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

        // Перерисовываем первый кадр (важно для autoPlay: false)
        if (mounted) {
          setState(() {});
        }

        // Создаём AnimationController только если autoPlay
        if (widget.autoPlay) {
          final duration = _timeline!.totalDuration;

          _controller = AnimationController(vsync: this, duration: duration);

          // Устанавливаем начальное значение контроллера если задано initialTime
          if (widget.initialTime != null && duration.inMicroseconds > 0) {
            final progress =
                widget.initialTime!.inMicroseconds / duration.inMicroseconds;
            _controller!.value = progress.clamp(0.0, 1.0);
          }

          // Слушаем обновления контроллера
          _controller!.addListener(_onAnimationTick);

          // Проверяем есть ли бесконечные анимации
          final hasInfiniteAnimations = animations.any(
            (anim) => anim.repeatCount.isInfinite,
          );

          if (hasInfiniteAnimations) {
            _controller!.repeat();
          } else {
            _controller!.forward();
          }
        }
      } else {
        _hasAnimations = false;
      }
    }
  }

  void _onAnimationTick() {
    if (_controller == null || _timeline == null) return;

    // Конвертируем progress контроллера в время
    final elapsed = _controller!.duration! * _controller!.value;

    // Обновляем timeline
    _timeline!.seek(elapsed);

    // Перерисовываем
    setState(() {});
  }

  void _onControllerUpdate() {
    if (_timeline == null) return;

    final controller = widget.controller;
    if (controller == null) return;

    // Обработка pause/resume
    if (controller.isPaused) {
      _controller?.stop();
    } else if (_controller != null && !_controller!.isAnimating) {
      // Возобновляем анимацию
      final hasInfinite = _timeline!.animations.any(
        (anim) => anim.repeatCount.isInfinite,
      );
      if (hasInfinite) {
        _controller!.repeat();
      } else {
        _controller!.forward(from: _controller!.value);
      }
    }

    // Обработка playbackRate
    if (controller.playbackRate != _timeline!.playbackRate) {
      _timeline!.playbackRate = controller.playbackRate;
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
      setState(() {});
    }

    // Обработка reverse (пока не реализовано полностью)
    // TODO: Реализовать reverse направление
  }

  void _dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _controller?.removeListener(_onAnimationTick);
    _controller?.dispose();
    _controller = null;
    _timeline = null;
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
        onTap: () => _handleTap(),
        onTapDown: (details) => _handleTapDown(details),
        child: MouseRegion(
          onEnter: (_) => _handleMouseEnter(),
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

  /// Обработать клик по всему SVG (document-level event)
  void _handleTap() {
    _timeline?.triggerEvent(null, 'click');
  }

  /// Обработать клик с координатами (может триггерить клик на элемент)
  void _handleTapDown(TapDownDetails details) {
    // TODO: Implement hit-testing to find which SVG element was clicked
    // For now, just trigger document-level click
    _timeline?.triggerEvent(null, 'click');
  }

  /// Обработать вход мыши в область SVG
  void _handleMouseEnter() {
    _timeline?.triggerEvent(null, 'mouseover');
  }

  /// Обработать выход мыши из области SVG
  void _handleMouseExit() {
    _timeline?.triggerEvent(null, 'mouseout');
  }

  /// Обработать движение мыши над SVG
  void _handleMouseHover(Offset position) {
    // TODO: Implement element-specific hover detection
    // For now, we just handle document-level events
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
