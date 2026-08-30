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

    test(
      'href-inherited userSpaceOnUse gradient units stay viewport-relative',
      () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <linearGradient id="base" gradientUnits="userSpaceOnUse"/>
            <linearGradient id="derived" href="#base"/>
          </defs>
        </svg>
      ''');
        final derived = document.root.findById('derived')!;

        expect(
          smilPercentageSemanticsForAttribute(
            'x2',
            targetNode: derived,
            document: document,
          ),
          SmilPercentageSemantics.horizontalLength,
        );
      },
    );

    test('pattern patternUnits resolves through the href chain', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <pattern id="base" patternUnits="userSpaceOnUse"
                     width="10" height="10"/>
            <pattern id="child" href="#base" width="20" height="20"/>
            <pattern id="explicit" href="#base" patternUnits="objectBoundingBox"
                     width="0.5" height="0.5"/>
          </defs>
        </svg>
      ''');
      final child = document.root.findById('child')!;
      final explicit = document.root.findById('explicit')!;

      // The child inherits userSpaceOnUse through the href chain, so its own
      // percentage width resolves against the viewport width (not the
      // bounding box) — matching the painter's resolved units.
      expect(
        smilPercentageSemanticsForAttribute(
          'width',
          targetNode: child,
          document: document,
        ),
        SmilPercentageSemantics.horizontalLength,
      );
      // The nearest explicit declaration wins over the inherited one.
      expect(
        smilPercentageSemanticsForAttribute(
          'width',
          targetNode: explicit,
          document: document,
        ),
        SmilPercentageSemantics.objectBoundingBox,
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

  testWidgets(
    'inline style percentage wins over the raw presentation attribute',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <rect width="200" height="100" fill="red"
              opacity="25%" style="opacity: 50%"/>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
      );
      // The inline 50% wins, so alpha ≈ 127, not 64 from the 25% presentation.
      expect(_pixelAt(pixels, 200, 100, 50)[3], closeTo(127, 12));
    },
  );

  testWidgets(
    'stylesheet percentage wins over the raw presentation attribute',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <style>#target { opacity: 50%; }</style>
        <rect id="target" width="200" height="100" fill="red" opacity="25%"/>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
      );
      expect(_pixelAt(pixels, 200, 100, 50)[3], closeTo(127, 12));
    },
  );

  testWidgets(
    'href-inherited userSpaceOnUse gradient animates x2 as a viewport length',
    (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <linearGradient id="base" gradientUnits="userSpaceOnUse"
                           x1="0" y1="0" x2="100" y2="0">
            <stop offset="0" stop-color="red"/>
            <stop offset="1" stop-color="blue"/>
          </linearGradient>
          <linearGradient id="derived" href="#base">
            <animate attributeName="x2" from="0%" to="100%" dur="2s"/>
          </linearGradient>
        </defs>
        <rect width="200" height="100" fill="url(#derived)"/>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 200,
        height: 100,
        initialTime: const Duration(seconds: 1),
      );
      // x2 = 50% of the 200-wide viewBox = 100, so the gradient spans x=0..100;
      // x=50 is its midpoint (red-dominant), not solid blue.
      final mid = _pixelAt(pixels, 200, 50, 50);
      expect(mid[0], greaterThan(80));
    },
  );

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

  testWidgets('animated text dx percentage places the glyph at x=100', (
    tester,
  ) async {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <text x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="dx" from="0%" to="100%" dur="2s"/>
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
    // dx = 50% of 200 = 100 at the midpoint, so the glyph moves to x≈100
    // instead of the numeric 50.
    expect(firstRed!, greaterThan(70));
  });

  testWidgets(
    'animated text dx percentage shifts glyph-precision hit targets',
    (tester) async {
      final traceEvents = <SvgTraceEvent>[];
      const svg = '''
      <svg viewBox="0 0 200 100">
        <text id="target" x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="dx" from="0%" to="100%" dur="2s"/>
        </text>
      </svg>
    ''';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: AnimatedSvgPicture.string(
                svg,
                autoPlay: false,
                initialTime: const Duration(seconds: 1),
                onTrace: traceEvents.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final topLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
      bool hitTarget() => traceEvents.any(
        (event) =>
            event.category == 'event' &&
            event.message == 'Tap detected' &&
            event.data['targetId'] == 'target',
      );

      // dx = 50% of 200 = 100 at the midpoint, so the glyph sits near x=100.
      traceEvents.clear();
      await tester.tapAt(topLeft + const Offset(110, 50));
      await tester.pump();
      expect(hitTarget(), isTrue);

      // The glyph no longer occupies its pre-animation position at x≈0;
      // the glyph-precision path must not report a stale hit there.
      traceEvents.clear();
      await tester.tapAt(topLeft + const Offset(10, 50));
      await tester.pump();
      expect(hitTarget(), isFalse);
    },
  );

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
      // The correct objectBoundingBox consumer behavior is deferred (#46).
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

  group('discrete and set raw percentage values', () {
    testWidgets('discrete percentage dx values place the glyph at x=100', (
      tester,
    ) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <text x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="dx" values="50%;0%"
                   calcMode="discrete" dur="2s"/>
        </text>
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
      // The discrete segment selects the raw string "50%", which must resolve
      // against the 200-wide viewport (dx = 100) instead of collapsing to the
      // numeric fallback at x=0.
      expect(firstRed!, greaterThan(70));
    });

    testWidgets('set percentage dx places the glyph at x=100', (tester) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <text x="0" y="60" font-size="40" fill="red">X
          <set attributeName="dx" to="50%" dur="4s"/>
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
      // <set> assigns the raw "50%" string for its whole active period.
      expect(firstRed!, greaterThan(70));
    });

    testWidgets('discrete percentage x values place the glyph at x=50', (
      tester,
    ) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <text x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="x" values="25%;75%"
                   calcMode="discrete" dur="2s"/>
        </text>
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
      // First discrete segment selects "25%" of the 200-wide viewport = 50.
      expect(firstRed!, closeTo(50, 5));
    });

    testWidgets('discrete percentage dx shifts glyph-precision hit targets', (
      tester,
    ) async {
      final traceEvents = <SvgTraceEvent>[];
      const svg = '''
      <svg viewBox="0 0 200 100">
        <text id="target" x="0" y="60" font-size="40" fill="red">X
          <animate attributeName="dx" values="50%;0%"
                   calcMode="discrete" dur="2s"/>
        </text>
      </svg>
    ''';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: AnimatedSvgPicture.string(
                svg,
                autoPlay: false,
                initialTime: const Duration(milliseconds: 500),
                onTrace: traceEvents.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final topLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
      bool hitTarget() => traceEvents.any(
        (event) =>
            event.category == 'event' &&
            event.message == 'Tap detected' &&
            event.data['targetId'] == 'target',
      );

      // dx = 50% of 200 = 100 during the first discrete segment, so the
      // glyph sits near x=100 and the hit path must follow it.
      traceEvents.clear();
      await tester.tapAt(topLeft + const Offset(110, 50));
      await tester.pump();
      expect(hitTarget(), isTrue);

      // The pre-animation position at x≈0 must not report a stale hit.
      traceEvents.clear();
      await tester.tapAt(topLeft + const Offset(10, 50));
      await tester.pump();
      expect(hitTarget(), isFalse);
    });
  });

  group('tref and textPath percentage classification', () {
    testWidgets('animated tref percentage dx shifts the referenced text', (
      tester,
    ) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <text id="src">X</text>
        </defs>
        <text x="0" y="60" font-size="40" fill="red">
          <tref href="#src">
            <animate attributeName="dx" from="0%" to="100%" dur="2s"/>
          </tref>
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
      // tref is a migrated text consumer: dx = 50% of 200 = 100 at the
      // midpoint, so the referenced glyph paints near x=100 instead of the
      // x=0 produced when the deferred wrapper is discarded.
      expect(firstRed!, greaterThan(70));
    });

    testWidgets('animated textPath percentage dx keeps the text on its path', (
      tester,
    ) async {
      const svg = '''
      <svg viewBox="0 0 200 100">
        <defs>
          <path id="p" d="M 10 60 L 190 60"/>
        </defs>
        <text font-size="40" fill="red">
          <textPath href="#p">XX
            <animate attributeName="dx" from="0%" to="100%" dur="2s"/>
          </textPath>
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
      // Narrowed classification keeps textPath dx numeric: the text stays at
      // the path start (x≈10) instead of shifting with the discarded (or
      // honored) percentage offset.
      expect(firstRed!, lessThan(30));
    });
  });

  group('continuous mixed percentage/absolute dx lists', () {
    testWidgets('interpolated mixed dx list paints the first glyph at x=150', (
      tester,
    ) async {
      const svg = '''
      <svg viewBox="0 0 300 100">
        <text x="0" y="60" font-size="40" fill="red">XX
          <animate attributeName="dx" from="0% 0" to="100% 0" dur="2s"/>
        </text>
      </svg>
    ''';
      final pixels = await _renderSvgPixels(
        tester,
        svg,
        width: 300,
        height: 100,
        initialTime: const Duration(seconds: 1),
      );
      final firstRed = _firstRedColumn(pixels, 300, 100);
      expect(firstRed, isNotNull);
      // At the midpoint the interpolated list is [50%-wrapper, 0.0]: the
      // first member resolves to 150 (50% of 300) and the numeric member
      // stays an absolute 0 for the second character. Rejecting the numeric
      // member collapses the whole list and paints at x=0.
      expect(firstRed!, closeTo(150, 8));
    });

    testWidgets(
      'interpolated mixed dx list shifts glyph-precision hit targets',
      (tester) async {
        final traceEvents = <SvgTraceEvent>[];
        const svg = '''
      <svg viewBox="0 0 300 100">
        <text id="target" x="0" y="60" font-size="40" fill="red">XX
          <animate attributeName="dx" from="0% 0" to="100% 0" dur="2s"/>
        </text>
      </svg>
    ''';
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 100,
                child: AnimatedSvgPicture.string(
                  svg,
                  autoPlay: false,
                  initialTime: const Duration(seconds: 1),
                  onTrace: traceEvents.add,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final topLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
        bool hitTarget() => traceEvents.any(
          (event) =>
              event.category == 'event' &&
              event.message == 'Tap detected' &&
              event.data['targetId'] == 'target',
        );

        // The glyphs sit at x≈150 during the midpoint state, so the shifted
        // position hits and the pre-animation position must not.
        traceEvents.clear();
        await tester.tapAt(topLeft + const Offset(165, 50));
        await tester.pump();
        expect(hitTarget(), isTrue);

        traceEvents.clear();
        await tester.tapAt(topLeft + const Offset(10, 50));
        await tester.pump();
        expect(hitTarget(), isFalse);
      },
    );
  });
}
