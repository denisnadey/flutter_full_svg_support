import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/svg_length_resolver.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

Future<Uint8List> _renderSvgPixels(
  WidgetTester tester,
  String svg, {
  required int width,
  required int height,
  Duration initialTime = Duration.zero,
}) async {
  final repaintBoundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: AnimatedSvgPicture.string(
              svg,
              autoPlay: false,
              initialTime: initialTime,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final pixels = await tester.runAsync<Uint8List?>(() async {
    final boundary =
        repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });

  expect(pixels, isNotNull);
  return pixels!;
}

List<int> _pixelAt(Uint8List pixels, int width, int x, int y) {
  final offset = ((y * width) + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

/// Leftmost column containing a pixel that is clearly red.
int? _firstRedColumn(Uint8List pixels, int width, int height) {
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      final p = _pixelAt(pixels, width, x, y);
      if (p[0] > 200 && p[1] < 100 && p[2] < 100 && p[3] > 200) {
        return x;
      }
    }
  }
  return null;
}

void main() {
  group('SmilPercentageSemantics classification', () {
    test('only migrated objectBoundingBox consumers are classified', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <linearGradient id="g">
              <stop offset="0" stop-color="red"/>
            </linearGradient>
            <pattern id="p" patternUnits="objectBoundingBox"
                     width="0.5" height="0.5"/>
            <clipPath id="c">
              <rect id="clip-rect" width="0.5"/>
            </clipPath>
            <mask id="m" x="0" width="1" height="1"/>
          </defs>
        </svg>
      ''');
      final gradient = document.root.findById('g')!;
      final pattern = document.root.findById('p')!;
      final clipRect = document.root.findById('clip-rect')!;
      final mask = document.root.findById('m')!;

      expect(
        smilPercentageSemanticsForAttribute('x1', targetNode: gradient),
        SmilPercentageSemantics.objectBoundingBox,
      );
      expect(
        smilPercentageSemanticsForAttribute('width', targetNode: pattern),
        SmilPercentageSemantics.objectBoundingBox,
      );
      expect(
        smilPercentageSemanticsForAttribute('x', targetNode: clipRect),
        SmilPercentageSemantics.none,
      );
      expect(
        smilPercentageSemanticsForAttribute('x', targetNode: mask),
        SmilPercentageSemantics.none,
      );
    });
  });

  group('resolveSvgNumericAttributeValue', () {
    test('resolves opacity as a unit interval', () {
      final document = SvgParser.parse(
        '<svg viewBox="0 0 200 100"><rect id="r"/></svg>',
      );
      final node = document.root.findById('r')!;
      expect(
        resolveSvgNumericAttributeValue(
          node,
          const SvgLengthPercentageValue(absolute: 0, percentage: 50),
          'opacity',
        ),
        0.5,
      );
    });

    test('resolves stroke-width against the normalized diagonal', () {
      final document = SvgParser.parse(
        '<svg viewBox="0 0 200 100"><rect id="r"/></svg>',
      );
      final node = document.root.findById('r')!;
      // normalized diagonal = sqrt((200^2 + 100^2) / 2) ≈ 158.11; 10% ≈ 15.81.
      expect(
        resolveSvgNumericAttributeValue(
          node,
          const SvgLengthPercentageValue(absolute: 0, percentage: 10),
          'stroke-width',
        ),
        closeTo(15.81, 0.1),
      );
    });
  });

  testWidgets('animated opacity percentage reaches 0.5 at the midpoint', (
    tester,
  ) async {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <rect width="200" height="100" fill="red" opacity="0">
          <animate attributeName="opacity" from="0" to="100%" dur="2s"/>
        </rect>
      </svg>
    ''';
    final pixels = await _renderSvgPixels(
      tester,
      svg,
      width: 200,
      height: 100,
      initialTime: const Duration(seconds: 1),
    );
    final center = _pixelAt(pixels, 200, 100, 50);
    expect(center[3], closeTo(127, 12));
  });

  testWidgets('animated gradient x2 percentage reaches 50% at the midpoint', (
    tester,
  ) async {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <linearGradient id="g">
            <stop offset="0" stop-color="red"/>
            <stop offset="1" stop-color="blue"/>
            <animate attributeName="x2" from="100%" to="0%" dur="2s"/>
          </linearGradient>
        </defs>
        <rect width="200" height="100" fill="url(#g)"/>
      </svg>
    ''';
    final pixels = await _renderSvgPixels(
      tester,
      svg,
      width: 200,
      height: 100,
      initialTime: const Duration(seconds: 1),
    );
    // x2=50% means the gradient ends at x=100; x=150 is past it and blue.
    final sample = _pixelAt(pixels, 200, 150, 50);
    expect(sample[2], greaterThan(sample[0]));
    expect(sample[2], greaterThan(180));
  });

  testWidgets('animated text x percentage places the glyph at x=100', (
    tester,
  ) async {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <text x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="x" from="0" to="100%" dur="2s"/>
        </text>
      </svg>
    ''';
    final pixels = await _renderSvgPixels(
      tester,
      svg,
      width: 200,
      height: 100,
      initialTime: const Duration(seconds: 1),
    );
    final firstRed = _firstRedColumn(pixels, 200, 100);
    expect(firstRed, isNotNull);
    expect(firstRed!, greaterThan(70));
  });

  testWidgets(
    'paced mixed percentage on a dimensionless root uses the widget viewport',
    (tester) async {
      const svg = '''
      <svg>
        <rect x="0" y="0" width="10" height="10" fill="red">
          <animate attributeName="x" values="0;100%;200" calcMode="paced"
                   dur="2s"/>
        </rect>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
        initialTime: const Duration(milliseconds: 500),
      );
      final firstRed = _firstRedColumn(pixels, 200, 100);
      expect(firstRed, isNotNull);
      expect(firstRed!, closeTo(50, 2));
    },
  );

  testWidgets('animated pattern width percentage keeps the fill visible', (
    tester,
  ) async {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <pattern id="p" patternUnits="userSpaceOnUse"
                   width="10" height="10">
            <rect width="10" height="10" fill="red"/>
            <animate attributeName="width" from="10%" to="20%" dur="2s"/>
          </pattern>
        </defs>
        <rect width="200" height="100" fill="url(#p)"/>
      </svg>
    ''';
    final pixels = await _renderSvgPixels(
      tester,
      svg,
      width: 200,
      height: 100,
      initialTime: const Duration(seconds: 1),
    );
    // At the midpoint width resolves to 15% of 200 = 30, so the pattern tiles
    // remain visible rather than collapsing to zero width.
    expect(_firstRedColumn(pixels, 200, 100), isNotNull);
  });

  testWidgets(
    'paced percentage on a use x attribute resolves against the outer viewport',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <rect id="source" width="10" height="10" fill="red"/>
        </defs>
        <use href="#source" x="0">
          <animate attributeName="x" values="0;100%;200" calcMode="paced"
                   dur="2s"/>
        </use>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
        initialTime: const Duration(milliseconds: 500),
      );
      final firstRed = _firstRedColumn(pixels, 200, 100);
      expect(firstRed, isNotNull);
      expect(firstRed!, closeTo(50, 2));
    },
  );

  testWidgets(
    'clipPath objectBoundingBox content with an animated percentage stays numeric',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <clipPath id="c" clipPathUnits="objectBoundingBox">
            <rect width="0.5" height="1">
              <animate attributeName="x" from="0%" to="100%" dur="2s"/>
            </rect>
          </clipPath>
        </defs>
        <rect width="200" height="100" fill="red" clip-path="url(#c)"/>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
        initialTime: const Duration(seconds: 1),
      );
      // Narrowed classification keeps the clip content numeric, so the target is
      // fully clipped (numeric 50 is outside the 0..1 objectBoundingBox fraction
      // range) rather than leaking a viewport wrapper into the bbox transform.
      // The correct objectBoundingBox consumer behavior is deferred (#42).
      expect(_firstRedColumn(pixels, 200, 100), isNull);
    },
  );

  testWidgets(
    'objectBoundingBox mask region with an animated percentage stays numeric',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <mask id="m" maskUnits="objectBoundingBox"
                maskContentUnits="userSpaceOnUse"
                x="0%" y="0" width="50%" height="100%">
            <rect width="200" height="100" fill="white"/>
            <animate attributeName="x" from="0%" to="100%" dur="2s"/>
          </mask>
        </defs>
        <rect width="200" height="100" fill="red" mask="url(#m)"/>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
        initialTime: const Duration(seconds: 1),
      );
      // Narrowed classification keeps the mask region numeric and bounded.
      expect(_firstRedColumn(pixels, 200, 100), isNotNull);
    },
  );
}
