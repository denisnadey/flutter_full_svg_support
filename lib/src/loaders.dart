import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../svg.dart' show svg;
import 'default_theme.dart';
import 'svg_theme.dart';
import 'utilities/file.dart';

/// Resolves the raw bytes of an SVG document for an [SvgPicture].
///
/// Earlier versions of this package re-exported `BytesLoader` from the
/// `vector_graphics` package, where the bytes were a compiled binary vector
/// format. `full_svg_flutter` now parses SVG directly, so [loadBytes] returns
/// the UTF-8 encoded SVG source.
@immutable
abstract class BytesLoader {
  /// Allows const constructors on subclasses.
  const BytesLoader();

  /// Loads the UTF-8 encoded SVG source for this loader.
  Future<ByteData> loadBytes(BuildContext? context);

  /// An object that uniquely identifies the SVG resolved by this loader.
  ///
  /// Used as the key into the shared decode cache ([svg]'s `cache`).
  Object cacheKey(BuildContext? context);
}

/// A [BytesLoader] that resolves an SVG document and caches its UTF-8 source.
@immutable
abstract class SvgLoader<T> extends BytesLoader {
  /// See class doc.
  const SvgLoader({this.theme, this.colorMapper});

  /// The theme controlling `currentColor` and font-relative units.
  final SvgTheme? theme;

  /// The [ColorMapper] used to substitute colors in the SVG, if any.
  final ColorMapper? colorMapper;

  /// Returns the SVG source for the prepared [message].
  ///
  /// Called with the result of [prepareMessage].
  @protected
  String provideSvg(T? message);

  /// Performs any asynchronous work (asset/network/file IO) needed before
  /// [provideSvg] can run.
  @protected
  Future<T?> prepareMessage(BuildContext? context) =>
      SynchronousFuture<T?>(null);

  /// Resolves the effective [SvgTheme] for this loader.
  @visibleForTesting
  @protected
  SvgTheme getTheme(BuildContext? context) {
    if (theme != null) {
      return theme!;
    }
    if (context != null) {
      final SvgTheme? defaultTheme = DefaultSvgTheme.of(context)?.theme;
      if (defaultTheme != null) {
        return defaultTheme;
      }
    }
    return const SvgTheme();
  }

  Future<ByteData> _load(BuildContext? context) {
    return prepareMessage(context).then((T? message) {
      final Uint8List bytes = utf8.encode(provideSvg(message));
      return bytes.buffer.asByteData(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    });
  }

  /// This method intentionally avoids using `await` to avoid unnecessary
  /// event loop turns. This helps tests in particular.
  @override
  Future<ByteData> loadBytes(BuildContext? context) {
    return svg.cache.putIfAbsent(cacheKey(context), () => _load(context));
  }

  @override
  SvgCacheKey cacheKey(BuildContext? context) {
    final SvgTheme theme = getTheme(context);
    return SvgCacheKey(keyData: this, theme: theme, colorMapper: colorMapper);
  }
}

/// A theme- and color-mapper-aware cache key.
///
/// The theme must be part of the cache key so otherwise-identical SVGs that
/// are rendered with a different theme are cached separately.
@immutable
class SvgCacheKey {
  /// See [SvgCacheKey].
  const SvgCacheKey({
    required this.keyData,
    required this.colorMapper,
    this.theme,
  });

  /// The theme for this cached SVG.
  final SvgTheme? theme;

  /// The other key data for the SVG.
  ///
  /// For most loaders, using the loader object itself is suitable.
  final Object keyData;

  /// The color mapper for the SVG, if any.
  final ColorMapper? colorMapper;

  @override
  int get hashCode => Object.hash(theme, keyData, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgCacheKey &&
        other.theme == theme &&
        other.keyData == keyData &&
        other.colorMapper == colorMapper;
  }
}

/// A [BytesLoader] that resolves an SVG from a raw string.
class SvgStringLoader extends SvgLoader<void> {
  /// See class doc.
  const SvgStringLoader(this._svg, {super.theme, super.colorMapper});

  final String _svg;

  @override
  String provideSvg(void message) {
    return _svg;
  }

  @override
  int get hashCode => Object.hash(_svg, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgStringLoader &&
        other._svg == _svg &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }
}

/// A [BytesLoader] that resolves an SVG from a UTF-8 encoded [Uint8List].
class SvgBytesLoader extends SvgLoader<void> {
  /// See class doc.
  const SvgBytesLoader(this.bytes, {super.theme, super.colorMapper});

  /// The UTF-8 encoded XML bytes.
  final Uint8List bytes;

  @override
  String provideSvg(void message) => utf8.decode(bytes, allowMalformed: true);

  @override
  int get hashCode => Object.hash(bytes, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgBytesLoader &&
        other.bytes == bytes &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }
}

/// A [BytesLoader] that resolves an SVG from a file.
class SvgFileLoader extends SvgLoader<void> {
  /// See class doc.
  const SvgFileLoader(this.file, {super.theme, super.colorMapper});

  /// The file containing the SVG data to decode and render.
  final File file;

  @override
  String provideSvg(void message) {
    final Uint8List bytes = file.readAsBytesSync();
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  int get hashCode => Object.hash(file, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgFileLoader &&
        other.file == file &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }
}

// Replaces the cache key for [SvgAssetLoader] to account for the fact that
// different widgets may select a different asset bundle based on the return
// value of `DefaultAssetBundle.of(context)`.
@immutable
class _AssetByteLoaderCacheKey {
  const _AssetByteLoaderCacheKey(
    this.assetName,
    this.packageName,
    this.assetBundle,
  );

  final String assetName;
  final String? packageName;

  final AssetBundle assetBundle;

  @override
  int get hashCode => Object.hash(assetName, packageName, assetBundle);

  @override
  bool operator ==(Object other) {
    return other is _AssetByteLoaderCacheKey &&
        other.assetName == assetName &&
        other.assetBundle == assetBundle &&
        other.packageName == packageName;
  }

  @override
  String toString() =>
      'SvgAsset(${packageName != null ? '$packageName/' : ''}$assetName)';
}

/// A [BytesLoader] that resolves an SVG from an asset bundle.
class SvgAssetLoader extends SvgLoader<ByteData> {
  /// See class doc.
  const SvgAssetLoader(
    this.assetName, {
    this.packageName,
    this.assetBundle,
    super.theme,
    super.colorMapper,
  });

  /// The name of the asset, e.g. foo.svg.
  final String assetName;

  /// The package containing the asset.
  final String? packageName;

  /// The asset bundle to use, or [DefaultAssetBundle] if null.
  final AssetBundle? assetBundle;

  AssetBundle _resolveBundle(BuildContext? context) {
    if (assetBundle != null) {
      return assetBundle!;
    }
    if (context != null) {
      return DefaultAssetBundle.of(context);
    }
    return rootBundle;
  }

  @override
  Future<ByteData?> prepareMessage(BuildContext? context) {
    return _resolveBundle(context).load(
      packageName == null ? assetName : 'packages/$packageName/$assetName',
    );
  }

  @override
  String provideSvg(ByteData? message) =>
      utf8.decode(Uint8List.sublistView(message!), allowMalformed: true);

  @override
  SvgCacheKey cacheKey(BuildContext? context) {
    final SvgTheme theme = getTheme(context);
    return SvgCacheKey(
      theme: theme,
      colorMapper: colorMapper,
      keyData: _AssetByteLoaderCacheKey(
        assetName,
        packageName,
        _resolveBundle(context),
      ),
    );
  }

  @override
  int get hashCode =>
      Object.hash(assetName, packageName, assetBundle, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgAssetLoader &&
        other.assetName == assetName &&
        other.packageName == packageName &&
        other.assetBundle == assetBundle &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() => 'SvgAssetLoader($assetName)';
}

/// A [BytesLoader] that resolves an SVG from the network.
class SvgNetworkLoader extends SvgLoader<Uint8List> {
  /// See class doc.
  const SvgNetworkLoader(
    this.url, {
    this.headers,
    super.theme,
    super.colorMapper,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// The [Uri] encoded resource address.
  final String url;

  /// Optional HTTP headers to send as part of the request.
  final Map<String, String>? headers;

  final http.Client? _httpClient;

  @override
  Future<Uint8List?> prepareMessage(BuildContext? context) async {
    final http.Client client = _httpClient ?? http.Client();
    final http.Response response = await client.get(
      Uri.parse(url),
      headers: headers,
    );
    if (_httpClient == null) {
      client.close();
    }
    return response.bodyBytes;
  }

  @override
  String provideSvg(Uint8List? message) =>
      utf8.decode(message!, allowMalformed: true);

  @override
  int get hashCode => Object.hash(url, headers, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgNetworkLoader &&
        other.url == url &&
        other.headers == headers &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() => 'SvgNetworkLoader($url)';
}
