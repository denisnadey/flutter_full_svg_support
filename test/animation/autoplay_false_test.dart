// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('autoPlay: false', () {
    testWidgets('SVG renders first frame when autoPlay is false', (
      tester,
    ) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="40" y="40" width="20" height="20" fill="red">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="4s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      // Build widget with autoPlay: false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
                autoPlay: false, // ← Key parameter!
              ),
            ),
          ),
        ),
      );

      // Initial build
      await tester.pump();

      // Capture pixels
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Verify: SVG should render even with autoPlay: false
      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'SVG should render first frame even when autoPlay is false',
      );

      print('✅ autoPlay: false test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
      print('   BoundingBox: ${analysis.boundingBox}');
    });

    testWidgets('Animation does not progress when autoPlay is false', (
      tester,
    ) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="20" height="20" fill="red">
            <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
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
                autoPlay: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Capture initial state
      final pixels1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis1 = VisualTestUtils.analyzeRedPixels(pixels1, 800, 600);

      // Wait some time
      await tester.pump(const Duration(milliseconds: 500));

      // Capture again
      final pixels2 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis2 = VisualTestUtils.analyzeRedPixels(pixels2, 800, 600);

      // Verify: Animation should NOT progress (same position)
      expect(
        (analysis1.centroid.dx - analysis2.centroid.dx).abs(),
        lessThan(1.0),
        reason:
            'Animation should not progress when autoPlay is false (centroid should stay the same)',
      );

      print('✅ Animation freeze test passed!');
      print('   Initial centroid: ${analysis1.centroid}');
      print('   After 500ms: ${analysis2.centroid}');
      print(
        '   Delta: ${(analysis1.centroid.dx - analysis2.centroid.dx).abs()}px',
      );
    });

    testWidgets('SVG renders correctly with autoPlay: true for comparison', (
      tester,
    ) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="40" y="40" width="20" height="20" fill="red">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="4s"
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
                autoPlay: true, // For comparison
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));

      print('✅ autoPlay: true (control) test passed!');
      print('   Pixels found: ${analysis.pixelCount}');
    });
  });
}
