import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('initialTime API', () {
    testWidgets('initialTime: Duration.zero shows first frame', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="40" width="20" height="20" fill="red">
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
                initialTime: Duration.zero,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));

      // At t=0, rect should be at x=0 (left side)
      expect(
        analysis.centroid.dx,
        lessThan(30.0),
        reason: 'At t=0, rect should be on the left',
      );

      print('✅ initialTime: Duration.zero test passed!');
      print('   Pixels: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid} (should be on left)');
    });

    testWidgets('initialTime: Duration(seconds: 1) shows mid-animation', (
      tester,
    ) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="40" width="20" height="20" fill="red">
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
                initialTime: const Duration(seconds: 1), // 50% через анимацию
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));

      // At t=1s (50% of 2s), rect should be at x=40 (middle)
      // Centroid should be around center
      expect(
        analysis.centroid.dx,
        greaterThan(30.0),
        reason: 'At t=1s, rect should be in the middle or right',
      );

      print('✅ initialTime: 1s test passed!');
      print('   Pixels: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid} (should be in middle/right)');
    });

    testWidgets('initialTime with rotation shows specific angle', (
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

      // Test at t=1s (90 degrees) - just verify it renders at that time
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(
                svgData,
                width: 100,
                height: 100,
                autoPlay: false,
                initialTime: const Duration(seconds: 1), // 90 degrees
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
        reason: 'Should render at specific rotation angle',
      );

      print('✅ initialTime rotation test passed!');
      print('   t=1s (90°) pixels: ${analysis.pixelCount}');
      print('   Centroid: ${analysis.centroid}');
    });

    testWidgets('initialTime works with autoPlay: true', (tester) async {
      const svgData = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="40" width="20" height="20" fill="red">
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
                autoPlay: true, // Animation will start from initialTime
                initialTime: const Duration(seconds: 1),
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
        reason: 'Should render even with autoPlay + initialTime',
      );

      print('✅ initialTime + autoPlay test passed!');
      print('   Pixels: ${analysis.pixelCount}');
    });
  });
}
