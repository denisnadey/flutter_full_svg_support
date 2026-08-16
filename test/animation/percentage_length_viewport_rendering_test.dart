import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_painter.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

import 'visual_test_utils.dart';

void main() {
  Future<PixelAnalysis> renderRedSvg(WidgetTester tester, String svg) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            child: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    final pixels = await VisualTestUtils.captureWidgetPixels(tester);
    return VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
  }

  group('viewport-relative percentage lengths', () {
    testWidgets('resolves use x and y against the parent SVG viewport', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <rect id="source" width="20" height="20" fill="red"/>
          </defs>
          <use href="#source" x="50%" y="25%"/>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      expect(analysis.pixelCount, greaterThan(100));
      expect(analysis.boundingBox.left, greaterThan(80));
      expect(analysis.boundingBox.top, greaterThan(15));
    });

    testWidgets('resolves nested SVG viewport x y width and height', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <svg x="25%" y="20%" width="50%" height="50%"
               viewBox="0 0 100 100" preserveAspectRatio="none">
            <rect width="100" height="100" fill="red"/>
          </svg>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      expect(analysis.pixelCount, greaterThan(1000));
      expect(analysis.boundingBox.left, greaterThan(40));
      expect(analysis.boundingBox.width, greaterThan(80));
      expect(analysis.boundingBox.height, greaterThan(40));
    });

    test('resolves image x y width and height in renderer geometry', () {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <image id="image" x="50%" y="25%" width="25%" height="50%"/>
        </svg>
      ''';

      final document = SvgParser.parse(svg);
      final image = document.root.findById('image');
      final bounds = AnimatedSvgPainter(
        document: document,
      ).measureNodeBounds(image!);

      expect(bounds.left, 100);
      expect(bounds.top, 25);
      expect(bounds.width, 50);
      expect(bounds.height, 50);
    });

    testWidgets('resolves normal use viewport width and height percentages', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <symbol id="source" viewBox="0 0 100 100"
                    preserveAspectRatio="none">
              <rect width="100" height="100" fill="red"/>
            </symbol>
          </defs>
          <use href="#source" x="25%" width="50%" height="50%"/>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      expect(analysis.boundingBox.left, closeTo(50, 1));
      expect(analysis.objectWidth, closeTo(100, 1));
      expect(analysis.objectHeight, closeTo(50, 1));
    });

    testWidgets('resolves percentage use geometry inside clip paths', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <rect id="source" width="40" height="20"/>
            <clipPath id="clip">
              <use href="#source" x="25%" y="25%"/>
            </clipPath>
          </defs>
          <rect width="200" height="100" fill="red"
                clip-path="url(#clip)"/>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      // The clip geometry should begin at document x=50, not the raw x=25.
      expect(analysis.boundingBox.left, closeTo(50, 1));
      expect(analysis.boundingBox.top, closeTo(25, 1));
      expect(analysis.objectWidth, greaterThan(35));
      expect(analysis.objectHeight, greaterThan(15));
    });

    testWidgets('resolves percentage use geometry inside masks', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <rect id="source" width="40" height="20" fill="white"/>
            <mask id="mask" type="luminance"
                  maskUnits="userSpaceOnUse"
                  maskContentUnits="userSpaceOnUse"
                  x="0" y="0" width="200" height="100">
              <use href="#source" x="25%" y="25%"/>
            </mask>
          </defs>
          <rect width="200" height="100" fill="red" mask="url(#mask)"/>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      expect(analysis.boundingBox.left, closeTo(50, 1));
      expect(analysis.boundingBox.top, closeTo(25, 1));
      expect(analysis.objectWidth, greaterThan(35));
      expect(analysis.objectHeight, greaterThan(15));
    });
    testWidgets('resolves percentage use viewport inside clip paths', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <symbol id="source" viewBox="0 0 100 100">
              <rect width="100" height="100"/>
            </symbol>
            <clipPath id="clip">
              <use href="#source" x="25%" width="50%" height="100%"/>
            </clipPath>
          </defs>
          <rect width="200" height="100" fill="red"
                clip-path="url(#clip)"/>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      // x=25% and width=50% resolve to a 100x100 clip in this viewport.
      expect(analysis.boundingBox.left, closeTo(50, 1));
      expect(analysis.objectWidth, greaterThan(90));
    });

    testWidgets(
      'keeps percentage use coordinates viewport-relative in objectBoundingBox clip paths',
      (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <symbol id="source" viewBox="0 0 100 100"
                      preserveAspectRatio="none">
                <rect width="100" height="100"/>
              </symbol>
              <clipPath id="clip" clipPathUnits="objectBoundingBox">
                <use href="#source" x="25%" width="50%" height="100%"/>
              </clipPath>
            </defs>
            <rect x="20" y="30" width="100" height="40" fill="red"
                  clip-path="url(#clip)"/>
          </svg>
        ''';

        final analysis = await renderRedSvg(tester, svg);

        // Percentages in clipPath content use the SVG viewport (x=50), then
        // clipPathUnits maps that coordinate through the target bounding box.
        expect(analysis.pixelCount, 0);
      },
    );

    testWidgets('resolves foreignObject and nested SVG viewport percentages', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100">
          <foreignObject x="25%" y="10%" width="50%" height="50%">
            <svg x="10%" y="20%" width="80%" height="60%"
                 viewBox="0 0 80 60" preserveAspectRatio="none">
              <rect width="80" height="60" fill="red"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final analysis = await renderRedSvg(tester, svg);

      expect(analysis.pixelCount, greaterThan(1000));
      expect(analysis.boundingBox.left, greaterThan(55));
      expect(analysis.boundingBox.top, greaterThan(15));
      expect(analysis.boundingBox.width, greaterThan(70));
      expect(analysis.boundingBox.height, greaterThan(25));
    });
  });

  test('resolves percentage basic-shape bounds for fill-box and filters', () {
    const svg = '''
      <svg viewBox="0 0 200 100">
        <rect id="rect" x="25%" y="20%" width="50%" height="40%"/>
        <circle id="circle" cx="75%" cy="50%" r="10%"/>
        <ellipse id="ellipse" cx="25%" cy="75%" rx="10%" ry="20%"/>
        <line id="line" x1="10%" y1="20%" x2="80%" y2="90%"/>
      </svg>
    ''';

    final document = SvgParser.parse(svg);
    final painter = AnimatedSvgPainter(document: document);

    expect(
      painter.measureNodeBounds(document.root.findById('rect')!),
      const Rect.fromLTWH(50, 20, 100, 40),
    );
    final circle = painter.measureNodeBounds(document.root.findById('circle')!);
    expect(circle.center, const Offset(150, 50));
    expect(circle.width, closeTo(31.6227766, 0.0001));
    expect(circle.height, closeTo(31.6227766, 0.0001));
    expect(
      painter.measureNodeBounds(document.root.findById('ellipse')!),
      const Rect.fromLTWH(30, 55, 40, 40),
    );
    expect(
      painter.measureNodeBounds(document.root.findById('line')!),
      const Rect.fromLTRB(20, 20, 160, 90),
    );
  });
}
