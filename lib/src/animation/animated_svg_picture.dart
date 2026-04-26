import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'animated_svg_controller.dart';
import 'animated_svg_painter.dart';
import 'animation_detector.dart';
import 'css_variables_calc.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'svg_font_registry.dart' show SvgFontLoader;
import 'switch_processing.dart';
import 'smil/smil_parser.dart';
import 'smil/smil_timeline.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';
import 'svg_parser.dart';
import 'svg_transform.dart';
import 'transform_3d.dart';
import '../utilities/file.dart';

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

/// Builder function to create an error widget for animated SVG loading errors.
typedef AnimatedSvgErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

/// Optional callback for loading external image bytes referenced by <image> href.
///
/// Returning null delegates loading to default bundle/network/data-uri logic.
typedef SvgImageLoader = Future<Uint8List?> Function(String href);

/// A widget that renders an animated SVG using the SMIL/CSS animation engine.
///
/// Similar API to [SvgPicture], but supports SMIL animations, CSS animations,
/// SVG filters, interactive hit-testing, and accessibility.
///
/// Example:
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
  /// Creates an animated SVG from a raw SVG string.
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
    this.imageLoader,
    this.fontLoader,
  }) : _svgString = svgString;

  /// Creates an animated SVG from an asset.
  factory AnimatedSvgPicture.asset(
    String assetName, {
    Key? key,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Color? backgroundColor,
    double playbackRate = 1.0,
    bool autoPlay = true,
    Duration? initialTime,
    AnimatedSvgController? controller,
    SvgTraceCallback? onTrace,
    bool traceFrameTicks = false,
    SvgLinkTapCallback? onLinkTap,
    SvgForeignObjectBuilder? foreignObjectBuilder,
    SvgImageLoader? imageLoader,
    SvgFontLoader? fontLoader,
    WidgetBuilder? placeholderBuilder,
    AnimatedSvgErrorWidgetBuilder? errorBuilder,
  }) {
    return _DeferredAnimatedSvgPicture.asset(
      assetName,
      key: key,
      bundle: bundle,
      package: package,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      backgroundColor: backgroundColor,
      playbackRate: playbackRate,
      autoPlay: autoPlay,
      initialTime: initialTime,
      controller: controller,
      onTrace: onTrace,
      traceFrameTicks: traceFrameTicks,
      onLinkTap: onLinkTap,
      foreignObjectBuilder: foreignObjectBuilder,
      imageLoader: imageLoader,
      fontLoader: fontLoader,
      placeholderBuilder: placeholderBuilder,
      errorBuilder: errorBuilder,
    );
  }

  /// Creates an animated SVG from the network.
  factory AnimatedSvgPicture.network(
    String url, {
    Key? key,
    Map<String, String>? headers,
    http.Client? httpClient,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Color? backgroundColor,
    double playbackRate = 1.0,
    bool autoPlay = true,
    Duration? initialTime,
    AnimatedSvgController? controller,
    SvgTraceCallback? onTrace,
    bool traceFrameTicks = false,
    SvgLinkTapCallback? onLinkTap,
    SvgForeignObjectBuilder? foreignObjectBuilder,
    SvgImageLoader? imageLoader,
    SvgFontLoader? fontLoader,
    WidgetBuilder? placeholderBuilder,
    AnimatedSvgErrorWidgetBuilder? errorBuilder,
  }) {
    return _DeferredAnimatedSvgPicture.network(
      url,
      key: key,
      headers: headers,
      httpClient: httpClient,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      backgroundColor: backgroundColor,
      playbackRate: playbackRate,
      autoPlay: autoPlay,
      initialTime: initialTime,
      controller: controller,
      onTrace: onTrace,
      traceFrameTicks: traceFrameTicks,
      onLinkTap: onLinkTap,
      foreignObjectBuilder: foreignObjectBuilder,
      imageLoader: imageLoader,
      fontLoader: fontLoader,
      placeholderBuilder: placeholderBuilder,
      errorBuilder: errorBuilder,
    );
  }

  /// Creates an animated SVG from a file.
  factory AnimatedSvgPicture.file(
    File file, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Color? backgroundColor,
    double playbackRate = 1.0,
    bool autoPlay = true,
    Duration? initialTime,
    AnimatedSvgController? controller,
    SvgTraceCallback? onTrace,
    bool traceFrameTicks = false,
    SvgLinkTapCallback? onLinkTap,
    SvgForeignObjectBuilder? foreignObjectBuilder,
    SvgImageLoader? imageLoader,
    SvgFontLoader? fontLoader,
    WidgetBuilder? placeholderBuilder,
    AnimatedSvgErrorWidgetBuilder? errorBuilder,
  }) {
    return _DeferredAnimatedSvgPicture.file(
      file,
      key: key,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      backgroundColor: backgroundColor,
      playbackRate: playbackRate,
      autoPlay: autoPlay,
      initialTime: initialTime,
      controller: controller,
      onTrace: onTrace,
      traceFrameTicks: traceFrameTicks,
      onLinkTap: onLinkTap,
      foreignObjectBuilder: foreignObjectBuilder,
      imageLoader: imageLoader,
      fontLoader: fontLoader,
      placeholderBuilder: placeholderBuilder,
      errorBuilder: errorBuilder,
    );
  }

  /// Creates an animated SVG from bytes.
  factory AnimatedSvgPicture.memory(
    Uint8List bytes, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Color? backgroundColor,
    double playbackRate = 1.0,
    bool autoPlay = true,
    Duration? initialTime,
    AnimatedSvgController? controller,
    SvgTraceCallback? onTrace,
    bool traceFrameTicks = false,
    SvgLinkTapCallback? onLinkTap,
    SvgForeignObjectBuilder? foreignObjectBuilder,
    SvgImageLoader? imageLoader,
    SvgFontLoader? fontLoader,
    WidgetBuilder? placeholderBuilder,
    AnimatedSvgErrorWidgetBuilder? errorBuilder,
  }) {
    return _DeferredAnimatedSvgPicture.memory(
      bytes,
      key: key,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      backgroundColor: backgroundColor,
      playbackRate: playbackRate,
      autoPlay: autoPlay,
      initialTime: initialTime,
      controller: controller,
      onTrace: onTrace,
      traceFrameTicks: traceFrameTicks,
      onLinkTap: onLinkTap,
      foreignObjectBuilder: foreignObjectBuilder,
      imageLoader: imageLoader,
      fontLoader: fontLoader,
      placeholderBuilder: placeholderBuilder,
      errorBuilder: errorBuilder,
    );
  }

  /// The raw SVG string to render.
  final String _svgString;

  /// The width of the rendered widget.
  final double? width;

  /// The height of the rendered widget.
  final double? height;

  /// How to inscribe the SVG into the space allocated during layout.
  final BoxFit fit;

  /// How to align the SVG within its parent widget.
  final Alignment alignment;

  /// Background color painted behind the SVG.
  final Color? backgroundColor;

  /// Playback speed multiplier (1.0 = normal speed, 2.0 = double speed).
  final double playbackRate;

  /// Whether to start playback automatically when the widget is mounted.
  final bool autoPlay;

  /// Initial animation time offset, useful for testing or previewing a frame.
  final Duration? initialTime;

  /// Controller for programmatic playback control.
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

  /// Optional callback to resolve external image bytes for <image> href values.
  final SvgImageLoader? imageLoader;

  /// Optional callback to resolve external font bytes for @font-face src URLs.
  final SvgFontLoader? fontLoader;

  @override
  State<AnimatedSvgPicture> createState() => _AnimatedSvgPictureState();
}

class _DeferredAnimatedSvgPicture extends AnimatedSvgPicture {
  _DeferredAnimatedSvgPicture.asset(
    String assetName, {
    super.key,
    AssetBundle? bundle,
    String? package,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.backgroundColor,
    super.playbackRate,
    super.autoPlay,
    super.initialTime,
    super.controller,
    super.onTrace,
    super.traceFrameTicks,
    super.onLinkTap,
    super.foreignObjectBuilder,
    super.imageLoader,
    super.fontLoader,
    this.placeholderBuilder,
    this.errorBuilder,
  }) : _loadSvg = ((BuildContext context) {
         final resolvedBundle = bundle ?? DefaultAssetBundle.of(context);
         final key = package == null
             ? assetName
             : 'packages/$package/$assetName';
         return resolvedBundle.loadString(key);
       }),
       _cacheKey = Object.hash(assetName, package, bundle),
       _usesDefaultBundle = bundle == null,
       super.string('');

  _DeferredAnimatedSvgPicture.network(
    String url, {
    super.key,
    Map<String, String>? headers,
    http.Client? httpClient,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.backgroundColor,
    super.playbackRate,
    super.autoPlay,
    super.initialTime,
    super.controller,
    super.onTrace,
    super.traceFrameTicks,
    super.onLinkTap,
    super.foreignObjectBuilder,
    super.imageLoader,
    super.fontLoader,
    this.placeholderBuilder,
    this.errorBuilder,
  }) : _loadSvg = ((BuildContext context) async {
         final client = httpClient ?? http.Client();
         try {
           final response = await client.get(Uri.parse(url), headers: headers);
           return utf8.decode(response.bodyBytes, allowMalformed: true);
         } finally {
           if (httpClient == null) {
             client.close();
           }
         }
       }),
       _cacheKey = Object.hash(url, _mapHash(headers), httpClient),
       _usesDefaultBundle = false,
       super.string('');

  _DeferredAnimatedSvgPicture.file(
    File file, {
    super.key,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.backgroundColor,
    super.playbackRate,
    super.autoPlay,
    super.initialTime,
    super.controller,
    super.onTrace,
    super.traceFrameTicks,
    super.onLinkTap,
    super.foreignObjectBuilder,
    super.imageLoader,
    super.fontLoader,
    this.placeholderBuilder,
    this.errorBuilder,
  }) : _loadSvg = ((BuildContext context) async {
         final bytes = await file.readAsBytes();
         return utf8.decode(bytes, allowMalformed: true);
       }),
       _cacheKey = file.path,
       _usesDefaultBundle = false,
       super.string('');

  _DeferredAnimatedSvgPicture.memory(
    Uint8List bytes, {
    super.key,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.backgroundColor,
    super.playbackRate,
    super.autoPlay,
    super.initialTime,
    super.controller,
    super.onTrace,
    super.traceFrameTicks,
    super.onLinkTap,
    super.foreignObjectBuilder,
    super.imageLoader,
    super.fontLoader,
    this.placeholderBuilder,
    this.errorBuilder,
  }) : _loadSvg = ((BuildContext context) {
         return Future<String>.value(utf8.decode(bytes, allowMalformed: true));
       }),
       _cacheKey = Object.hashAll(bytes),
       _usesDefaultBundle = false,
       super.string('');

  final Future<String> Function(BuildContext context) _loadSvg;
  final Object _cacheKey;
  final bool _usesDefaultBundle;
  final WidgetBuilder? placeholderBuilder;
  final AnimatedSvgErrorWidgetBuilder? errorBuilder;

  static int _mapHash(Map<String, String>? map) {
    if (map == null || map.isEmpty) {
      return 0;
    }
    return Object.hashAllUnordered(
      map.entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }

  @override
  State<AnimatedSvgPicture> createState() => _DeferredAnimatedSvgPictureState();
}

class _DeferredAnimatedSvgPictureState
    extends State<_DeferredAnimatedSvgPicture> {
  Future<String>? _svgFuture;
  AssetBundle? _resolvedBundle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._usesDefaultBundle) {
      final currentBundle = DefaultAssetBundle.of(context);
      if (!identical(currentBundle, _resolvedBundle)) {
        _resolvedBundle = currentBundle;
        _svgFuture = widget._loadSvg(context);
      }
    } else {
      _svgFuture ??= widget._loadSvg(context);
    }
  }

  @override
  void didUpdateWidget(covariant _DeferredAnimatedSvgPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._cacheKey != widget._cacheKey ||
        oldWidget._usesDefaultBundle != widget._usesDefaultBundle) {
      _resolvedBundle = null;
      _svgFuture = null;
    }
  }

  Widget _buildDefaultPlaceholder() {
    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return const LimitedBox();
  }

  @override
  Widget build(BuildContext context) {
    _svgFuture ??= widget._loadSvg(context);
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error!,
              snapshot.stackTrace ?? StackTrace.current,
            );
          }
          return _buildDefaultPlaceholder();
        }

        final svgString = snapshot.data;
        if (svgString == null) {
          return widget.placeholderBuilder?.call(context) ??
              _buildDefaultPlaceholder();
        }

        return AnimatedSvgPicture.string(
          svgString,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          backgroundColor: widget.backgroundColor,
          playbackRate: widget.playbackRate,
          autoPlay: widget.autoPlay,
          initialTime: widget.initialTime,
          controller: widget.controller,
          onTrace: widget.onTrace,
          traceFrameTicks: widget.traceFrameTicks,
          onLinkTap: widget.onLinkTap,
          foreignObjectBuilder: widget.foreignObjectBuilder,
          imageLoader: widget.imageLoader,
          fontLoader: widget.fontLoader,
        );
      },
    );
  }
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
  final Map<String, ui.Image> _convolvedImagesByFilterKey =
      <String, ui.Image>{};
  final Map<String, ui.Image> _lightingImagesByFilterKey = <String, ui.Image>{};
  final Map<String, ui.Image> _displacementImagesByFilterKey =
      <String, ui.Image>{};
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
    // Subscribe to controller changes
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

  /// Starts or resumes playback.
  void play() => _play();

  /// Pauses playback.
  void pause() => _pause();

  /// Resets playback to the beginning.
  void reset() => _reset();

  /// Seeks to the given animation time.
  void seekTo(Duration time) => _seekTo(time);
}
