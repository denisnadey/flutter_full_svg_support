import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rotation Golden Tests', () {
    testWidgets('rotation at t=0 (0 degrees)', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff0000">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  autoPlay: false, // Не запускаем автоматически
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Golden test для t=0
      await expectLater(
        find.byType(AnimatedSvgPicture),
        matchesGoldenFile('goldens/rotation_0deg.png'),
      );
    });

    testWidgets('rotation at t=0.25 (90 degrees)', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff0000">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Перемотать на 0.5 секунды (25% от 2s = 90 градусов)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Golden test для t=0.25 (90°)
      await expectLater(
        find.byType(AnimatedSvgPicture),
        matchesGoldenFile('goldens/rotation_90deg.png'),
      );
    });

    testWidgets('rotation at t=0.5 (180 degrees)', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff0000">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Перемотать на 1.0 секунду (50% от 2s = 180 градусов)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      // Golden test для t=0.5 (180°)
      await expectLater(
        find.byType(AnimatedSvgPicture),
        matchesGoldenFile('goldens/rotation_180deg.png'),
      );
    });

    testWidgets('rotation at t=0.75 (270 degrees)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff0000">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Перемотать на 1.5 секунды (75% от 2s = 270 градусов)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      // Golden test для t=0.75 (270°)
      await expectLater(
        find.byType(AnimatedSvgPicture),
        matchesGoldenFile('goldens/rotation_270deg.png'),
      );
    });

    testWidgets('verify pixels actually change during rotation', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff0000">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Начальный кадр (0°)
      await tester.pump();

      // Сделаем скриншоты на разных углах для визуальной проверки
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rotation_sequence_0deg.png'),
      );

      // Переместить на 90 градусов
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rotation_sequence_90deg.png'),
      );

      // Переместить на 180 градусов
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rotation_sequence_180deg.png'),
      );

      // Переместить на 270 градусов
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/rotation_sequence_270deg.png'),
      );
    });
  });
}
