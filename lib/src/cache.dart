import 'package:flutter/foundation.dart';

import 'svg_theme.dart';

/// Statistics for cache profiling and diagnostics.
class CacheStats {
  CacheStats();

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _pendingHits = 0;
  int _peakSize = 0;

  /// Total cache hits (found in completed cache).
  int get hits => _hits;

  /// Total cache misses (not found, had to load).
  int get misses => _misses;

  /// Total evictions from cache.
  int get evictions => _evictions;

  /// Hits on pending (in-flight) entries.
  int get pendingHits => _pendingHits;

  /// Peak cache size observed.
  int get peakSize => _peakSize;

  /// Total access count (hits + misses).
  int get totalAccesses => _hits + _misses;

  /// Hit rate as a percentage (0.0 to 1.0).
  double get hitRate => totalAccesses > 0 ? _hits / totalAccesses : 0.0;

  /// Hit rate including pending hits.
  double get effectiveHitRate =>
      totalAccesses > 0 ? (_hits + _pendingHits) / totalAccesses : 0.0;

  /// Records a cache hit.
  void recordHit() => _hits++;

  /// Records a cache miss.
  void recordMiss() => _misses++;

  /// Records an eviction.
  void recordEviction() => _evictions++;

  /// Records a pending hit.
  void recordPendingHit() => _pendingHits++;

  /// Updates peak size if current size is larger.
  void updatePeakSize(int currentSize) {
    if (currentSize > _peakSize) {
      _peakSize = currentSize;
    }
  }

  /// Resets all statistics.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _pendingHits = 0;
    _peakSize = 0;
  }

  /// Returns a diagnostic summary of cache statistics.
  String dump() {
    return 'CacheStats{'
        'hits: $_hits, '
        'misses: $_misses, '
        'pendingHits: $_pendingHits, '
        'evictions: $_evictions, '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'effectiveHitRate: ${(effectiveHitRate * 100).toStringAsFixed(1)}%, '
        'peakSize: $_peakSize}';
  }

  @override
  String toString() => dump();
}

/// The cache for decoded SVGs.
class Cache {
  final Map<Object, Future<ByteData>> _pending = <Object, Future<ByteData>>{};
  final Map<Object, ByteData> _cache = <Object, ByteData>{};

  /// Statistics for cache profiling.
  final CacheStats stats = CacheStats();

  /// Maximum number of entries to store in the cache.
  ///
  /// Once this many entries have been cached, the least-recently-used entry is
  /// evicted when adding a new entry.
  int get maximumSize => _maximumSize;
  int _maximumSize = 100;

  /// Changes the maximum cache size.
  ///
  /// If the new size is smaller than the current number of elements, the
  /// extraneous elements are evicted immediately. Setting this to zero and then
  /// returning it to its original value will therefore immediately clear the
  /// cache.
  set maximumSize(int value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    assert(value >= 0);
    if (value == maximumSize) {
      return;
    }
    _maximumSize = value;
    if (maximumSize == 0) {
      clear();
    } else {
      while (_cache.length > maximumSize) {
        _cache.remove(_cache.keys.first);
        stats.recordEviction();
      }
    }
  }

  /// Evicts all entries from the cache.
  ///
  /// This is useful if, for instance, the root asset bundle has been updated
  /// and therefore new images must be obtained.
  void clear() {
    final count = _cache.length;
    _cache.clear();
    for (var i = 0; i < count; i++) {
      stats.recordEviction();
    }
  }

  /// Evicts a single entry from the cache, returning true if successful.
  bool evict(Object key) {
    final removed = _cache.remove(key) != null;
    if (removed) {
      stats.recordEviction();
    }
    return removed;
  }

  /// Evicts a single entry from the cache if the `oldData` and `newData` are
  /// incompatible.
  ///
  /// For example, if the theme has changed the current color and the picture
  /// uses current color, [evict] will be called.
  bool maybeEvict(Object key, SvgTheme oldData, SvgTheme newData) {
    return evict(key);
  }

  /// Returns the previously cached [PictureStream] for the given key, if available;
  /// if not, calls the given callback to obtain it first. In either case, the
  /// key is moved to the "most recently used" position.
  ///
  /// The arguments must not be null. The `loader` cannot return null.
  Future<ByteData> putIfAbsent(Object key, Future<ByteData> Function() loader) {
    assert(key != null); // ignore: unnecessary_null_comparison
    assert(loader != null); // ignore: unnecessary_null_comparison
    Future<ByteData>? pendingResult = _pending[key];
    if (pendingResult != null) {
      stats.recordPendingHit();
      return pendingResult;
    }

    ByteData? result = _cache[key];
    if (result != null) {
      stats.recordHit();
      // Remove the provider from the list so that we can put it back in below
      // and thus move it to the end of the list.
      _cache.remove(key);
    } else {
      stats.recordMiss();
      pendingResult = loader();
      _pending[key] = pendingResult;
      pendingResult.then(
        (ByteData data) {
          _pending.remove(key);
          _add(key, data);
          result = data; // in case it was a synchronous future.
        },
        // Drop failed entries so the load can be retried, and so the failure
        // is observed here rather than surfacing as an unhandled async error.
        onError: (Object _, StackTrace __) {
          _pending.remove(key);
        },
      );
    }
    stats.updatePeakSize(_cache.length);
    if (result != null) {
      _add(key, result!);
      return SynchronousFuture<ByteData>(result!);
    }
    assert(_cache.length <= maximumSize);
    return pendingResult!;
  }

  void _add(Object key, ByteData result) {
    if (maximumSize > 0) {
      if (_cache.containsKey(key)) {
        _cache.remove(key); // update LRU.
      } else if (_cache.length == maximumSize && maximumSize > 0) {
        _cache.remove(_cache.keys.first);
        stats.recordEviction();
      }
      assert(_cache.length < maximumSize);
      _cache[key] = result;
    }
    assert(_cache.length <= maximumSize);
  }

  /// The number of entries in the cache.
  int get count => _cache.length;

  /// Dumps cache statistics for diagnostic purposes.
  String dumpStats() => stats.dump();

  /// Resets cache statistics without clearing the cache.
  void resetStats() => stats.reset();
}
