import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_controller.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('AnimatedSvgController', () {
    const simpleSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="30" height="30" fill="red">
    <animate attributeName="x" from="10" to="60" dur="2s" repeatCount="indefinite"/>
  </rect>
</svg>
''';

    const reverseSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="30" height="30" fill="red">
    <animate attributeName="x" from="10" to="60" dur="2s" fill="freeze"/>
  </rect>
</svg>
''';

    test('controller initial state', () {
      final controller = AnimatedSvgController();

      expect(controller.isPaused, isFalse);
      expect(controller.playbackRate, 1.0);
      expect(controller.isReversed, isFalse);
      expect(controller.pendingSeek, isNull);
    });

    test('pause and resume', () {
      final controller = AnimatedSvgController();

      controller.pause();
      expect(controller.isPaused, isTrue);

      controller.resume();
      expect(controller.isPaused, isFalse);
    });

    test('togglePlayPause', () {
      final controller = AnimatedSvgController();

      expect(controller.isPaused, isFalse);

      controller.togglePlayPause();
      expect(controller.isPaused, isTrue);

      controller.togglePlayPause();
      expect(controller.isPaused, isFalse);
    });

    test('seek sets pending seek target', () {
      final controller = AnimatedSvgController();

      controller.seek(const Duration(seconds: 1));
      expect(controller.pendingSeek, const Duration(seconds: 1));

      controller.clearPendingSeek();
      expect(controller.pendingSeek, isNull);
    });

    test('setPlaybackRate', () {
      final controller = AnimatedSvgController();

      controller.setPlaybackRate(2.0);
      expect(controller.playbackRate, 2.0);

      controller.setPlaybackRate(0.5);
      expect(controller.playbackRate, 0.5);
    });

    test('setPlaybackRate throws on invalid rate', () {
      final controller = AnimatedSvgController();

      expect(() => controller.setPlaybackRate(0), throwsArgumentError);

      expect(() => controller.setPlaybackRate(-1), throwsArgumentError);
    });

    test('reverse and forward', () {
      final controller = AnimatedSvgController();

      expect(controller.isReversed, isFalse);

      controller.reverse();
      expect(controller.isReversed, isTrue);

      controller.forward();
      expect(controller.isReversed, isFalse);
    });

    test('toggleDirection', () {
      final controller = AnimatedSvgController();

      expect(controller.isReversed, isFalse);

      controller.toggleDirection();
      expect(controller.isReversed, isTrue);

      controller.toggleDirection();
      expect(controller.isReversed, isFalse);
    });

    test('restart', () {
      final controller = AnimatedSvgController();

      controller.pause();
      controller.seek(const Duration(seconds: 2));

      controller.restart();

      expect(controller.isPaused, isFalse);
      expect(controller.pendingSeek, Duration.zero);
    });

    test('controller notifies listeners', () {
      final controller = AnimatedSvgController();
      int notifyCount = 0;

      controller.addListener(() {
        notifyCount++;
      });

      controller.pause();
      expect(notifyCount, 1);

      controller.resume();
      expect(notifyCount, 2);

      controller.seek(const Duration(seconds: 1));
      expect(notifyCount, 3);

      controller.setPlaybackRate(2.0);
      expect(notifyCount, 4);
    });

    testWidgets('controller integrates with AnimatedSvgPicture', (
      tester,
    ) async {
      final controller = AnimatedSvgController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                simpleSvg,
                width: 200,
                height: 200,
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Проверяем начальное состояние
      final pixels1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis1 = VisualTestUtils.analyzeRedPixels(pixels1, 800, 600);
      expect(analysis1.pixelCount, greaterThan(0));

      final centroid1 = analysis1.centroid;

      // Делаем seek через контроллер
      controller.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Проверяем что прямоугольник сдвинулся
      final pixels2 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis2 = VisualTestUtils.analyzeRedPixels(pixels2, 800, 600);

      final centroid2 = analysis2.centroid;

      print('Controller integration test:');
      print('  Centroid before seek: $centroid1');
      print('  Centroid after seek: $centroid2');
      print('  Delta X: ${(centroid2.dx - centroid1.dx).toStringAsFixed(1)}');

      expect(
        centroid2.dx,
        greaterThan(centroid1.dx + 5),
        reason: 'Rectangle should move right after seek',
      );
    });

    testWidgets('controller pause stops animation', (tester) async {
      final controller = AnimatedSvgController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                simpleSvg,
                width: 200,
                height: 200,
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Запускаем анимацию
      await tester.pump(const Duration(milliseconds: 100));

      final pixels1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis1 = VisualTestUtils.analyzeRedPixels(pixels1, 800, 600);
      final centroid1 = analysis1.centroid;

      // Паузим
      controller.pause();
      await tester.pump();

      // Ждём
      await tester.pump(const Duration(milliseconds: 500));

      // Проверяем что не двигается
      final pixels2 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis2 = VisualTestUtils.analyzeRedPixels(pixels2, 800, 600);
      final centroid2 = analysis2.centroid;

      print('Pause test:');
      print('  Centroid before pause wait: $centroid1');
      print('  Centroid after pause wait: $centroid2');

      // Позиция должна остаться примерно той же (допуск ±2 пикселя)
      expect(
        (centroid2.dx - centroid1.dx).abs(),
        lessThan(3),
        reason: 'Rectangle should not move when paused',
      );
    });

    testWidgets('controller playbackRate changes speed', (tester) async {
      final controller = AnimatedSvgController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                simpleSvg,
                width: 200,
                height: 200,
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Устанавливаем быструю скорость
      controller.setPlaybackRate(2.0);
      await tester.pump();

      final pixels1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis1 = VisualTestUtils.analyzeRedPixels(pixels1, 800, 600);
      final centroid1 = analysis1.centroid;

      // Ждём 250ms (но эффективно 500ms из-за 2x скорости)
      await tester.pump(const Duration(milliseconds: 250));

      final pixels2 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis2 = VisualTestUtils.analyzeRedPixels(pixels2, 800, 600);
      final centroid2 = analysis2.centroid;

      print('Playback rate test:');
      print('  Centroid start: $centroid1');
      print('  Centroid after 250ms at 2x: $centroid2');
      print('  Delta X: ${(centroid2.dx - centroid1.dx).toStringAsFixed(1)}');

      // С 2x скоростью должно сдвинуться больше
      expect(
        centroid2.dx,
        greaterThan(centroid1.dx + 5),
        reason: 'Rectangle should move faster with 2x playback rate',
      );
    });

    testWidgets('controller reverse changes playback direction', (
      tester,
    ) async {
      final controller = AnimatedSvgController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                reverseSvg,
                width: 200,
                height: 200,
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final pixels1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis1 = VisualTestUtils.analyzeRedPixels(pixels1, 800, 600);
      final centroidForward = analysis1.centroid;

      controller.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final pixels2 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis2 = VisualTestUtils.analyzeRedPixels(pixels2, 800, 600);
      final centroidReverse = analysis2.centroid;

      expect(
        centroidReverse.dx,
        lessThan(centroidForward.dx - 3),
        reason: 'Rectangle should move left after reverse()',
      );
    });
  });
}
