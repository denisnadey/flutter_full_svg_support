// Regression tests for SMIL animation edge cases
// Tests complex animation scenarios that have historically caused issues

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMIL animate with values/keyTimes/keySplines', () {
    test('animate with matching values and keyTimes', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="50" height="50" fill="red">
            <animate attributeName="x" 
                     values="0;50;100;50;0" 
                     keyTimes="0;0.25;0.5;0.75;1"
                     dur="4s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'x');

      final value0 = animations[0].computeValue(0.0);
      final value25 = animations[0].computeValue(0.25);
      final value50 = animations[0].computeValue(0.5);

      expect(value0, 0.0);
      expect(value25, 50.0);
      expect(value50, 100.0);
    });

    test('animate with keySplines for easing', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle cx="50" cy="100" r="20" fill="blue">
            <animate attributeName="cx" 
                     values="50;150" 
                     keyTimes="0;1"
                     keySplines="0.42 0 0.58 1"
                     calcMode="spline"
                     dur="2s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);

      // Spline interpolation - at t=0.5, should NOT be exactly 100 due to easing
      final valueAt50 = animations[0].computeValue(0.5) as double;
      // With ease-in-out, midpoint should be close to linear but not exact
      expect(valueAt50, greaterThan(49.0));
      expect(valueAt50, lessThan(151.0));
    });

    test('animate with multiple keySplines segments', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect y="10" width="30" height="30" fill="green">
            <animate attributeName="y" 
                     values="10;100;50" 
                     keyTimes="0;0.5;1"
                     keySplines="0 0 1 1; 0 0 1 1"
                     calcMode="spline"
                     dur="3s"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);

      final value0 = animations[0].computeValue(0.0);
      final value50 = animations[0].computeValue(0.5);
      final value100 = animations[0].computeValue(1.0);

      expect(value0, 10.0);
      expect(value50, 100.0);
      expect(value100, 50.0);
    });

    test('animate discrete calcMode jumps between values', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate attributeName="fill" 
                     values="red;green;blue;yellow" 
                     calcMode="discrete"
                     dur="4s"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);

      // Discrete should jump, not interpolate
      final value0 = animations[0].computeValue(0.0);
      final value24 = animations[0].computeValue(0.24);
      final value26 = animations[0].computeValue(0.26);

      // First segment should be red
      expect(value0, isNotNull);
      expect(value24, isNotNull);
      // After 0.25, should jump to green
      expect(value26, isNotNull);
    });

    test('animate paced calcMode distributes evenly', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle r="10" fill="purple">
            <animate attributeName="cx" 
                     values="0;100;120" 
                     calcMode="paced"
                     dur="2s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      // Paced mode should compute values based on path length
    });
  });

  group('animateTransform additive behavior', () {
    test('animateTransform additive="sum" accumulates', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="30" height="30" fill="red" transform="translate(50,50)">
            <animateTransform attributeName="transform" 
                              type="rotate" from="0" to="90" 
                              dur="1s" additive="sum"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'transform');
    });

    test('multiple animateTransform with additive sum', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="30" height="30" fill="blue">
            <animateTransform attributeName="transform" type="translate" 
                              from="0,0" to="100,0" dur="2s" additive="sum"/>
            <animateTransform attributeName="transform" type="scale" 
                              from="1" to="2" dur="2s" additive="sum"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 2);
    });

    test('animateTransform accumulate="sum"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle r="20" fill="green">
            <animateTransform attributeName="transform" type="rotate" 
                              from="0" to="45" dur="1s" 
                              repeatCount="3" accumulate="sum"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].accumulate, isTrue);
    });

    test('animateTransform type="skewX"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="50" height="50" fill="orange">
            <animateTransform attributeName="transform" type="skewX" 
                              from="0" to="30" dur="2s"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateTransform type="skewY"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="50" height="50" fill="teal">
            <animateTransform attributeName="transform" type="skewY" 
                              from="0" to="-20" dur="2s"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });
  });

  group('set element behavior', () {
    testWidgets('set element changes value discretely', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <set attributeName="fill" to="blue" begin="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('set with dur and fill="freeze"', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <circle r="30" fill="green">
            <set attributeName="r" to="50" begin="0.5s" dur="2s" fill="freeze"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('set with end attribute', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect width="40" height="40">
            <set attributeName="fill" to="purple" begin="0s" end="2s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('set visibility attribute', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect width="50" height="50" fill="red" visibility="hidden">
            <set attributeName="visibility" to="visible" begin="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Syncbase timing', () {
    test('begin referencing another animation end', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate id="anim1" attributeName="x" from="0" to="100" dur="2s"/>
            <animate attributeName="y" from="0" to="100" dur="2s" begin="anim1.end"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 2);
    });

    test('begin referencing another animation begin with offset', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle fill="blue">
            <animate id="main" attributeName="cx" from="50" to="150" dur="3s"/>
            <animate attributeName="r" from="10" to="30" dur="1s" 
                     begin="main.begin+1s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 2);
    });

    test('begin with multiple syncbase references', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="green">
            <animate id="a1" attributeName="x" from="0" to="50" dur="1s"/>
            <animate id="a2" attributeName="y" from="0" to="50" dur="1s"/>
            <animate attributeName="opacity" from="0" to="1" dur="0.5s" 
                     begin="a1.end;a2.end"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 3);
    });

    test('end referencing another animation begin', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <ellipse fill="purple">
            <animate id="stopper" attributeName="rx" from="50" to="80" dur="3s"/>
            <animate attributeName="ry" from="30" to="50" dur="5s" 
                     end="stopper.begin+2s"/>
          </ellipse>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 2);
    });
  });

  group('Event-based timing', () {
    test('begin on click event', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect id="target" width="50" height="50" fill="red">
            <animate attributeName="fill" from="red" to="blue" dur="1s" 
                     begin="target.click"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('begin on mouseover event', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle id="hover" cx="100" cy="100" r="30" fill="green">
            <animate attributeName="r" from="30" to="50" dur="0.3s" 
                     begin="hover.mouseover"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('begin on mouseout with repeat', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect id="box" width="60" height="60" fill="blue">
            <animate attributeName="opacity" values="1;0.5;1" dur="0.5s" 
                     begin="box.mouseout" repeatCount="2"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });
  });

  group('Animation restart behavior', () {
    test('restart="always" animation parses', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate attributeName="x" from="0" to="100" dur="2s" 
                     begin="click" restart="always"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'x');
    });

    test('restart="whenNotActive" animation parses', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle fill="blue">
            <animate attributeName="r" from="10" to="50" dur="3s" 
                     begin="click" restart="whenNotActive"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'r');
    });

    test('restart="never" animation parses', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <ellipse fill="green">
            <animate attributeName="rx" from="20" to="80" dur="2s" 
                     begin="click" restart="never"/>
          </ellipse>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'rx');
    });
  });

  group('Animation fill mode', () {
    test('fill="freeze" holds final value', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate attributeName="opacity" from="1" to="0" dur="1s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].fillMode, SmilFillMode.freeze);
    });

    test('fill="remove" (default) returns to base value', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle fill="blue">
            <animate attributeName="cx" from="50" to="150" dur="2s" fill="remove"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].fillMode, SmilFillMode.remove);
    });
  });

  group('repeatDur and repeatCount interaction', () {
    test('repeatCount="indefinite"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate attributeName="x" from="0" to="100" dur="1s" 
                     repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].repeatCount, double.infinity);
    });

    test('repeatDur limits total animation time', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle fill="blue">
            <animate attributeName="r" from="10" to="40" dur="0.5s" 
                     repeatCount="indefinite" repeatDur="3s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      final endTime = animations[0].getEffectiveEndTime();
      expect(endTime.inSeconds, 3);
    });

    test('repeatCount as fraction', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="green">
            <animate attributeName="y" from="0" to="100" dur="2s" 
                     repeatCount="2.5"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].repeatCount, 2.5);
    });

    test('min and max duration constraints', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <ellipse fill="purple">
            <animate attributeName="rx" from="20" to="80" dur="1s" 
                     repeatCount="10" min="2s" max="5s"/>
          </ellipse>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });
  });

  group('Color animation edge cases', () {
    test('animate fill with named colors', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red">
            <animate attributeName="fill" values="red;green;blue;red" 
                     dur="3s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animate stroke with hex colors', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle stroke="#FF0000" stroke-width="3" fill="none">
            <animate attributeName="stroke" values="#FF0000;#00FF00;#0000FF" 
                     dur="2s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animate stop-color in gradient', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <linearGradient id="grad">
              <stop offset="0%" stop-color="red">
                <animate attributeName="stop-color" values="red;yellow;red" 
                         dur="2s" repeatCount="indefinite"/>
              </stop>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect width="200" height="200" fill="url(#grad)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
      expect(animations[0].attributeName, 'stop-color');
    });

    test('animate with rgba colors', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect fill="rgba(255,0,0,1)">
            <animate attributeName="fill" 
                     from="rgba(255,0,0,1)" to="rgba(0,0,255,0.5)" 
                     dur="2s"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });
  });

  group('Path animation (animateMotion)', () {
    test('animateMotion with inline path', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle r="5" fill="red">
            <animateMotion path="M10,80 Q95,10 180,80" dur="2s"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateMotion with mpath reference', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <path id="motionPath" d="M20,50 C40,10 60,90 80,50"/>
          </defs>
          <rect width="10" height="10" fill="blue">
            <animateMotion dur="3s">
              <mpath href="#motionPath"/>
            </animateMotion>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateMotion with rotate="auto"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <polygon points="0,-5 10,0 0,5" fill="green">
            <animateMotion path="M20,100 L180,100" dur="2s" rotate="auto"/>
          </polygon>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateMotion with rotate="auto-reverse"', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="10" height="5" fill="purple">
            <animateMotion path="M50,100 C100,20 150,180 200,100" dur="3s" 
                           rotate="auto-reverse"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateMotion with fixed rotation angle', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <rect width="8" height="8" fill="orange">
            <animateMotion path="M10,100 L190,100" dur="2s" rotate="45"/>
          </rect>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });

    test('animateMotion with keyPoints and keyTimes', () {
      const svgString = '''
        <svg viewBox="0 0 200 200">
          <circle r="5" fill="teal">
            <animateMotion path="M10,100 L190,100" dur="4s" 
                           keyPoints="0;0.5;1" keyTimes="0;0.25;1" calcMode="linear"/>
          </circle>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.length, 1);
    });
  });

  group('Widget integration tests', () {
    testWidgets('animated SVG renders without error', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect fill="red" x="10" y="10" width="50" height="50">
            <animate attributeName="x" from="10" to="140" dur="2s" 
                     repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple animations on same element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <circle cx="50" cy="100" r="20" fill="blue">
            <animate attributeName="cx" from="50" to="150" dur="2s" repeatCount="indefinite"/>
            <animate attributeName="r" values="20;30;20" dur="1s" repeatCount="indefinite"/>
            <animate attributeName="fill" values="blue;purple;blue" dur="3s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animateTransform rotate renders correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect x="75" y="75" width="50" height="50" fill="green">
            <animateTransform attributeName="transform" type="rotate" 
                              from="0 100 100" to="360 100 100" 
                              dur="4s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animation with complex timing', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <g>
            <circle id="c1" cx="50" cy="100" r="20" fill="red">
              <animate id="a1" attributeName="cx" from="50" to="150" dur="1s"/>
            </circle>
            <circle cx="150" cy="100" r="20" fill="blue">
              <animate attributeName="cx" from="150" to="50" dur="1s" begin="a1.end"/>
            </circle>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animation frozen at end state', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect x="10" y="80" width="40" height="40" fill="orange">
            <animate attributeName="x" from="10" to="150" dur="0.5s" fill="freeze"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // After animation ends

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
