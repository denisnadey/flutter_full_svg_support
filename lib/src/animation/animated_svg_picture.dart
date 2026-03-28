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
part 'animated_svg_picture_diagnostics.dart';
part 'animated_svg_picture_foreign_object.dart';
part 'animated_svg_picture_types.dart';
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
part 'animated_svg_picture_event_model.dart';
part 'animated_svg_picture_hit_test_advanced.dart';

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
    this.foreignObjectBuilder,
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

  /// Optional builder for rendering custom content inside foreignObject elements.
  /// If provided, this callback is invoked for each foreignObject element.
  /// Return a Widget to render custom content, or null to skip rendering.
  /// This is useful for embedding Flutter widgets in place of HTML content.
  final SvgForeignObjectBuilder? foreignObjectBuilder;

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
    _handleWidgetUpdate(oldWidget);
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
  Widget build(BuildContext context) => _buildWidget(context);

  /// Запустить анимацию
  void play() => _play();

  /// Остановить анимацию
  void pause() => _pause();

  /// Перейти к началу
  void reset() => _reset();

  /// Перейти к конкретному времени
  void seekTo(Duration time) => _seekTo(time);
}
