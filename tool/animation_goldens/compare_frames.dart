// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Animation frame comparison and report generator.
///
/// Compares Flutter-rendered animation frames against browser golden references
/// and generates per-SVG and summary JSON reports with diff visualizations.
///
/// ## Running
///
///   flutter test tool/animation_goldens/compare_frames.dart --tags animation_compare
///
/// ## Prerequisites
///
///   Both browser and Flutter frames must be captured first:
///   - Browser: node tool/animation_goldens/capture_browser.js ...
///   - Flutter: flutter test tool/animation_goldens/capture_flutter_test.dart --tags animation_golden
///
@Tags(['animation_compare'])
library compare_frames;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/golden_capture/image_compare.dart';

// ---------------------------------------------------------------------------
// Directory paths
// ---------------------------------------------------------------------------

const String kBrowserDir = 'test/animation_goldens/browser';
const String kFlutterDir = 'test/animation_goldens/flutter';
const String kDiffDir = 'test/animation_goldens/diff';
const String kReportsDir = 'test/animation_goldens/reports';

// ---------------------------------------------------------------------------
// Per-pixel comparison threshold
// ---------------------------------------------------------------------------

const double kPerPixelThreshold = 0.15; // 15%

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class FrameResult {
  FrameResult({
    required this.frame,
    required this.timeSeconds,
    required this.similarity,
    required this.differentPixels,
    required this.totalPixels,
    this.error,
  });

  final int frame;
  final double timeSeconds;
  final double similarity;
  final int differentPixels;
  final int totalPixels;
  final String? error;

  Map<String, dynamic> toJson() => {
    'frame': frame,
    'time_s': double.parse(timeSeconds.toStringAsFixed(1)),
    'similarity': double.parse(similarity.toStringAsFixed(4)),
    'different_pixels': differentPixels,
    'total_pixels': totalPixels,
    if (error != null) 'error': error,
  };
}

class SvgReport {
  SvgReport({
    required this.svg,
    required this.frames,
    required this.results,
  });

  final String svg;
  final int frames;
  final List<FrameResult> results;

  double get averageSimilarity {
    if (results.isEmpty) return 0.0;
    return results.map((r) => r.similarity).reduce((a, b) => a + b) /
        results.length;
  }

  int get worstFrame {
    if (results.isEmpty) return -1;
    var worst = 0;
    for (int i = 1; i < results.length; i++) {
      if (results[i].similarity < results[worst].similarity) worst = i;
    }
    return worst;
  }

  double get worstSimilarity {
    if (results.isEmpty) return 0.0;
    return results.map((r) => r.similarity).reduce(
      (a, b) => a < b ? a : b,
    );
  }

  Map<String, dynamic> toJson() => {
    'svg': svg,
    'frames': frames,
    'results': results.map((r) => r.toJson()).toList(),
    'average_similarity': double.parse(averageSimilarity.toStringAsFixed(4)),
    'worst_frame': worstFrame,
    'worst_similarity': double.parse(worstSimilarity.toStringAsFixed(4)),
  };
}

// ---------------------------------------------------------------------------
// Discover SVGs that have both browser and flutter frames
// ---------------------------------------------------------------------------

List<String> _discoverComparableSvgs() {
  final browserDir = Directory(kBrowserDir);
  final flutterDir = Directory(kFlutterDir);

  if (!browserDir.existsSync() || !flutterDir.existsSync()) {
    return [];
  }

  final browserSvgs =
      browserDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .toSet();

  final flutterSvgs =
      flutterDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .toSet();

  final common = browserSvgs.intersection(flutterSvgs).toList()..sort();
  return common;
}

// ---------------------------------------------------------------------------
// Count frames in a directory
// ---------------------------------------------------------------------------

List<String> _listFrameFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  final frames =
      dir
          .listSync()
          .where((e) => e.path.endsWith('.png'))
          .map((e) => e.path.split('/').last)
          .toList()
    ..sort();
  return frames;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Compare animation frames and generate reports', () async {
    final svgNames = _discoverComparableSvgs();

    if (svgNames.isEmpty) {
      // ignore: avoid_print
      print(
        '\nNo comparable SVGs found.\n'
        'Make sure both browser and Flutter frames are captured first.\n'
        '  Browser: $kBrowserDir/<svg_name>/frame_NN.png\n'
        '  Flutter: $kFlutterDir/<svg_name>/frame_NN.png\n',
      );
      return;
    }

    // Ensure output directories exist
    Directory(kDiffDir).createSync(recursive: true);
    Directory(kReportsDir).createSync(recursive: true);

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('=' * 70);
    // ignore: avoid_print
    print('  Animation Frame Comparison Report');
    // ignore: avoid_print
    print('=' * 70);
    // ignore: avoid_print
    print('  SVGs to compare: ${svgNames.length}');
    // ignore: avoid_print
    print('  Per-pixel threshold: ${(kPerPixelThreshold * 100).toInt()}%');
    // ignore: avoid_print
    print('=' * 70);
    // ignore: avoid_print
    print('');

    final allReports = <SvgReport>[];

    for (final svgName in svgNames) {
      // ignore: avoid_print
      print('  Comparing: $svgName');

      final browserFrameDir = '$kBrowserDir/$svgName';
      final flutterFrameDir = '$kFlutterDir/$svgName';
      final diffFrameDir = '$kDiffDir/$svgName';

      Directory(diffFrameDir).createSync(recursive: true);

      final browserFrames = _listFrameFiles(browserFrameDir);
      final flutterFrames = _listFrameFiles(flutterFrameDir);

      // Match frames by filename
      final commonFrames =
          browserFrames.toSet().intersection(flutterFrames.toSet()).toList()
            ..sort();

      if (commonFrames.isEmpty) {
        // ignore: avoid_print
        print('    SKIP: No matching frame files');
        continue;
      }

      final frameResults = <FrameResult>[];

      for (int i = 0; i < commonFrames.length; i++) {
        final frameName = commonFrames[i];
        // Extract frame number from filename like "frame_00.png"
        final frameNum =
            int.tryParse(
              frameName.replaceAll('frame_', '').replaceAll('.png', ''),
            ) ??
            i;

        // Estimate time (assuming uniform distribution)
        // We'll use frame index since we don't know exact duration
        final timeSeconds = frameNum.toDouble();

        final browserPng = File('$browserFrameDir/$frameName');
        final flutterPng = File('$flutterFrameDir/$frameName');

        if (!browserPng.existsSync() || !flutterPng.existsSync()) {
          frameResults.add(
            FrameResult(
              frame: frameNum,
              timeSeconds: timeSeconds,
              similarity: 0.0,
              differentPixels: 0,
              totalPixels: 0,
              error: 'Missing frame file',
            ),
          );
          continue;
        }

        final browserBytes = Uint8List.fromList(browserPng.readAsBytesSync());
        final flutterBytes = Uint8List.fromList(flutterPng.readAsBytesSync());

        final result = await compareImages(
          imageA: flutterBytes,
          imageB: browserBytes,
          perPixelThreshold: kPerPixelThreshold,
          generateDiff: true,
        );

        // Save diff image
        if (result.diffImage != null) {
          final diffFile = File('$diffFrameDir/$frameName');
          diffFile.writeAsBytesSync(result.diffImage!);
        }

        frameResults.add(
          FrameResult(
            frame: frameNum,
            timeSeconds: timeSeconds,
            similarity: result.similarity,
            differentPixels: result.differentPixels,
            totalPixels: result.totalPixels,
            error: result.message,
          ),
        );
      }

      final report = SvgReport(
        svg: svgName,
        frames: commonFrames.length,
        results: frameResults,
      );
      allReports.add(report);

      // Save per-SVG report
      final reportFile = File('$kReportsDir/$svgName.json');
      reportFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report.toJson()),
      );

      // Print summary for this SVG
      final avgPct = (report.averageSimilarity * 100).toStringAsFixed(1);
      final worstPct = (report.worstSimilarity * 100).toStringAsFixed(1);
      final worstIdx = report.worstFrame;
      // ignore: avoid_print
      print(
        '    ${commonFrames.length} frames | avg: $avgPct% | worst: $worstPct% (frame $worstIdx)',
      );
    }

    // Generate summary report
    if (allReports.isNotEmpty) {
      final totalFrames = allReports.fold<int>(
        0,
        (s, r) => s + r.frames,
      );
      final overallAvg =
          allReports.map((r) => r.averageSimilarity).reduce((a, b) => a + b) /
          allReports.length;
      final above95 =
          allReports.where((r) => r.averageSimilarity >= 0.95).length;
      final below90 =
          allReports.where((r) => r.averageSimilarity < 0.90).length;

      // Find worst SVG
      var worstSvgIdx = 0;
      for (int i = 1; i < allReports.length; i++) {
        if (allReports[i].averageSimilarity <
            allReports[worstSvgIdx].averageSimilarity) {
          worstSvgIdx = i;
        }
      }

      final summary = {
        'total_svgs': allReports.length,
        'total_frames': totalFrames,
        'overall_average_similarity': double.parse(
          overallAvg.toStringAsFixed(4),
        ),
        'svgs_above_95': above95,
        'svgs_below_90': below90,
        'worst_svg': allReports[worstSvgIdx].svg,
        'worst_svg_similarity': double.parse(
          allReports[worstSvgIdx].averageSimilarity.toStringAsFixed(4),
        ),
        'per_svg':
            allReports
                .map(
                  (r) => {
                    'svg': r.svg,
                    'average_similarity': double.parse(
                      r.averageSimilarity.toStringAsFixed(4),
                    ),
                    'worst_frame': r.worstFrame,
                    'worst_similarity': double.parse(
                      r.worstSimilarity.toStringAsFixed(4),
                    ),
                    'frames': r.frames,
                  },
                )
                .toList(),
      };

      final summaryFile = File('$kReportsDir/summary.json');
      summaryFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(summary),
      );

      // Print summary table
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('=' * 70);
      // ignore: avoid_print
      print('  SUMMARY');
      // ignore: avoid_print
      print('=' * 70);
      // ignore: avoid_print
      print(
        '  ${'SVG'.padRight(35)} ${'Avg%'.padLeft(7)} ${'Worst%'.padLeft(7)} ${'Frames'.padLeft(6)}',
      );
      // ignore: avoid_print
      print('  ${'-' * 55}');

      for (final r in allReports) {
        final avgP = (r.averageSimilarity * 100).toStringAsFixed(1);
        final worstP = (r.worstSimilarity * 100).toStringAsFixed(1);
        final status = r.averageSimilarity >= 0.95
            ? 'OK'
            : r.averageSimilarity >= 0.90
            ? 'WARN'
            : 'FAIL';
        // ignore: avoid_print
        print(
          '  ${r.svg.padRight(35)} ${avgP.padLeft(6)}% ${worstP.padLeft(6)}% ${r.frames.toString().padLeft(6)}  $status',
        );
      }

      // ignore: avoid_print
      print('  ${'-' * 55}');
      final overallPct = (overallAvg * 100).toStringAsFixed(1);
      // ignore: avoid_print
      print('  Overall: $overallPct% average similarity');
      // ignore: avoid_print
      print('  $above95/${allReports.length} SVGs above 95%');
      if (below90 > 0) {
        // ignore: avoid_print
        print('  WARNING: $below90 SVGs below 90%');
      }
      // ignore: avoid_print
      print('  Worst: ${allReports[worstSvgIdx].svg} (${(allReports[worstSvgIdx].averageSimilarity * 100).toStringAsFixed(1)}%)');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('  Reports saved to: $kReportsDir/');
      // ignore: avoid_print
      print('  Diffs saved to:   $kDiffDir/');
      // ignore: avoid_print
      print('=' * 70);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
