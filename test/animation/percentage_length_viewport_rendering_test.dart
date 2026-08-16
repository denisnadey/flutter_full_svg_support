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
}
