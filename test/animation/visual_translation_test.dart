// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'visual_test_utils.dart';

void main() {
  group('Visual Translation Tests', () {
    testWidgets(
      'translation animation renders correctly',
      (WidgetTester tester) async {
        print('\n${"=" * 80}');
        print('TEST: Translation Animation Visual Rendering');
        print('${"=" * 80}\n');

        const svgData = '''
<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="20" height="20" fill="red">
    <animateTransform
      attributeName="transform"
      type="translate"
      from="0 0"
      to="70 70"
      dur="2s"
      repeatCount="indefinite"/>
  </rect>
</svg>
''';

        print('📸 Building animated SVG widget...');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: AnimatedSvgPicture.string(
                      svgData,
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      autoPlay: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        print('📸 Capturing pixels...');
        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
        final hash = VisualTestUtils.computePixelHash(pixels);

        print('✅ Analysis:');
        print('   Red pixels: ${analysis.pixelCount}');
        print(
          '   Centroid: (${analysis.centroid.dx.toStringAsFixed(1)}, ${analysis.centroid.dy.toStringAsFixed(1)})',
        );
        print('   BBox: ${_formatRect(analysis.boundingBox)}');
        print('   Hash: $hash');

        print(
          '\n📊 Result: ${analysis.pixelCount > 0 ? "✅ SVG RENDERED" : "❌ NOT RENDERED"}',
        );
        print('${"=" * 80}\n');

        // Verify SVG rendered
        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason:
              'Animated SVG with translation should render with visible pixels',
        );

        // Verify bbox is reasonable (20x20 rect)
        expect(
          analysis.boundingBox.width,
          greaterThan(10),
          reason: 'Bounding box should have reasonable width',
        );
        expect(
          analysis.boundingBox.height,
          greaterThan(10),
          reason: 'Bounding box should have reasonable height',
        );

        // Verify rect is somewhere on the canvas
        expect(
          analysis.centroid.dx,
          greaterThan(0),
          reason: 'Centroid X should be positive',
        );
        expect(
          analysis.centroid.dy,
          greaterThan(0),
          reason: 'Centroid Y should be positive',
        );
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}

String _formatRect(Rect rect) {
  return '${rect.width.toStringAsFixed(0)}×${rect.height.toStringAsFixed(0)} '
      'at (${rect.left.toStringAsFixed(0)}, ${rect.top.toStringAsFixed(0)})';
}
