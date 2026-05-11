// ignore_for_file: avoid_print
// Quick debug test — not part of the test suite
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

void main() {
  // Test 1: pure feColorMatrix — does it apply correctly?
  testWidgets('feColorMatrix replaces color with constant', (tester) async {
    const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="cm">
      <!-- Replace all RGB with constants, keep alpha -->
      <feColorMatrix type="matrix"
        values="0 0 0 0 1  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="blue" filter="url(#cm)"/>
</svg>''';
    tester.view.physicalSize = const Size(100, 100);
    tester.view.devicePixelRatio = 1.0;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(key: key, child: SizedBox(width:100, height:100,
        child: AnimatedSvgPicture.string(svg, width: 100, height: 100))),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final px = await tester.runAsync<Uint8List?>(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return bd?.buffer.asUint8List();
    });
    final c = (cy:50, cx:50, w:100);
    final idx = (c.cy * c.w + c.cx) * 4;
    print('[CM test] center: rgb(${px![idx]},${px[idx+1]},${px[idx+2]},a=${px[idx+3]})');
    // Expect RED (ff,0,0) not blue
    expect(px[idx], greaterThan(200), reason: 'Color matrix should have replaced blue with red');
  });

  // Test 2: feComposite arithmetic k2=-1, k3=1 with simple shapes
  testWidgets('feComposite arithmetic k2=-1 k3=1 is not solid black', (tester) async {
    const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="comp" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
      <feComposite operator="arithmetic" k2="-1" k3="1" in="blur" in2="SourceGraphic"/>
    </filter>
  </defs>
  <rect x="20" y="20" width="60" height="60" fill="lime" filter="url(#comp)"/>
</svg>''';
    tester.view.physicalSize = const Size(100, 100);
    tester.view.devicePixelRatio = 1.0;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(key: key, child: SizedBox(width:100, height:100,
        child: AnimatedSvgPicture.string(svg, width: 100, height: 100))),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final px = await tester.runAsync<Uint8List?>(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return bd?.buffer.asUint8List();
    });
    final idx = (50 * 100 + 50) * 4;
    print('[Composite test] center: rgb(${px![idx]},${px[idx+1]},${px[idx+2]},a=${px[idx+3]})');
    // At center: should be transparent (the interior is masked out by inner shadow)
    expect(px[idx+3], lessThan(50), reason: 'Inner shadow center should be transparent');
  });
}
