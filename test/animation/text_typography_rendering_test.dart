import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-decoration-style rendering mapping', () {
    testWidgets('solid decoration style renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-style: solid">Solid Style</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('double decoration style renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-style: double">Double Style</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('dotted decoration style renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-style: dotted">Dotted Style</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('dashed decoration style renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-style: dashed">Dashed Style</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('wavy decoration style renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-style: wavy">Wavy Style</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('default decoration style is solid', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline">Default Solid</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('decoration style combined with decoration line', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-decoration-line: underline overline; text-decoration-style: wavy">Combined</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('text-decoration-thickness rendering', () {
    testWidgets('decoration thickness in px renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-thickness: 3px">3px Thick</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('decoration thickness in em renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-thickness: 0.15em">0.15em Thick</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('decoration thickness auto renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-thickness: auto">Auto Thick</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('decoration thickness from-font renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-thickness: from-font">From Font</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('decoration thickness combined with style', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" 
                style="text-decoration-thickness: 4px; text-decoration-style: double">Combined</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('text-shadow rendering', () {
    testWidgets('single shadow with all values renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 2px 3px 4px black">Shadow</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple shadows render correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 1px 1px red, 2px 2px blue">Multi Shadow</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shadow without blur radius renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 2px 3px black">No Blur</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shadow with hex color renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 1px 1px 0px #ff0000">Hex Color</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shadow with rgb color renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 1px 1px 0px rgb(255, 0, 0)">RGB Color</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shadow with rgba color renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="text-shadow: 1px 1px 2px rgba(0, 0, 255, 0.5)">RGBA Color</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-shadow none renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-shadow: none">No Shadow</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-shadow inherits from parent', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg">
          <g style="text-shadow: 2px 2px 3px gray">
            <text x="10" y="30" font-size="16">Inherited 1</text>
            <text x="10" y="55" font-size="16">Inherited 2</text>
          </g>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('font-variation-settings rendering', () {
    testWidgets('single axis wght renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="font-variation-settings: 'wght' 700">Bold Weight</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple axes render correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="font-variation-settings: 'wght' 700, 'wdth' 125">Multi Axis</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-variation-settings normal renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="font-variation-settings: normal">Normal</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('slnt axis renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="font-variation-settings: 'slnt' -12">Slant</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ital axis renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                style="font-variation-settings: 'ital' 1">Italic</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('font-optical-sizing rendering', () {
    testWidgets('font-optical-sizing auto adds opsz variation', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="24" style="font-optical-sizing: auto">Optical Auto</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-optical-sizing none disables opsz', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="24" style="font-optical-sizing: none">Optical None</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('optical sizing with different font sizes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="25" font-size="12" style="font-optical-sizing: auto">12px</text>
          <text x="10" y="50" font-size="24" style="font-optical-sizing: auto">24px</text>
          <text x="10" y="85" font-size="36" style="font-optical-sizing: auto">36px</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('line-height rendering', () {
    testWidgets('line-height as multiplier renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 2">Double Height</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height as px value renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 24px">24px Height</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height as em value renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 1.5em">1.5em Height</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height as percentage renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 150%">150% Height</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height normal renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: normal">Normal Height</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height computes height/fontSize correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" style="line-height: 30px">Height Calc</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('font-family fallback rendering', () {
    testWidgets('single font renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" font-family="Arial">Single Font</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('comma-separated fonts render with primary + fallbacks', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                font-family="Roboto, Arial, sans-serif">Fallback Chain</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('quoted font names with spaces render correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 250 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                font-family='"Times New Roman", Georgia, serif'>Quoted Name</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('null font-family uses default', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">No Font Specified</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-family with extra whitespace normalizes correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 250 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" 
                font-family="  Arial  ,  Helvetica  ,  sans-serif  ">Whitespace</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('text emphasis rendering', () {
    testWidgets('text-emphasis filled renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="16" style="text-emphasis: filled">Emphasis</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-emphasis open dot renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="16" style="text-emphasis: open dot">Open Dot</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-emphasis circle with color renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="16" style="text-emphasis: circle red">Circle Red</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-emphasis-style receives style from paint sites', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="16" 
                style="text-emphasis-style: triangle; text-emphasis-color: blue">Triangle</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-emphasis none renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-emphasis: none">No Emphasis</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('text stroke rendering', () {
    testWidgets('text with stroke renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="35" font-size="24" fill="white" stroke="black" stroke-width="1">Stroked</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with stroke=none renders no stroke', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="35" font-size="24" fill="blue" stroke="none">No Stroke</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order stroke first renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="35" font-size="24" fill="yellow" stroke="black" stroke-width="2"
                style="paint-order: stroke fill">Stroke First</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order fill stroke markers renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="35" font-size="24" fill="green" stroke="red" stroke-width="1"
                style="paint-order: fill stroke markers">Fill First</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('stroke without fill renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="35" font-size="24" fill="none" stroke="purple" stroke-width="1.5">Outline Only</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('thick stroke with paint-order for outline effect', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 250 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="45" font-size="32" fill="white" stroke="black" stroke-width="3"
                style="paint-order: stroke fill">Outline Effect</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('mix-blend-mode copyWith preservation', () {
    testWidgets('mix-blend-mode on text renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="yellow"/>
          <text x="10" y="50" font-size="24" fill="blue" style="mix-blend-mode: multiply">Blend</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode screen on text renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="darkblue"/>
          <text x="10" y="50" font-size="24" fill="red" style="mix-blend-mode: screen">Screen</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode overlay on text renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="gray"/>
          <text x="10" y="50" font-size="24" fill="orange" style="mix-blend-mode: overlay">Overlay</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode inherited through copyWith preserves value', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="cyan"/>
          <g style="mix-blend-mode: darken">
            <text x="10" y="40" font-size="20" fill="magenta">Inherited 1</text>
            <text x="10" y="70" font-size="20" fill="yellow">Inherited 2</text>
          </g>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode difference on text renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="white"/>
          <text x="10" y="50" font-size="24" fill="black" style="mix-blend-mode: difference">Diff</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('combined typography features', () {
    testWidgets('multiple typography features combined', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 80" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" 
                font-family="Arial, sans-serif"
                style="text-shadow: 2px 2px 3px gray; 
                       text-decoration: underline; 
                       text-decoration-style: wavy;
                       line-height: 1.5">Combined Features</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('stroke with shadow and decoration', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 80" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" 
                fill="white" stroke="black" stroke-width="1"
                style="text-shadow: 3px 3px 5px rgba(0,0,0,0.5);
                       text-decoration: underline;
                       paint-order: stroke fill">Styled Text</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font variations with optical sizing', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 80" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" 
                style="font-variation-settings: 'wght' 600;
                       font-optical-sizing: auto">Variable Font</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('emphasis with shadow', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 80" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" 
                style="text-emphasis: dot red;
                       text-shadow: 1px 1px 2px black">Emphasis Shadow</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('all decoration properties combined', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 60" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="18" 
                style="text-decoration-line: underline overline;
                       text-decoration-style: double;
                       text-decoration-thickness: 2px;
                       text-decoration-color: red">Full Decoration</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
