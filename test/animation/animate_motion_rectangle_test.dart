// ignore_for_file: avoid_print
/// Reproduces the gallery "Basic Motion" page: a blue dot following a
/// rectangular SMIL `<animateMotion>` path. Probes (1) computeValue
/// positions at explicit initialTime, (2) the live transform attribute
/// the engine actually writes under autoPlay.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _svg = '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath1" d="M50,50 L250,50 L250,150 L50,150 Z"
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  <use href="#motionPath1"/>
  <circle r="8" fill="#2196F3">
    <animateMotion
      path="M50,50 L250,50 L250,150 L50,150 Z"
      dur="4s"
      repeatCount="indefinite"/>
  </circle>
</svg>
''';

({double x, double y, int count}) _findBlueDot(
    Uint8List rgba, int width, int height) {
  int totalX = 0, totalY = 0, count = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2], a = rgba[i + 3];
      if (a > 200 && b > 180 && g > 100 && g < 200 && r < 100) {
        totalX += x;
        totalY += y;
        count++;
      }
    }
  }
  if (count == 0) return (x: -1, y: -1, count: 0);
  return (x: totalX / count, y: totalY / count, count: count);
}

Future<Uint8List> _renderAt(
  WidgetTester tester, {
  required Duration initialTime,
}) async {
  const width = 300.0, height = 200.0;
  tester.view.physicalSize = const Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: width,
            height: height,
            child: AnimatedSvgPicture.string(
              _svg,
              width: width,
              height: height,
              fit: BoxFit.fill,
              autoPlay: false,
              initialTime: initialTime,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return await tester.runAsync<Uint8List>(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }) as Uint8List;
}

int? _totalDurationMs(AnimatedSvgController c) {
  final snap = c.captureDebugSnapshot();
  final d = snap?['totalDurationMs'];
  return d is int ? d : (d is num ? d.toInt() : null);
}

String? _circleTransform(AnimatedSvgController c) {
  final snap = c.captureDebugSnapshot();
  final elements =
      (snap?['elements'] as List?)?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[];
  for (final e in elements) {
    if (e['tag'] == 'circle') {
      final attrs = (e['attrs'] as Map?)?.cast<String, String>();
      return attrs?['transform'];
    }
  }
  return null;
}

void main() {
  // Path = rectangle from (50,50) -> (250,50) -> (250,150) -> (50,150) -> back.
  // Total length = 200 + 100 + 200 + 100 = 600.  dur=4s → speed=0.15 px/ms.
  // At progress t∈[0,1]:
  //   t=0   → (50, 50)
  //   t=1/4 → distance=150 → (200, 50)            (top middle)
  //   t=1/3 → distance=200 → (250, 50)            (top-right corner)
  //   t=1/2 → distance=300 → (250, 150)           (bottom-right corner)
  //   t=2/3 → distance=400 → (150, 150)           (bottom middle)
  //   t=5/6 → distance=500 → (50, 150)            (bottom-left corner)
  //   t=1   → distance=600 → (50, 50)             (back to start)

  testWidgets('initialTime renders dot at expected path positions',
      (tester) async {
    final samples = <(Duration, double, double)>[
      (const Duration(milliseconds: 0),    50.0,  50.0),
      (const Duration(milliseconds: 1000), 200.0, 50.0),  // 25% → top middle
      (const Duration(milliseconds: 1333), 250.0, 50.0),  // ~33% top-right
      (const Duration(milliseconds: 2000), 250.0, 150.0), // 50% bottom-right
      (const Duration(milliseconds: 2667), 150.0, 150.0), // ~67% bottom middle
      (const Duration(milliseconds: 3333), 50.0,  150.0), // ~83% bottom-left
    ];

    print('Basic Motion · initialTime → centroid:');
    for (final s in samples) {
      final t = s.$1, ex = s.$2, ey = s.$3;
      final pixels = await _renderAt(tester, initialTime: t);
      final c = _findBlueDot(pixels, 300, 200);
      print('  t=${t.inMilliseconds.toString().padLeft(4)}ms → '
          'expected (${ex.toStringAsFixed(0)},${ey.toStringAsFixed(0)})'
          '  actual (${c.x.toStringAsFixed(1)},${c.y.toStringAsFixed(1)},n=${c.count})');
      expect((c.x - ex).abs(), lessThan(3.0),
          reason: 't=${t.inMilliseconds} x off');
      expect((c.y - ey).abs(), lessThan(3.0),
          reason: 't=${t.inMilliseconds} y off');
    }
  });

  testWidgets('autoPlay: live transform attribute matches path positions',
      (tester) async {
    const width = 300.0, height = 200.0;
    tester.view.physicalSize = const Size(width, height);
    tester.view.devicePixelRatio = 1.0;

    final controller = AnimatedSvgController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: AnimatedSvgPicture.string(
              _svg,
              controller: controller,
              width: width,
              height: height,
              fit: BoxFit.fill,
              autoPlay: true,
            ),
          ),
        ),
      ),
    );

    print('  total duration (ms): ${_totalDurationMs(controller)}');
    print('  pump#  | currentTimeMs | circle.transform');
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      final ct = controller.currentTimeMs ?? 0;
      final tr = _circleTransform(controller);
      print('  $i      | ${ct.toStringAsFixed(0).padLeft(5)}        | $tr');
    }
  });
}
