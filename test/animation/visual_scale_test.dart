// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'visual_test_utils.dart';

void main() {
  group('Visual Scale Tests', () {
    testWidgets(
      'scale animation renders correctly',
      (WidgetTester tester) async {
        print('\n${"=" * 80}');
        print('TEST: Scale Animation Visual Rendering');
        print('${"=" * 80}\n');

        const svgData = '''
<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="40" y="40" width="20" height="20" fill="red">
    <animateTransform
      attributeName="transform"
      type="scale"
      from="1"
      to="2"
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
          reason: 'Animated SVG with scale should render with visible pixels',
        );

        // Verify bbox is reasonable (should be larger than 0)
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

        // Verify centroid is near center (scale from origin keeps center)
        expect(
          (analysis.centroid.dx - 400).abs(),
          lessThan(100),
          reason: 'Centroid X should be reasonably centered',
        );
        expect(
          (analysis.centroid.dy - 300).abs(),
          lessThan(100),
          reason: 'Centroid Y should be reasonably centered',
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
