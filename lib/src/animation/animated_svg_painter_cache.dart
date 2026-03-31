part of 'animated_svg_painter.dart';

/// Performance cache for render-time computed values.
///
/// This cache stores expensive-to-compute values that can be reused between
/// frames when the underlying SVG elements haven't changed. Cache keys include
/// element ID and a hash of relevant attributes to ensure proper invalidation.
///
/// Performance optimization: Implements LRU-style eviction to prevent unbounded
/// cache growth. Each cache type has a maximum size; when exceeded, oldest
/// entries are evicted to maintain memory efficiency.
class _RenderCache {
  /// Maximum cache sizes to prevent unbounded memory growth.
  /// These values are tuned for typical SVG document complexity.
  static const int _maxGradientShaders = 128;
  static const int _maxPatternImages = 64;
  static const int _maxTextParagraphs = 512;
  static const int _maxHitTestPaths = 256;
  static const int _maxMaskBounds = 128;

  /// Cached gradient shaders keyed by gradient ID + paint bounds hash.
  final Map<String, ui.Shader> gradientShaders = <String, ui.Shader>{};

  /// Cached pattern images keyed by pattern ID + target bounds hash.
  final Map<String, ui.Image> patternImages = <String, ui.Image>{};

  /// Cached text paragraphs keyed by text content + style hash.
  final Map<String, ui.Paragraph> textParagraphs = <String, ui.Paragraph>{};

  /// Cached hit-test paths keyed by element ID + geometry hash.
  final Map<String, ui.Path> hitTestPaths = <String, ui.Path>{};

  /// Cached mask bounds keyed by mask ID + masked element bounds hash.
  /// Used to avoid recomputing mask regions every frame.
  final Map<String, ui.Rect> maskBounds = <String, ui.Rect>{};

  /// Cached mask content animation state keyed by mask ID.
  /// True if mask content is animated and needs per-frame invalidation.
  final Map<String, bool> maskAnimationState = <String, bool>{};

  /// Cached animated mask cache keys for content caching.
  /// Used to determine if animated mask content needs re-rendering.
  final Map<String, String> animatedMaskCacheKeys = <String, String>{};

  /// Last animation time when cache was valid.
  double? _lastAnimationTime;

  /// Initialize or update cache state for new frame.
  /// Performance optimization: Enforces cache size limits via LRU eviction.
  void prepareFrame(double? animationTime, bool hasAnimations) {
    // If animation time changed, invalidate caches that depend on animated values
    if (_lastAnimationTime != animationTime && hasAnimations) {
      gradientShaders.clear();
      patternImages.clear();
      textParagraphs.clear();
      hitTestPaths.clear();
      // Only clear animated mask bounds, preserve static ones
      _invalidateAnimatedMaskCaches();
    }
    _lastAnimationTime = animationTime;

    // Enforce cache size limits to prevent unbounded memory growth.
    // Uses simple eviction: when limit exceeded, clear oldest half of entries.
    // This is more efficient than per-entry LRU tracking for hot paths.
    _enforceGradientCacheLimit();
    _enforcePatternCacheLimit();
    _enforceTextCacheLimit();
    _enforceHitTestCacheLimit();
    _enforceMaskBoundsCacheLimit();
  }

  /// Evicts oldest gradient shader entries when cache exceeds size limit.
  void _enforceGradientCacheLimit() {
    if (gradientShaders.length > _maxGradientShaders) {
      final keysToRemove = gradientShaders.keys
          .take(gradientShaders.length - _maxGradientShaders ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        gradientShaders.remove(key);
      }
    }
  }

  /// Evicts oldest pattern image entries when cache exceeds size limit.
  void _enforcePatternCacheLimit() {
    if (patternImages.length > _maxPatternImages) {
      final keysToRemove = patternImages.keys
          .take(patternImages.length - _maxPatternImages ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        patternImages.remove(key);
      }
    }
  }

  /// Evicts oldest text paragraph entries when cache exceeds size limit.
  void _enforceTextCacheLimit() {
    if (textParagraphs.length > _maxTextParagraphs) {
      final keysToRemove = textParagraphs.keys
          .take(textParagraphs.length - _maxTextParagraphs ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        textParagraphs.remove(key);
      }
    }
  }

  /// Evicts oldest hit-test path entries when cache exceeds size limit.
  void _enforceHitTestCacheLimit() {
    if (hitTestPaths.length > _maxHitTestPaths) {
      final keysToRemove = hitTestPaths.keys
          .take(hitTestPaths.length - _maxHitTestPaths ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        hitTestPaths.remove(key);
      }
    }
  }

  /// Evicts oldest mask bounds entries when cache exceeds size limit.
  void _enforceMaskBoundsCacheLimit() {
    if (maskBounds.length > _maxMaskBounds) {
      final keysToRemove = maskBounds.keys
          .take(maskBounds.length - _maxMaskBounds ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        maskBounds.remove(key);
      }
    }
  }

  /// Invalidates mask caches that contain animated content.
  void _invalidateAnimatedMaskCaches() {
    final animatedMasks = maskAnimationState.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    for (final maskId in animatedMasks) {
      maskBounds.removeWhere((key, _) => key.startsWith('m:$maskId|'));
      // Clear cache keys for animated masks to force re-evaluation
      animatedMaskCacheKeys.remove(maskId);
    }
  }

  /// Clears all caches.
  void clear() {
    gradientShaders.clear();
    patternImages.clear();
    textParagraphs.clear();
    hitTestPaths.clear();
    maskBounds.clear();
    maskAnimationState.clear();
    animatedMaskCacheKeys.clear();
    _lastAnimationTime = null;
  }

  /// Generate a cache key for gradient shader.
  static String gradientKey(
    String gradientId,
    ui.Rect bounds,
    Map<String, Object?> attributes,
  ) {
    final boundsHash =
        '${bounds.left.toStringAsFixed(2)}_'
        '${bounds.top.toStringAsFixed(2)}_'
        '${bounds.width.toStringAsFixed(2)}_'
        '${bounds.height.toStringAsFixed(2)}';
    final attrHash = attributes.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    return 'g:$gradientId|b:$boundsHash|a:${attrHash.hashCode}';
  }

  /// Generate a cache key for pattern image.
  static String patternKey(
    String patternId,
    ui.Rect bounds,
    int tileWidth,
    int tileHeight,
  ) {
    final boundsHash =
        '${bounds.left.toStringAsFixed(2)}_'
        '${bounds.top.toStringAsFixed(2)}_'
        '${bounds.width.toStringAsFixed(2)}_'
        '${bounds.height.toStringAsFixed(2)}';
    return 'p:$patternId|b:$boundsHash|tw:$tileWidth|th:$tileHeight';
  }

  /// Generate a cache key for text paragraph.
  static String textKey(
    String text,
    double fontSize,
    String? fontFamily,
    int fontWeightIndex,
    int fontStyleIndex,
    double letterSpacing,
    int colorValue,
  ) {
    return 't:${text.hashCode}|fs:${fontSize.toStringAsFixed(1)}|'
        'ff:${fontFamily ?? "def"}|fw:$fontWeightIndex|'
        'fst:$fontStyleIndex|ls:${letterSpacing.toStringAsFixed(2)}|'
        'c:$colorValue';
  }

  /// Generate a cache key for mask bounds.
  // ignore: unused_element
  static String maskKey(
    String maskId,
    ui.Rect elementBounds,
    String maskUnits,
    String maskContentUnits,
  ) {
    final boundsHash =
        '${elementBounds.left.toStringAsFixed(2)}_'
        '${elementBounds.top.toStringAsFixed(2)}_'
        '${elementBounds.width.toStringAsFixed(2)}_'
        '${elementBounds.height.toStringAsFixed(2)}';
    return 'm:$maskId|b:$boundsHash|mu:$maskUnits|mcu:$maskContentUnits';
  }
}
