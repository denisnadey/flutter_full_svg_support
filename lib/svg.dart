import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'src/animation/animated_svg_picture.dart';
import 'src/animation/animation_detector.dart';
import 'src/cache.dart';
import 'src/default_theme.dart';
import 'src/loaders.dart';
import 'src/rendering_strategy.dart';
import 'src/svg_theme.dart';
import 'src/utilities/file.dart';

export 'src/cache.dart';
export 'src/default_theme.dart';
export 'src/loaders.dart';
export 'src/rendering_strategy.dart';
export 'src/render_svg.dart';
export 'src/svg_theme.dart';

/// Builder function to create an error widget. This builder is called when
/// the image failed loading.
typedef SvgErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

/// Instance for [Svg]'s utility methods, which can produce a [DrawableRoot]
/// or [PictureInfo] from [String] or [Uint8List].
final Svg svg = Svg._();

/// A utility class for decoding SVG data to a [DrawableRoot] or a [PictureInfo].
///
/// These methods are used by [SvgPicture], but can also be directly used e.g.
/// to create a [DrawableRoot] you manipulate or render to your own [Canvas].
/// Access to this class is provided by the exported [svg] member.
class Svg {
  Svg._();

  /// A global override flag for [SvgPicture.cacheColorFilter].
  ///
  /// If this is null, the value in [SvgPicture.cacheColorFilter] is used. If it
  /// is not null, it will override that value.
  @Deprecated('This no longer does anything.')
  bool? cacheColorFilterOverride;

  /// The cache instance for decoded SVGs.
  final Cache cache = Cache();
}

// ignore: avoid_classes_with_only_static_members
/// Deprecated class, will be removed, does not do anything.
@Deprecated('This feature does not do anything anymore.')
class PictureProvider {
  /// Deprecated, use [svg.cache] instead.
  @Deprecated('Use svg.cache instead.')
  static Cache get cache => svg.cache;
}

enum _FSvgSourceType { string, asset, network, file, memory }

/// A unified SVG widget that auto-selects static or animated rendering.
///
/// If animation markers are detected (`<animate>`, CSS animation, etc.),
/// this widget uses [AnimatedSvgPicture]. Otherwise it falls back to
/// [SvgPicture].
class FSvgPicture extends StatefulWidget {
  /// Creates an auto-detected SVG from a raw SVG string.
  const FSvgPicture.string(
    String string, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    this.theme,
    this.colorMapper,
    this.renderingStrategy = RenderingStrategy.picture,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
  }) : _sourceType = _FSvgSourceType.string,
       _svgString = string,
       _assetName = null,
       _assetBundle = null,
       _package = null,
       _url = null,
       _headers = null,
       _httpClient = null,
       _file = null,
       _bytes = null;

  /// Creates an auto-detected SVG from an asset.
  const FSvgPicture.asset(
    String assetName, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    this.theme,
    this.colorMapper,
    this.renderingStrategy = RenderingStrategy.picture,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
  }) : _sourceType = _FSvgSourceType.asset,
       _svgString = null,
       _assetName = assetName,
       _assetBundle = bundle,
       _package = package,
       _url = null,
       _headers = null,
       _httpClient = null,
       _file = null,
       _bytes = null;

  /// Creates an auto-detected SVG from the network.
  const FSvgPicture.network(
    String url, {
    super.key,
    Map<String, String>? headers,
    http.Client? httpClient,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    this.theme,
    this.colorMapper,
    this.renderingStrategy = RenderingStrategy.picture,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
  }) : _sourceType = _FSvgSourceType.network,
       _svgString = null,
       _assetName = null,
       _assetBundle = null,
       _package = null,
       _url = url,
       _headers = headers,
       _httpClient = httpClient,
       _file = null,
       _bytes = null;

  /// Creates an auto-detected SVG from a file.
  const FSvgPicture.file(
    File file, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    this.theme,
    this.colorMapper,
    this.renderingStrategy = RenderingStrategy.picture,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
  }) : _sourceType = _FSvgSourceType.file,
       _svgString = null,
       _assetName = null,
       _assetBundle = null,
       _package = null,
       _url = null,
       _headers = null,
       _httpClient = null,
       _file = file,
       _bytes = null;

  /// Creates an auto-detected SVG from UTF-8 bytes.
  const FSvgPicture.memory(
    Uint8List bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    this.theme,
    this.colorMapper,
    this.renderingStrategy = RenderingStrategy.picture,
    this.backgroundColor,
    this.playbackRate = 1.0,
    this.autoPlay = true,
    this.initialTime,
  }) : _sourceType = _FSvgSourceType.memory,
       _svgString = null,
       _assetName = null,
       _assetBundle = null,
       _package = null,
       _url = null,
       _headers = null,
       _httpClient = null,
       _file = null,
       _bytes = bytes;

  /// The width of the rendered SVG.
  final double? width;

  /// The height of the rendered SVG.
  final double? height;

  /// How to inscribe the picture into the space allocated during layout.
  final BoxFit fit;

  /// How to align the picture within its parent widget.
  final AlignmentGeometry alignment;

  /// Flips picture horizontally in RTL contexts.
  final bool matchTextDirection;

  /// Whether to allow drawing outside the viewBox bounds.
  final bool allowDrawingOutsideViewBox;

  /// Placeholder while source is loading.
  final WidgetBuilder? placeholderBuilder;

  /// Color filter to apply to rendered output.
  final ColorFilter? colorFilter;

  /// Semantics label for accessibility.
  final String? semanticsLabel;

  /// Whether to exclude this picture from semantics.
  final bool excludeFromSemantics;

  /// Clip behavior for static rendering.
  final Clip clipBehavior;

  /// Error widget builder for source loading/parsing failures.
  final SvgErrorWidgetBuilder? errorBuilder;

  /// Theme used when parsing static SVG elements.
  final SvgTheme? theme;

  /// Color substitution mapper for static rendering.
  final ColorMapper? colorMapper;

  /// Static render strategy (`picture` or `raster`).
  final RenderingStrategy renderingStrategy;

  /// Background color for animated rendering.
  final Color? backgroundColor;

  /// Animated playback speed multiplier.
  final double playbackRate;

  /// Whether animation should start automatically.
  final bool autoPlay;

  /// Initial animation time for animated rendering.
  final Duration? initialTime;

  final _FSvgSourceType _sourceType;
  final String? _svgString;
  final String? _assetName;
  final AssetBundle? _assetBundle;
  final String? _package;
  final String? _url;
  final Map<String, String>? _headers;
  final http.Client? _httpClient;
  final File? _file;
  final Uint8List? _bytes;

  @override
  State<FSvgPicture> createState() => _FSvgPictureState();
}

class _FSvgPictureState extends State<FSvgPicture> {
  Future<String>? _svgFuture;
  AssetBundle? _resolvedBundle;

  @override
  void didUpdateWidget(FSvgPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sourceCacheKey(oldWidget) != _sourceCacheKey(widget)) {
      _svgFuture = null;
      _resolvedBundle = null;
    }
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return SvgPicture.defaultPlaceholderBuilder(context);
  }

  Widget _buildLoadError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, stackTrace);
    }
    return _buildDefaultPlaceholder(context);
  }

  int _headersHash(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return 0;
    }
    return Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }

  Object _sourceCacheKey(FSvgPicture picture) {
    switch (picture._sourceType) {
      case _FSvgSourceType.string:
        return Object.hash(picture._sourceType, picture._svgString);
      case _FSvgSourceType.asset:
        return Object.hash(
          picture._sourceType,
          picture._assetName,
          picture._package,
          picture._assetBundle,
        );
      case _FSvgSourceType.network:
        return Object.hash(
          picture._sourceType,
          picture._url,
          _headersHash(picture._headers),
          picture._httpClient,
        );
      case _FSvgSourceType.file:
        return Object.hash(picture._sourceType, picture._file?.path);
      case _FSvgSourceType.memory:
        return Object.hash(
          picture._sourceType,
          picture._bytes == null ? 0 : Object.hashAll(picture._bytes),
        );
    }
  }

  Future<String> _loadSvgString(BuildContext context) {
    switch (widget._sourceType) {
      case _FSvgSourceType.string:
        return SynchronousFuture<String>(widget._svgString!);
      case _FSvgSourceType.memory:
        return SynchronousFuture<String>(
          utf8.decode(widget._bytes!, allowMalformed: true),
        );
      case _FSvgSourceType.asset:
        final bundle = widget._assetBundle ?? DefaultAssetBundle.of(context);
        final key = widget._package == null
            ? widget._assetName!
            : 'packages/${widget._package}/${widget._assetName}';
        return bundle.loadString(key);
      case _FSvgSourceType.network:
        final client = widget._httpClient ?? http.Client();
        return client
            .get(Uri.parse(widget._url!), headers: widget._headers)
            .then((response) {
              return utf8.decode(response.bodyBytes, allowMalformed: true);
            })
            .whenComplete(() {
              if (widget._httpClient == null) {
                client.close();
              }
            });
      case _FSvgSourceType.file:
        return widget._file!.readAsBytes().then(
          (bytes) => utf8.decode(bytes, allowMalformed: true),
        );
    }
  }

  Future<String> _ensureSvgFuture(BuildContext context) {
    if (widget._sourceType == _FSvgSourceType.asset) {
      final bundle = widget._assetBundle ?? DefaultAssetBundle.of(context);
      if (_svgFuture == null || !identical(bundle, _resolvedBundle)) {
        _resolvedBundle = bundle;
        _svgFuture = _loadSvgString(context);
      }
      return _svgFuture!;
    }

    _svgFuture ??= _loadSvgString(context);
    return _svgFuture!;
  }

  Alignment _resolveAnimatedAlignment(BuildContext context) {
    final alignment = widget.alignment;
    if (alignment is Alignment) {
      return alignment;
    }
    if (alignment is AlignmentDirectional) {
      return alignment.resolve(Directionality.maybeOf(context));
    }
    return Alignment.center;
  }

  Widget _buildAnimated(BuildContext context, String svgString) {
    Widget animated = AnimatedSvgPicture.string(
      svgString,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: _resolveAnimatedAlignment(context),
      backgroundColor: widget.backgroundColor,
      playbackRate: widget.playbackRate,
      autoPlay: widget.autoPlay,
      initialTime: widget.initialTime,
      theme: widget.theme,
      colorMapper: widget.colorMapper,
    );

    if (widget.colorFilter != null) {
      animated = ColorFiltered(
        colorFilter: widget.colorFilter!,
        child: animated,
      );
    }

    final textDirection = Directionality.maybeOf(context);
    final shouldFlip =
        widget.matchTextDirection &&
        textDirection != null &&
        textDirection == TextDirection.rtl;
    if (shouldFlip) {
      animated = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: animated,
      );
    }

    if (!widget.excludeFromSemantics && widget.semanticsLabel != null) {
      animated = Semantics(
        label: widget.semanticsLabel,
        image: true,
        child: animated,
      );
    }

    if (!widget.allowDrawingOutsideViewBox &&
        widget.clipBehavior != Clip.none) {
      animated = ClipRect(clipBehavior: widget.clipBehavior, child: animated);
    }

    return animated;
  }

  Widget _buildResolvedSvg(BuildContext context, String svgString) {
    if (AnimationDetector.hasAnimations(svgString)) {
      return _buildAnimated(context, svgString);
    }

    return SvgPicture.string(
      svgString,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      matchTextDirection: widget.matchTextDirection,
      allowDrawingOutsideViewBox: widget.allowDrawingOutsideViewBox,
      placeholderBuilder: widget.placeholderBuilder,
      colorFilter: widget.colorFilter,
      semanticsLabel: widget.semanticsLabel,
      excludeFromSemantics: widget.excludeFromSemantics,
      clipBehavior: widget.clipBehavior,
      errorBuilder: widget.errorBuilder,
      theme: widget.theme,
      colorMapper: widget.colorMapper,
      renderingStrategy: widget.renderingStrategy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSyncSource =
        widget._sourceType == _FSvgSourceType.string ||
        widget._sourceType == _FSvgSourceType.memory;

    if (isSyncSource) {
      final svgString = widget._sourceType == _FSvgSourceType.string
          ? widget._svgString!
          : utf8.decode(widget._bytes!, allowMalformed: true);
      return _buildResolvedSvg(context, svgString);
    }

    return FutureBuilder<String>(
      future: _ensureSvgFuture(context),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildLoadError(
            context,
            snapshot.error!,
            snapshot.stackTrace ?? StackTrace.current,
          );
        }

        final svgString = snapshot.data;
        if (svgString == null) {
          return widget.placeholderBuilder?.call(context) ??
              _buildDefaultPlaceholder(context);
        }

        return _buildResolvedSvg(context, svgString);
      },
    );
  }
}

/// A widget that will parse SVG data for rendering on screen.
class SvgPicture extends StatelessWidget {
  /// Instantiates a widget that renders an SVG picture using the `pictureProvider`.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time, e.g. for a network picture.
  ///
  /// The `semanticsLabel` can be used to identify the purpose of this picture for
  /// screen reading software.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  const SvgPicture(
    this.bytesLoader, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.colorFilter,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    @Deprecated(
      'No code should use this parameter. It never was implemented properly. '
      'The SVG theme must be set on the bytesLoader.',
    )
    SvgTheme? theme,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    this.renderingStrategy = RenderingStrategy.picture,
  });

  /// Instantiates a widget that renders an SVG picture from an [AssetBundle].
  ///
  /// The key will be derived from the `assetName`, `package`, and `bundle`
  /// arguments. The `package` argument must be non-null when displaying an SVG
  /// from a package and null otherwise. See the `Assets in packages` section for
  /// details.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// The `theme` argument, if provided, will override the default theme
  /// used when parsing SVG elements.
  ///
  /// ## Assets in packages
  ///
  /// To create the widget with an asset from a package, the [package] argument
  /// must be provided. For instance, suppose a package called `my_icons` has
  /// `icons/heart.svg` .
  ///
  /// Then to display the image, use:
  ///
  /// ```dart
  /// SvgPicture.asset('icons/heart.svg', package: 'my_icons')
  /// ```
  ///
  /// Assets used by the package itself should also be displayed using the
  /// [package] argument as above.
  ///
  /// If the desired asset is specified in the `pubspec.yaml` of the package, it
  /// is bundled automatically with the app. In particular, assets used by the
  /// package itself must be specified in its `pubspec.yaml`.
  ///
  /// A package can also choose to have assets in its 'lib/' folder that are not
  /// specified in its `pubspec.yaml`. In this case for those images to be
  /// bundled, the app has to specify which ones to include. For instance a
  /// package named `fancy_backgrounds` could have:
  ///
  /// ```none
  /// lib/backgrounds/background1.svg
  /// lib/backgrounds/background2.svg
  /// lib/backgrounds/background3.svg
  ///```
  ///
  /// To include, say the first image, the `pubspec.yaml` of the app should
  /// specify it in the assets section:
  ///
  /// ```yaml
  ///  assets:
  ///    - packages/fancy_backgrounds/backgrounds/background1.svg
  /// ```
  ///
  /// The `lib/` is implied, so it should not be included in the asset path.
  ///
  ///
  /// See also:
  ///
  ///  * <https://flutter.io/assets-and-images/>, an introduction to assets in
  ///    Flutter.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  SvgPicture.asset(
    String assetName, {
    super.key,
    this.matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    SvgTheme? theme,
    ColorMapper? colorMapper,
    ui.ColorFilter? colorFilter,
    @Deprecated('Use colorFilter instead.') ui.Color? color,
    @Deprecated('Use colorFilter instead.')
    ui.BlendMode colorBlendMode = ui.BlendMode.srcIn,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    this.renderingStrategy = RenderingStrategy.picture,
  }) : bytesLoader = SvgAssetLoader(
         assetName,
         packageName: package,
         assetBundle: bundle,
         theme: theme,
         colorMapper: colorMapper,
       ),
       colorFilter = colorFilter ?? _getColorFilter(color, colorBlendMode);

  /// Creates a widget that displays an SVG obtained from the network.
  ///
  /// The [url] argument must not be null.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time, such as high latency scenarios.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// The `theme` argument, if provided, will override the default theme
  /// used when parsing SVG elements.
  ///
  /// All network images are cached regardless of HTTP headers.
  ///
  /// An optional `headers` argument can be used to send custom HTTP headers
  /// with the image request.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  SvgPicture.network(
    String url, {
    super.key,
    Map<String, String>? headers,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    ui.ColorFilter? colorFilter,
    @Deprecated('Use colorFilter instead.') ui.Color? color,
    @Deprecated('Use colorFilter instead.')
    ui.BlendMode colorBlendMode = ui.BlendMode.srcIn,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    SvgTheme? theme,
    ColorMapper? colorMapper,
    http.Client? httpClient,
    this.renderingStrategy = RenderingStrategy.picture,
  }) : bytesLoader = SvgNetworkLoader(
         url,
         headers: headers,
         theme: theme,
         colorMapper: colorMapper,
         httpClient: httpClient,
       ),
       colorFilter = colorFilter ?? _getColorFilter(color, colorBlendMode);

  /// Creates a widget that displays an SVG obtained from a [File].
  ///
  /// The [file] argument must not be null.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// The `theme` argument, if provided, will override the default theme
  /// used when parsing SVG elements.
  ///
  /// On Android, this may require the
  /// `android.permission.READ_EXTERNAL_STORAGE` permission.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  SvgPicture.file(
    File file, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    ui.ColorFilter? colorFilter,
    @Deprecated('Use colorFilter instead.') ui.Color? color,
    @Deprecated('Use colorFilter instead.')
    ui.BlendMode colorBlendMode = ui.BlendMode.srcIn,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    SvgTheme? theme,
    ColorMapper? colorMapper,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    this.renderingStrategy = RenderingStrategy.picture,
  }) : bytesLoader = SvgFileLoader(
         file,
         theme: theme,
         colorMapper: colorMapper,
       ),
       colorFilter = colorFilter ?? _getColorFilter(color, colorBlendMode);

  /// Creates a widget that displays an SVG obtained from a [Uint8List].
  ///
  /// The [bytes] argument must not be null.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// The `theme` argument, if provided, will override the default theme
  /// used when parsing SVG elements.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  SvgPicture.memory(
    Uint8List bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    ui.ColorFilter? colorFilter,
    @Deprecated('Use colorFilter instead.') ui.Color? color,
    @Deprecated('Use colorFilter instead.')
    ui.BlendMode colorBlendMode = ui.BlendMode.srcIn,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    SvgTheme? theme,
    ColorMapper? colorMapper,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    this.renderingStrategy = RenderingStrategy.picture,
  }) : bytesLoader = SvgBytesLoader(
         bytes,
         theme: theme,
         colorMapper: colorMapper,
       ),
       colorFilter = colorFilter ?? _getColorFilter(color, colorBlendMode);

  /// Creates a widget that displays an SVG obtained from a [String].
  ///
  /// The [string] argument must not be null.
  ///
  /// Either the [width] and [height] arguments should be specified, or the
  /// widget should be placed in a context that sets tight layout constraints.
  /// Otherwise, the image dimensions will change as the image is loaded, which
  /// will result in ugly layout changes.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// The `theme` argument, if provided, will override the default theme
  /// used when parsing SVG elements.
  ///
  /// If [excludeFromSemantics] is true, then [semanticsLabel] will be ignored.
  SvgPicture.string(
    String string, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.matchTextDirection = false,
    this.allowDrawingOutsideViewBox = false,
    this.placeholderBuilder,
    ui.ColorFilter? colorFilter,
    @Deprecated('Use colorFilter instead.') ui.Color? color,
    @Deprecated('Use colorFilter instead.')
    ui.BlendMode colorBlendMode = ui.BlendMode.srcIn,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.clipBehavior = Clip.hardEdge,
    this.errorBuilder,
    SvgTheme? theme,
    ColorMapper? colorMapper,
    @Deprecated('This no longer does anything.') bool cacheColorFilter = false,
    this.renderingStrategy = RenderingStrategy.picture,
  }) : bytesLoader = SvgStringLoader(
         string,
         theme: theme,
         colorMapper: colorMapper,
       ),
       colorFilter = colorFilter ?? _getColorFilter(color, colorBlendMode);

  static ColorFilter? _getColorFilter(
    ui.Color? color,
    ui.BlendMode colorBlendMode,
  ) => color == null ? null : ui.ColorFilter.mode(color, colorBlendMode);

  /// The default placeholder for a SVG that may take time to parse or
  /// retrieve, e.g. from a network location.
  static WidgetBuilder defaultPlaceholderBuilder = (BuildContext ctx) =>
      const LimitedBox();

  /// If specified, the width to use for the SVG.  If unspecified, the SVG
  /// will take the width of its parent.
  final double? width;

  /// If specified, the height to use for the SVG.  If unspecified, the SVG
  /// will take the height of its parent.
  final double? height;

  /// How to inscribe the picture into the space allocated during layout.
  /// The default is [BoxFit.contain].
  final BoxFit fit;

  /// How to align the picture within its parent widget.
  ///
  /// The alignment aligns the given position in the picture to the given position
  /// in the layout bounds. For example, an [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// picture with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then a [TextDirection] must be available
  /// when the picture is painted.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final AlignmentGeometry alignment;

  /// The [BytesLoader] used to resolve the SVG.
  final BytesLoader bytesLoader;

  /// The placeholder to use while fetching, decoding, and parsing the SVG data.
  final WidgetBuilder? placeholderBuilder;

  /// If true, will horizontally flip the picture in [TextDirection.rtl] contexts.
  final bool matchTextDirection;

  /// If true, will allow the SVG to be drawn outside of the clip boundary of its
  /// viewBox.
  final bool allowDrawingOutsideViewBox;

  /// The [Semantics.label] for this picture.
  ///
  /// The value indicates the purpose of the picture, and will be
  /// read out by screen readers.
  final String? semanticsLabel;

  /// Whether to exclude this picture from semantics.
  ///
  /// Useful for pictures which do not contribute meaningful information to an
  /// application.
  final bool excludeFromSemantics;

  /// The content will be clipped (or not) according to this option.
  ///
  /// See the enum [Clip] for details of all possible options and their common
  /// use cases.
  ///
  /// Defaults to [Clip.hardEdge], and must not be null.
  final Clip clipBehavior;

  /// Widget displayed while the target image failed loading.
  final SvgErrorWidgetBuilder? errorBuilder;

  /// The color filter, if any, to apply to this widget.
  final ColorFilter? colorFilter;

  /// Widget rendering strategy used to balance flexibility and performance.
  ///
  /// See the enum [RenderingStrategy] for details of all possible options and their common
  /// use cases.
  ///
  /// Defaults to [RenderingStrategy.picture].
  final RenderingStrategy renderingStrategy;

  @override
  Widget build(BuildContext context) {
    return _StaticSvgView(
      loader: bytesLoader,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      matchTextDirection: matchTextDirection,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      colorFilter: colorFilter,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      clipBehavior: clipBehavior,
      errorBuilder: errorBuilder,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties
      ..add(
        StringProperty('bytesLoader', bytesLoader.toString(), showName: false),
      )
      ..add(DoubleProperty('width', width, defaultValue: null))
      ..add(DoubleProperty('height', height, defaultValue: null))
      ..add(
        DiagnosticsProperty<AlignmentGeometry>(
          'alignment',
          alignment,
          defaultValue: Alignment.center,
        ),
      )
      ..add(
        DiagnosticsProperty<bool>(
          'allowDrawingOutsideViewBox',
          allowDrawingOutsideViewBox,
          defaultValue: false,
        ),
      )
      ..add(
        EnumProperty<Clip>(
          'clipBehavior',
          clipBehavior,
          defaultValue: BoxFit.contain,
        ),
      )
      ..add(
        StringProperty(
          'colorFilter',
          colorFilter.toString(),
          defaultValue: null,
        ),
      )
      ..add(EnumProperty<BoxFit>('fit', fit, defaultValue: BoxFit.contain))
      ..add(
        DiagnosticsProperty<Function>(
          'placeholderBuilder',
          placeholderBuilder,
          defaultValue: null,
        ),
      )
      ..add(
        DiagnosticsProperty<bool>(
          'matchTextDirection',
          matchTextDirection,
          defaultValue: false,
        ),
      )
      ..add(
        DiagnosticsProperty<bool>(
          'excludeFromSemantics',
          excludeFromSemantics,
          defaultValue: false,
        ),
      )
      ..add(
        StringProperty('semanticsLabel', semanticsLabel, defaultValue: null),
      );
  }
}

/// Resolves a [BytesLoader], parses the SVG, and renders it statically through
/// the shared rendering engine.
///
/// This is the rendering backend of [SvgPicture]. Animated SVG content is
/// rendered at its first frame ([AnimatedSvgPicture] with `autoPlay: false`).
class _StaticSvgView extends StatefulWidget {
  const _StaticSvgView({
    required this.loader,
    required this.width,
    required this.height,
    required this.fit,
    required this.alignment,
    required this.matchTextDirection,
    required this.allowDrawingOutsideViewBox,
    required this.placeholderBuilder,
    required this.colorFilter,
    required this.semanticsLabel,
    required this.excludeFromSemantics,
    required this.clipBehavior,
    required this.errorBuilder,
  });

  final BytesLoader loader;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool matchTextDirection;
  final bool allowDrawingOutsideViewBox;
  final WidgetBuilder? placeholderBuilder;
  final ColorFilter? colorFilter;
  final String? semanticsLabel;
  final bool excludeFromSemantics;
  final Clip clipBehavior;
  final SvgErrorWidgetBuilder? errorBuilder;

  @override
  State<_StaticSvgView> createState() => _StaticSvgViewState();
}

class _StaticSvgViewState extends State<_StaticSvgView> {
  Future<ByteData>? _future;
  Object? _cacheKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _StaticSvgView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _future = null;
      _cacheKey = null;
    }
    _ensureFuture();
  }

  void _ensureFuture() {
    final Object key = widget.loader.cacheKey(context);
    if (_future == null || key != _cacheKey) {
      _cacheKey = key;
      _future = widget.loader.loadBytes(context);
    }
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return SvgPicture.defaultPlaceholderBuilder(context);
  }

  Alignment _resolveAlignment(BuildContext context) {
    final AlignmentGeometry alignment = widget.alignment;
    if (alignment is Alignment) {
      return alignment;
    }
    return alignment.resolve(Directionality.maybeOf(context));
  }

  Widget _buildResolved(BuildContext context, ByteData data) {
    final String source = utf8.decode(
      Uint8List.sublistView(data),
      allowMalformed: true,
    );

    final BytesLoader loader = widget.loader;
    final SvgTheme? theme =
        (loader is SvgLoader ? loader.theme : null) ??
        DefaultSvgTheme.of(context)?.theme;
    final ColorMapper? colorMapper = loader is SvgLoader
        ? loader.colorMapper
        : null;

    Widget result = AnimatedSvgPicture.string(
      source,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: _resolveAlignment(context),
      autoPlay: false,
      theme: theme,
      colorMapper: colorMapper,
      clipToViewBox: !widget.allowDrawingOutsideViewBox,
    );

    if (widget.colorFilter != null) {
      result = ColorFiltered(colorFilter: widget.colorFilter!, child: result);
    }

    if (widget.matchTextDirection &&
        Directionality.maybeOf(context) == TextDirection.rtl) {
      result = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: result,
      );
    }

    if (widget.excludeFromSemantics) {
      result = ExcludeSemantics(child: result);
    } else if (widget.semanticsLabel != null) {
      result = Semantics(
        label: widget.semanticsLabel,
        image: true,
        child: result,
      );
    }

    if (!widget.allowDrawingOutsideViewBox &&
        widget.clipBehavior != Clip.none) {
      result = ClipRect(clipBehavior: widget.clipBehavior, child: result);
    }

    return RepaintBoundary(child: result);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ByteData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error!,
              snapshot.stackTrace ?? StackTrace.current,
            );
          }
          return _buildDefaultPlaceholder(context);
        }
        final ByteData? data = snapshot.data;
        if (data == null) {
          return widget.placeholderBuilder?.call(context) ??
              _buildDefaultPlaceholder(context);
        }
        return _buildResolved(context, data);
      },
    );
  }
}
