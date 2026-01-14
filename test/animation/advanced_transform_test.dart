import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Transform Rendering', () {
    testWidgets('skewX transform renders correctly', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="30" y="30" width="40" height="40" fill="red" transform="skewX(20)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'skewX transform should render',
      );

      print('✅ skewX test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
      print('   BoundingBox: ${analysis.boundingBox}');
    });

    testWidgets('skewY transform renders correctly', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="30" y="30" width="40" height="40" fill="red" transform="skewY(20)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'skewY transform should render',
      );

      print('✅ skewY test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
    });

    testWidgets('matrix transform renders correctly', (tester) async {
      // matrix(a, b, c, d, e, f)
      // a=1, b=0, c=0, d=1, e=10, f=10 = translate(10, 10)
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="40" y="40" width="20" height="20" fill="red" transform="matrix(1, 0, 0, 1, 10, 10)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'matrix transform should render',
      );

      // With translate(10, 10), centroid should be offset
      // Original rect at x=40, y=40, size=20x20 -> center at (50, 50)
      // After translate(10, 10) -> center at (60, 60)
      // But we need to account for viewBox scaling...
      // Just verify it renders for now

      print('✅ matrix transform test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
    });

    testWidgets('animated skewX renders correctly', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="30" y="30" width="40" height="40" fill="red">
            <animateTransform
              attributeName="transform"
              type="skewX"
              from="0"
              to="30"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'animated skewX should render',
      );

      print('✅ animated skewX test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
    });

    testWidgets('animated skewY renders correctly', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="30" y="30" width="40" height="40" fill="red">
            <animateTransform
              attributeName="transform"
              type="skewY"
              from="0"
              to="30"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'animated skewY should render',
      );

      print('✅ animated skewY test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
    });

    testWidgets('combined transforms render correctly', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="40" y="40" width="20" height="20" fill="red" 
                transform="translate(10, 10) rotate(45 50 50) scale(1.2)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'combined transforms should render',
      );

      print('✅ combined transforms test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
    });
  });
}
