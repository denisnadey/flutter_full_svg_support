// ignore_for_file: public_member_api_docs

/// Metrics collected for a single benchmark scenario and package combination.
class BenchmarkMetrics {
  const BenchmarkMetrics({
    required this.name,
    required this.package,
    required this.scenario,
    required this.firstPaintMs,
    required this.avgBuildMs,
    required this.p90BuildMs,
    required this.p99BuildMs,
    required this.worstBuildMs,
    required this.avgRasterMs,
    required this.p90RasterMs,
    required this.p99RasterMs,
    required this.worstRasterMs,
    required this.frameCount,
    required this.jankFrameCount60hz,
    required this.jankFrameCount120hz,
    required this.memoryBeforeMb,
    required this.memoryAfterMb,
    required this.memoryDeltaMb,
    required this.benchmarkDurationMs,
  });

  /// Human-readable display name for this benchmark run.
  final String name;

  /// Package identifier: "full_svg_flutter_picture", "full_svg_flutter_raster",
  /// or "flutter_svg".
  final String package;

  /// Scenario key, e.g. "render_simple_icon_picture".
  final String scenario;

  /// Wall-clock time from widget pump to first frame completion, in milliseconds.
  final double firstPaintMs;

  // ---------- Build phase ----------

  final double avgBuildMs;
  final double p90BuildMs;
  final double p99BuildMs;
  final double worstBuildMs;

  // ---------- Raster phase ----------

  final double avgRasterMs;
  final double p90RasterMs;
  final double p99RasterMs;
  final double worstRasterMs;

  // ---------- Frame counts ----------

  final int frameCount;

  /// Number of frames whose build duration exceeded 16.67 ms (60 Hz budget).
  final int jankFrameCount60hz;

  /// Number of frames whose build duration exceeded 8.33 ms (120 Hz budget).
  final int jankFrameCount120hz;

  // ---------- Memory ----------

  final double memoryBeforeMb;
  final double memoryAfterMb;
  final double memoryDeltaMb;

  // ---------- Wall clock ----------

  /// Total measurement window duration in milliseconds.
  final int benchmarkDurationMs;

  // ---------- Serialisation ----------

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'package': package,
        'scenario': scenario,
        'firstPaintMs': firstPaintMs,
        'avgBuildMs': avgBuildMs,
        'p90BuildMs': p90BuildMs,
        'p99BuildMs': p99BuildMs,
        'worstBuildMs': worstBuildMs,
        'avgRasterMs': avgRasterMs,
        'p90RasterMs': p90RasterMs,
        'p99RasterMs': p99RasterMs,
        'worstRasterMs': worstRasterMs,
        'frameCount': frameCount,
        'jankFrameCount60hz': jankFrameCount60hz,
        'jankFrameCount120hz': jankFrameCount120hz,
        'memoryBeforeMb': memoryBeforeMb,
        'memoryAfterMb': memoryAfterMb,
        'memoryDeltaMb': memoryDeltaMb,
        'benchmarkDurationMs': benchmarkDurationMs,
      };

  factory BenchmarkMetrics.fromJson(Map<String, dynamic> json) =>
      BenchmarkMetrics(
        name: json['name'] as String,
        package: json['package'] as String,
        scenario: json['scenario'] as String,
        firstPaintMs: (json['firstPaintMs'] as num).toDouble(),
        avgBuildMs: (json['avgBuildMs'] as num).toDouble(),
        p90BuildMs: (json['p90BuildMs'] as num).toDouble(),
        p99BuildMs: (json['p99BuildMs'] as num).toDouble(),
        worstBuildMs: (json['worstBuildMs'] as num).toDouble(),
        avgRasterMs: (json['avgRasterMs'] as num).toDouble(),
        p90RasterMs: (json['p90RasterMs'] as num).toDouble(),
        p99RasterMs: (json['p99RasterMs'] as num).toDouble(),
        worstRasterMs: (json['worstRasterMs'] as num).toDouble(),
        frameCount: json['frameCount'] as int,
        jankFrameCount60hz: json['jankFrameCount60hz'] as int,
        jankFrameCount120hz: json['jankFrameCount120hz'] as int,
        memoryBeforeMb: (json['memoryBeforeMb'] as num).toDouble(),
        memoryAfterMb: (json['memoryAfterMb'] as num).toDouble(),
        memoryDeltaMb: (json['memoryDeltaMb'] as num).toDouble(),
        benchmarkDurationMs: json['benchmarkDurationMs'] as int,
      );
}

/// Aggregated results for a complete benchmark suite run.
class BenchmarkSuiteResult {
  const BenchmarkSuiteResult({
    required this.timestamp,
    required this.deviceInfo,
    required this.flutterVersion,
    required this.dartVersion,
    required this.rendererMode,
    required this.packageVersions,
    required this.results,
  });

  /// ISO-8601 timestamp of when the suite run started.
  final String timestamp;

  /// Human-readable device/emulator description.
  final String deviceInfo;

  final String flutterVersion;
  final String dartVersion;

  /// "skia" or "impeller".
  final String rendererMode;

  /// Map from package name to resolved version string.
  final Map<String, String> packageVersions;

  final List<BenchmarkMetrics> results;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp,
        'deviceInfo': deviceInfo,
        'flutterVersion': flutterVersion,
        'dartVersion': dartVersion,
        'rendererMode': rendererMode,
        'packageVersions': packageVersions,
        'results': results.map((r) => r.toJson()).toList(),
      };
}
