import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('xml:space attribute', () {
    testWidgets('xml:space: default (collapse whitespace)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">Multiple   spaces   collapsed</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space="preserve" keeps multiple spaces', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" xml:space="preserve">Multiple   spaces   preserved</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space="preserve" keeps leading/trailing spaces', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" xml:space="preserve">  Padded Text  </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space="default" trims whitespace', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" xml:space="default">  Trimmed Text  </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <g xml:space="preserve">
            <text x="10" y="30" font-size="16">  Inherited   preserve  </text>
            <text x="10" y="60" font-size="16">  Also   preserved  </text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space with tspan', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" xml:space="preserve">
            <tspan>Multiple   spaces</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('direction attribute (RTL/LTR)', () {
    testWidgets('direction: ltr (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" direction="ltr">Left to Right</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('direction: rtl', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="190" y="30" font-size="20" direction="rtl">مرحبا</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('direction: rtl with numbers', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="190" y="30" font-size="20" direction="rtl">123 عربي</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('direction via style attribute', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="190" y="30" font-size="20" style="direction: rtl">RTL Text</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('direction inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g direction="rtl">
            <text x="190" y="30" font-size="16">First RTL</text>
            <text x="190" y="60" font-size="16">Second RTL</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('direction with text-anchor: end', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="190" y="30" font-size="20" direction="rtl" text-anchor="end">
            שלום
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mixed direction content', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" direction="ltr">English LTR</text>
          <text x="290" y="60" font-size="16" direction="rtl">עברית RTL</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
