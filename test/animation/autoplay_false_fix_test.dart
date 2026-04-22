import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('autoPlay: false bug fix', () {
    const simpleSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="30" height="30" fill="red">
    <animate attributeName="x" from="10" to="60" dur="2s" repeatCount="indefinite"/>
  </rect>
</svg>
''';

    testWidgets('autoPlay: false renders initial frame (t=0)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                simpleSvg,
                width: 200,
                height: 200,
                autoPlay:
                    false, // ❌ Баг: должно рендерить t=0, но рендерит 0 пикселей
              ),
            ),
          ),
        ),
      );

      // Даём виджету время на инициализацию
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Захватываем пиксели
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);

      // Проверяем что есть пиксели (красный прямоугольник)
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      print('autoPlay: false test:');
      print('  Red pixels found: ${analysis.pixelCount}');
      print(
        '  Coverage: ${(analysis.pixelCount / (800 * 600) * 100).toStringAsFixed(2)}%',
      );

      // ДОЛЖНО пройти после фикса
      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'autoPlay: false should render initial frame at t=0',
      );

      // Дополнительная проверка: должно быть достаточно пикселей для прямоугольника 30x30
      expect(
        analysis.pixelCount,
        greaterThan(50),
        reason: 'Should have enough pixels for a 30x30 rectangle',
      );
    });

    testWidgets('autoPlay: false with initialTime renders correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                simpleSvg,
                width: 200,
                height: 200,
                autoPlay: false,
                initialTime: const Duration(
                  seconds: 1,
                ), // t=1s (середина анимации)
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);

      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      print('autoPlay: false with initialTime test:');
      print('  Red pixels found: ${analysis.pixelCount}');

      expect(
        analysis.pixelCount,
        greaterThan(0),
        reason: 'autoPlay: false with initialTime should render frame at t=1s',
      );

      // При t=1s прямоугольник должен быть посередине пути (x ~35)
      // Проверяем что центроид сместился вправо от начальной позиции
      if (analysis.pixelCount > 0) {
        print('  Centroid: ${analysis.centroid}');
        expect(
          analysis.centroid.dx,
          greaterThan(50), // Должен быть правее начальной позиции
          reason: 'Rectangle should be moved to the right at t=1s',
        );
      }
    });

    testWidgets('switching from autoPlay: false to true starts animation', (
      tester,
    ) async {
      // Создаём StatefulWidget для переключения autoPlay
      bool autoPlayEnabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    AnimatedSvgPicture.string(
                      simpleSvg,
                      width: 200,
                      height: 200,
                      autoPlay: autoPlayEnabled,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          autoPlayEnabled = true;
                        });
                      },
                      child: const Text('Start'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();

      // Проверяем начальное состояние (autoPlay: false)
      final pixelsBefore = await VisualTestUtils.captureWidgetPixels(tester);
      final analysisBefore = VisualTestUtils.analyzeRedPixels(
        pixelsBefore,
        800,
        600,
      );

      expect(
        analysisBefore.pixelCount,
        greaterThan(0),
        reason: 'Should render initial frame',
      );

      final centroidBefore = analysisBefore.centroid;

      // Включаем autoPlay
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Ждём немного времени для анимации
      await tester.pump(const Duration(milliseconds: 500));

      // Проверяем что анимация запустилась (прямоугольник сдвинулся)
      final pixelsAfter = await VisualTestUtils.captureWidgetPixels(tester);
      final analysisAfter = VisualTestUtils.analyzeRedPixels(
        pixelsAfter,
        800,
        600,
      );

      final centroidAfter = analysisAfter.centroid;

      print('Switching autoPlay test:');
      print('  Centroid before: $centroidBefore');
      print('  Centroid after: $centroidAfter');
      print(
        '  Delta X: ${(centroidAfter.dx - centroidBefore.dx).toStringAsFixed(1)}',
      );

      // Прямоугольник должен сдвинуться вправо
      expect(
        centroidAfter.dx,
        greaterThan(centroidBefore.dx + 5), // Минимум 5 пикселей вправо
        reason: 'Rectangle should move right when animation starts',
      );
    });
  });
}
