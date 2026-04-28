// ignore_for_file: avoid_print

/// Integration benchmark test suite.
///
/// Run with:
///   flutter test integration_test/benchmark_test.dart \
///     --device-id <device> \
///     --reporter expanded
///
/// Results are written to results/<scenario>/<package>.json and a combined
/// results/suite_results.json file.
///
/// NOTE: dart:io is intentionally used here (integration_test context runs on
/// the target device / host, not in Flutter widget code).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;
import 'package:integration_test/integration_test.dart';

import 'package:full_svg_flutter_benchmarks/benchmark_runner.dart';
import 'package:full_svg_flutter_benchmarks/result_models.dart';

// ---------------------------------------------------------------------------
// Asset path constants
// ---------------------------------------------------------------------------

const String _simpleIcon = 'assets/simple/simple_icon.svg';
const String _complexPath1k = 'assets/complex/complex_path_1k.svg';
const String _complexPath10k = 'assets/complex/complex_path_10k.svg';
const String _gradients = 'assets/complex/gradients.svg';
const String _filters = 'assets/filters/filter_stack.svg';
const String _cssKeyframes = 'assets/animated/css_keyframes.svg';
const String _smilAnimation = 'assets/animated/spinner_smil.svg';
const String _animSpinner = 'assets/animated/spinner_smil.svg';
const String _animHeartbeat = 'assets/animated/dash_heartbeat.svg';
const String _animPathMorph = 'assets/animated/path_morph.svg';
const String _animTransform = 'assets/animated/transform_matrix.svg';
const String _animMotion = 'assets/animated/motion_path.svg';
const String _animFilterStack = 'assets/filters/anim_filter_stack.svg';
const String _galacticStorm = 'assets/stress/galactic_storm.svg';

// ---------------------------------------------------------------------------
// Package identifier constants
// ---------------------------------------------------------------------------

const String _pkgFullSvgPicture = 'full_svg_flutter_picture';
const String _pkgFullSvgRaster = 'full_svg_flutter_raster';
const String _pkgFlutterSvg = 'flutter_svg';

// ---------------------------------------------------------------------------
// Accumulated results for suite_results.json
// ---------------------------------------------------------------------------

final List<BenchmarkMetrics> _allResults = [];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Writes a [BenchmarkMetrics] object to results/<scenario>/<package>.json.
Future<void> _saveResult(BenchmarkMetrics metrics) async {
  // TODO: On some platforms (e.g. iOS sandbox) the working directory may not
  //       be writable. Consider using path_provider for a stable output path.
  final dir = Directory('results/${metrics.scenario}');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('results/${metrics.scenario}/${metrics.package}.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(metrics.toJson()),
  );
  print('[benchmark] Saved: ${file.path}');
}

/// Minimal scaffold that wraps [child] so it can be pumped by WidgetTester.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

/// Adapter: bridges the tester + widgetFactory call-site to BenchmarkRunner's
/// pumpFrame callback API so flutter_test stays out of lib/ code.
Future<BenchmarkMetrics> _run({
  required String name,
  required String package,
  required String scenario,
  required WidgetTester tester,
  required Widget Function() widgetFactory,
  Duration warmupDuration = const Duration(seconds: 2),
  Duration measureDuration = const Duration(seconds: 5),
}) async {
  await tester.pumpWidget(widgetFactory());
  await tester.pump();
  return BenchmarkRunner.runScenario(
    name: name,
    package: package,
    scenario: scenario,
    pumpFrame: tester.pump,
    warmupDuration: warmupDuration,
    measureDuration: measureDuration,
  );
}

// ---------------------------------------------------------------------------
// Test entry point
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Group 1 — Parse benchmarks
  // The parse benchmarks measure how quickly the SVG loader can decode an
  // asset. We pump the widget once and capture first-paint time as a proxy.
  // For pure Dart parse microbenchmarks see benchmark_runner/bin/run_benchmarks.dart.
  // -------------------------------------------------------------------------

  group('parse', () {
    testWidgets('parse_simple_icon — full_svg_flutter', (tester) async {
      final metrics = await _run(
        name: 'Parse Simple Icon',
        package: _pkgFullSvgPicture,
        scenario: 'parse_simple_icon',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_simpleIcon)),
        warmupDuration: const Duration(seconds: 1),
        measureDuration: const Duration(seconds: 3),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_simple_icon — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Parse Simple Icon',
        package: _pkgFlutterSvg,
        scenario: 'parse_simple_icon',
        tester: tester,
        widgetFactory: () => _wrap(fsvg.SvgPicture.asset(_simpleIcon)),
        warmupDuration: const Duration(seconds: 1),
        measureDuration: const Duration(seconds: 3),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_complex_path_1k — full_svg_flutter', (tester) async {
      final metrics = await _run(
        name: 'Parse Complex Path 1k',
        package: _pkgFullSvgPicture,
        scenario: 'parse_complex_path_1k',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_complexPath1k)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_complex_path_1k — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Parse Complex Path 1k',
        package: _pkgFlutterSvg,
        scenario: 'parse_complex_path_1k',
        tester: tester,
        widgetFactory: () => _wrap(fsvg.SvgPicture.asset(_complexPath1k)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_complex_path_10k — full_svg_flutter', (tester) async {
      final metrics = await _run(
        name: 'Parse Complex Path 10k',
        package: _pkgFullSvgPicture,
        scenario: 'parse_complex_path_10k',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_complexPath10k)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_complex_path_10k — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Parse Complex Path 10k',
        package: _pkgFlutterSvg,
        scenario: 'parse_complex_path_10k',
        tester: tester,
        widgetFactory: () => _wrap(fsvg.SvgPicture.asset(_complexPath10k)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_gradients — full_svg_flutter', (tester) async {
      final metrics = await _run(
        name: 'Parse Gradients',
        package: _pkgFullSvgPicture,
        scenario: 'parse_gradients',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_gradients)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_gradients — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Parse Gradients',
        package: _pkgFlutterSvg,
        scenario: 'parse_gradients',
        tester: tester,
        widgetFactory: () => _wrap(fsvg.SvgPicture.asset(_gradients)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_filters — full_svg_flutter', (tester) async {
      final metrics = await _run(
        name: 'Parse Filters',
        package: _pkgFullSvgPicture,
        scenario: 'parse_filters',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_filters)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_filters — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Parse Filters',
        package: _pkgFlutterSvg,
        scenario: 'parse_filters',
        tester: tester,
        widgetFactory: () => _wrap(fsvg.SvgPicture.asset(_filters)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_css_keyframes — full_svg_flutter', (tester) async {
      // flutter_svg does not support CSS @keyframes — full_svg_flutter only.
      final metrics = await _run(
        name: 'Parse CSS Keyframes',
        package: _pkgFullSvgPicture,
        scenario: 'parse_css_keyframes',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_cssKeyframes)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('parse_smil_animation — full_svg_flutter', (tester) async {
      // flutter_svg does not support SMIL — full_svg_flutter only.
      final metrics = await _run(
        name: 'Parse SMIL Animation',
        package: _pkgFullSvgPicture,
        scenario: 'parse_smil_animation',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(_smilAnimation)),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });
  });

  // -------------------------------------------------------------------------
  // Group 2 — Render benchmarks (static)
  // -------------------------------------------------------------------------

  group('render_static', () {
    testWidgets('render_simple_icon_picture', (tester) async {
      final metrics = await _run(
        name: 'Render Simple Icon (picture)',
        package: _pkgFullSvgPicture,
        scenario: 'render_simple_icon_picture',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(
          _simpleIcon,
          width: 200,
          height: 200,
          // TODO: pass renderingStrategy: RenderingStrategy.picture
        )),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('render_simple_icon_raster', (tester) async {
      final metrics = await _run(
        name: 'Render Simple Icon (raster)',
        package: _pkgFullSvgRaster,
        scenario: 'render_simple_icon_raster',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(
          _simpleIcon,
          width: 200,
          height: 200,
          // TODO: pass renderingStrategy: RenderingStrategy.raster
        )),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('render_complex_illustration_picture', (tester) async {
      final metrics = await _run(
        name: 'Render Complex Illustration (picture)',
        package: _pkgFullSvgPicture,
        scenario: 'render_complex_illustration_picture',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(
          _complexPath1k,
          width: 300,
          height: 300,
        )),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('render_complex_illustration_raster', (tester) async {
      final metrics = await _run(
        name: 'Render Complex Illustration (raster)',
        package: _pkgFullSvgRaster,
        scenario: 'render_complex_illustration_raster',
        tester: tester,
        widgetFactory: () => _wrap(ffsf.SvgPicture.asset(
          _complexPath1k,
          width: 300,
          height: 300,
          // TODO: pass renderingStrategy: RenderingStrategy.raster
        )),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });
  });

  // -------------------------------------------------------------------------
  // Group 3 — Grid / scroll benchmarks
  // -------------------------------------------------------------------------

  group('grid_and_scroll', () {
    testWidgets('grid_100_same_svg_cached — full_svg_flutter_picture',
        (tester) async {
      final metrics = await _run(
        name: 'Grid 100 Same SVG (cached)',
        package: _pkgFullSvgPicture,
        scenario: 'grid_100_same_svg_cached',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
            ),
            itemCount: 100,
            itemBuilder: (_, __) =>
                ffsf.SvgPicture.asset(_simpleIcon, width: 40, height: 40),
          ),
        ),
        measureDuration: const Duration(seconds: 5),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('grid_100_same_svg_cached — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Grid 100 Same SVG (cached)',
        package: _pkgFlutterSvg,
        scenario: 'grid_100_same_svg_cached',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
            ),
            itemCount: 100,
            itemBuilder: (_, __) =>
                fsvg.SvgPicture.asset(_simpleIcon, width: 40, height: 40),
          ),
        ),
        measureDuration: const Duration(seconds: 5),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('grid_100_unique_svg — full_svg_flutter_picture',
        (tester) async {
      final assets = [_simpleIcon, _complexPath1k, _gradients];
      final metrics = await _run(
        name: 'Grid 100 Unique SVG',
        package: _pkgFullSvgPicture,
        scenario: 'grid_100_unique_svg',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
            ),
            itemCount: 100,
            itemBuilder: (_, i) => ffsf.SvgPicture.asset(
              assets[i % assets.length],
              width: 40,
              height: 40,
            ),
          ),
        ),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('grid_100_unique_svg — flutter_svg', (tester) async {
      final assets = [_simpleIcon, _complexPath1k, _gradients];
      final metrics = await _run(
        name: 'Grid 100 Unique SVG',
        package: _pkgFlutterSvg,
        scenario: 'grid_100_unique_svg',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
            ),
            itemCount: 100,
            itemBuilder: (_, i) => fsvg.SvgPicture.asset(
              assets[i % assets.length],
              width: 40,
              height: 40,
            ),
          ),
        ),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('grid_500_simple_icons — full_svg_flutter_picture',
        (tester) async {
      final metrics = await _run(
        name: 'Grid 500 Simple Icons',
        package: _pkgFullSvgPicture,
        scenario: 'grid_500_simple_icons',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 20,
            ),
            itemCount: 500,
            itemBuilder: (_, __) =>
                ffsf.SvgPicture.asset(_simpleIcon, width: 30, height: 30),
          ),
        ),
        measureDuration: const Duration(seconds: 6),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('grid_500_simple_icons — flutter_svg', (tester) async {
      final metrics = await _run(
        name: 'Grid 500 Simple Icons',
        package: _pkgFlutterSvg,
        scenario: 'grid_500_simple_icons',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 20,
            ),
            itemCount: 500,
            itemBuilder: (_, __) =>
                fsvg.SvgPicture.asset(_simpleIcon, width: 30, height: 30),
          ),
        ),
        measureDuration: const Duration(seconds: 6),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('scroll_200_svg_items — full_svg_flutter_picture',
        (tester) async {
      final scrollController = ScrollController();
      final metrics = await _run(
        name: 'Scroll 200 SVG Items',
        package: _pkgFullSvgPicture,
        scenario: 'scroll_200_svg_items',
        tester: tester,
        widgetFactory: () => _wrap(
          ListView.builder(
            controller: scrollController,
            itemCount: 200,
            itemBuilder: (_, i) => ListTile(
              leading: ffsf.SvgPicture.asset(_simpleIcon,
                  width: 40, height: 40),
              title: Text('Item $i'),
            ),
          ),
        ),
        measureDuration: const Duration(seconds: 5),
      );
      // TODO: use tester.drag() or scrollController.animateTo() inside the
      // measure window to simulate real scroll rather than static frame pumps.
      _allResults.add(metrics);
      await _saveResult(metrics);
      scrollController.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Group 4 — Animation benchmarks (full_svg_flutter only)
  // -------------------------------------------------------------------------

  group('animation', () {
    Future<void> _runAnimBenchmark(
      WidgetTester tester,
      String name,
      String scenario,
      String assetPath,
    ) async {
      final controller = ffsf.AnimatedSvgController();
      final metrics = await _run(
        name: name,
        package: _pkgFullSvgPicture,
        scenario: scenario,
        tester: tester,
        widgetFactory: () => _wrap(ffsf.AnimatedSvgPicture.asset(
          assetPath,
          controller: controller,
          width: 200,
          height: 200,
        )),
        warmupDuration: const Duration(seconds: 2),
        measureDuration: const Duration(seconds: 5),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
      controller.dispose();
    }

    testWidgets('anim_spinner_smil', (tester) async {
      await _runAnimBenchmark(
          tester, 'Anim Spinner SMIL', 'anim_spinner_smil', _animSpinner);
    });

    testWidgets('anim_dash_heartbeat', (tester) async {
      await _runAnimBenchmark(tester, 'Anim Dash Heartbeat',
          'anim_dash_heartbeat', _animHeartbeat);
    });

    testWidgets('anim_path_morph', (tester) async {
      await _runAnimBenchmark(
          tester, 'Anim Path Morph', 'anim_path_morph', _animPathMorph);
    });

    testWidgets('anim_transform_matrix', (tester) async {
      await _runAnimBenchmark(tester, 'Anim Transform Matrix',
          'anim_transform_matrix', _animTransform);
    });

    testWidgets('anim_motion_path', (tester) async {
      await _runAnimBenchmark(
          tester, 'Anim Motion Path', 'anim_motion_path', _animMotion);
    });

    testWidgets('anim_css_keyframes', (tester) async {
      await _runAnimBenchmark(tester, 'Anim CSS Keyframes',
          'anim_css_keyframes', _cssKeyframes);
    });

    testWidgets('anim_filter_stack', (tester) async {
      await _runAnimBenchmark(tester, 'Anim Filter Stack', 'anim_filter_stack',
          _animFilterStack);
    });

    testWidgets('anim_20_instances_same_svg', (tester) async {
      // TODO: read RSS memory via dart:developer Service.getVM().isolates[0].pauseOnExit
      //       before and after pumping to measure memory cost of 20 concurrent animations.
      final controllers =
          List.generate(20, (_) => ffsf.AnimatedSvgController());
      final metrics = await _run(
        name: 'Anim 20 Instances Same SVG',
        package: _pkgFullSvgPicture,
        scenario: 'anim_20_instances_same_svg',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.count(
            crossAxisCount: 5,
            children: List.generate(
              20,
              (i) => ffsf.AnimatedSvgPicture.asset(
                _animSpinner,
                controller: controllers[i],
                width: 60,
                height: 60,
              ),
            ),
          ),
        ),
        measureDuration: const Duration(seconds: 5),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
      for (final c in controllers) {
        c.dispose();
      }
    });

    testWidgets('anim_50_instances_same_svg', (tester) async {
      // TODO: read RSS memory via dart:developer Service.getVM().isolates[0].pauseOnExit
      //       before and after pumping to measure memory cost of 50 concurrent animations.
      final controllers =
          List.generate(50, (_) => ffsf.AnimatedSvgController());
      final metrics = await _run(
        name: 'Anim 50 Instances Same SVG',
        package: _pkgFullSvgPicture,
        scenario: 'anim_50_instances_same_svg',
        tester: tester,
        widgetFactory: () => _wrap(
          GridView.count(
            crossAxisCount: 10,
            children: List.generate(
              50,
              (i) => ffsf.AnimatedSvgPicture.asset(
                _animSpinner,
                controller: controllers[i],
                width: 40,
                height: 40,
              ),
            ),
          ),
        ),
        measureDuration: const Duration(seconds: 5),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
      for (final c in controllers) {
        c.dispose();
      }
    });
  });

  // -------------------------------------------------------------------------
  // Group 5 — Mega stress (Galactic Storm)
  //
  // Single SVG asset with ~2,300 elements running 850 <animate>,
  // 141 <animateTransform>, 60 <animateMotion> concurrently. Stresses every
  // advanced feature simultaneously: SMIL, CSS @keyframes, path morphing,
  // motion paths, animated gradients, filter chains, textPath.
  //
  // 30s warmup + 30s measurement (longer window — animations have varied
  // periods up to 22s, so we want at least one full cycle in the sample).
  // -------------------------------------------------------------------------

  group('mega_stress', () {
    testWidgets('mega_stress_galactic_storm — full_svg_flutter',
        (tester) async {
      final metrics = await _run(
        name: 'Galactic Storm Mega Stress',
        package: _pkgFullSvgPicture,
        scenario: 'mega_stress_galactic_storm',
        tester: tester,
        widgetFactory: () => _wrap(
          ffsf.FSvgPicture.asset(
            _galacticStorm,
            fit: BoxFit.cover,
            autoPlay: true,
          ),
        ),
        warmupDuration: const Duration(seconds: 5),
        measureDuration: const Duration(seconds: 30),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });

    testWidgets('mega_stress_galactic_storm — flutter_svg', (tester) async {
      // flutter_svg cannot animate this asset — measurement captures the
      // cost of *parsing* the document and rendering a static frame.
      final metrics = await _run(
        name: 'Galactic Storm Mega Stress',
        package: _pkgFlutterSvg,
        scenario: 'mega_stress_galactic_storm',
        tester: tester,
        widgetFactory: () => _wrap(
          fsvg.SvgPicture.asset(_galacticStorm, fit: BoxFit.cover),
        ),
        warmupDuration: const Duration(seconds: 5),
        measureDuration: const Duration(seconds: 30),
      );
      _allResults.add(metrics);
      await _saveResult(metrics);
    });
  });

  // -------------------------------------------------------------------------
  // Teardown — write combined suite_results.json
  // -------------------------------------------------------------------------

  tearDownAll(() async {
    if (_allResults.isEmpty) return;

    // TODO: populate deviceInfo, flutterVersion, dartVersion, rendererMode by
    //       reading from dart:io Platform and calling flutter --version.
    final suite = BenchmarkSuiteResult(
      timestamp: DateTime.now().toUtc().toIso8601String(),
      deviceInfo:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      flutterVersion: 'unknown — TODO: read from flutter --version',
      dartVersion: Platform.version,
      rendererMode: 'unknown — TODO: detect impeller vs skia at runtime',
      packageVersions: const {
        'full_svg_flutter': '^1.0.1',
        'flutter_svg': '^2.0.14',
      },
      results: List.unmodifiable(_allResults),
    );

    final dir = Directory('results');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('results/suite_results.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(suite.toJson()),
    );
    print('[benchmark] Combined results written to ${file.path}');
  });
}
