import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedSvgPicture', () {
    testWidgets('renders static rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="20" width="30" height="40" fill="#ff0000"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders animated rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="blue">
            <animate attributeName="x" from="0" to="80" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: false, // Не автостарт для тестирования
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates x attribute over time', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="red">
            <animate attributeName="x" from="0" to="80" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      // Начальное состояние
      await tester.pump();

      // Анимация должна запуститься
      // Проверяем что CustomPaint существует
      expect(find.byType(CustomPaint), findsWidgets);

      // Продвигаем время на половину анимации (500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Виджет должен перерисоваться
      expect(find.byType(CustomPaint), findsWidgets);

      // Завершаем анимацию (ещё 500ms)
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders circle', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="25" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders ellipse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <ellipse cx="50" cy="50" rx="40" ry="20" fill="yellow"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animates opacity', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="blue">
            <animate attributeName="opacity" from="1" to="0" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('handles repeatCount indefinite', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="red">
            <animate attributeName="x" from="0" to="80" dur="1s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      // Несколько циклов анимации
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('applies backgroundColor', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles viewBox scaling', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 50 50">
          <rect x="5" y="5" width="40" height="40" fill="purple"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders stroke', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" 
                fill="none" stroke="black" stroke-width="2"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders line', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <line x1="10" y1="10" x2="90" y2="90" stroke="red" stroke-width="3"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders rounded rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" rx="10" ry="10" fill="orange"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animates fill color', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="red">
            <animate attributeName="fill" from="red" to="blue" dur="1s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates stroke color', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="30" fill="none" stroke="green" stroke-width="3">
            <animate attributeName="stroke" from="#00ff00" to="#ff0000" dur="2s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates transform rotate', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="red">
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
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates transform translate', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="20" cy="50" r="10" fill="blue">
            <animateTransform
              attributeName="transform"
              type="translate"
              from="0 0"
              to="60 0"
              dur="1s"
              repeatCount="indefinite"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
