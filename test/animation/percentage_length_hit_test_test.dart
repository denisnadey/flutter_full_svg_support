import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import 'visual_test_utils.dart';

void main() {
  Future<void> expectTapTarget(
    WidgetTester tester, {
    required String svg,
    required Offset documentOffset,
    required String targetId,
    String? retargetedId,
  }) async {
    final traceEvents = <SvgTraceEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedSvgPicture.string(
              svg,
              width: 200,
              height: 100,
              autoPlay: false,
              onTrace: traceEvents.add,
              onLinkTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pictureTopLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
    traceEvents.clear();
    await tester.tapAt(pictureTopLeft + documentOffset);
    await tester.pump();

    final tapTrace = traceEvents.lastWhere(
      (event) => event.category == 'event' && event.message == 'Tap detected',
    );
    expect(tapTrace.data['targetId'], targetId);
    expect(tapTrace.data['retargetedId'], retargetedId ?? targetId);
  }

  Future<void> expectForeignObjectClickStartsAnimation(
    WidgetTester tester, {
    required String svg,
    required Offset documentOffset,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedSvgPicture.string(
              svg,
              width: 200,
              height: 100,
              autoPlay: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
    final before = VisualTestUtils.analyzeRedPixels(beforePixels, 800, 600);
    final pictureTopLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));

    await tester.tapAt(pictureTopLeft + documentOffset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
    final after = VisualTestUtils.analyzeRedPixels(afterPixels, 800, 600);
    expect(after.centroid.dx, greaterThan(before.centroid.dx + 10));
  }

  group('percentage SVG lengths in hit testing', () {
    testWidgets('resolves rect horizontal and vertical percentages', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <rect id="rect-target" x="50%" y="20%" width="25%" height="20%" fill="black"/>
          </svg>
        ''',
        documentOffset: const Offset(125, 30),
        targetId: 'rect-target',
      );
    });

    testWidgets('matches percentage rect corner radii during hit testing', (
      tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="rounded-target" x="25%" width="50%" height="100%"
                rx="25%" ry="25%" fill="red"/>
          </svg>
        ''',
        // This point is inside a raw 25x25 corner radius, but outside the
        // correctly resolved 50x25 corner radius.
        documentOffset: const Offset(58, 10),
        targetId: 'background',
      );
    });

    testWidgets('resolves circle center and radius percentages', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <circle id="circle-target" cx="75%" cy="50%" r="10%" fill="black"/>
          </svg>
        ''',
        documentOffset: const Offset(160, 50),
        targetId: 'circle-target',
      );
    });

    testWidgets('resolves ellipse center and radius percentages', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <ellipse id="ellipse-target" cx="75%" cy="50%" rx="10%" ry="20%" fill="black"/>
          </svg>
        ''',
        documentOffset: const Offset(150, 50),
        targetId: 'ellipse-target',
      );
    });

    testWidgets('resolves line endpoint percentages', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <line id="line-target" x1="60%" y1="20%" x2="80%" y2="80%" stroke="black" stroke-width="4"/>
          </svg>
        ''',
        documentOffset: const Offset(140, 50),
        targetId: 'line-target',
      );
    });

    testWidgets('resolves image viewport percentages', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <image id="image-target" x="50%" y="20%" width="25%" height="20%"
                href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLwzAAAAABJRU5ErkJggg=="/>
          </svg>
        ''',
        documentOffset: const Offset(125, 30),
        targetId: 'image-target',
      );
    });

    testWidgets('resolves percentage rect geometry in clip-path hit testing', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <clipPath id="clip">
                <rect x="25%" width="50%" height="100%"/>
              </clipPath>
            </defs>
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="target" width="200" height="100" fill="red"
                  clip-path="url(#clip)"/>
          </svg>
        ''',
        // Correct clip range is x=50..150; raw values would reject x=120.
        documentOffset: const Offset(120, 50),
        targetId: 'target',
      );
    });

    testWidgets('resolves percentage rect geometry in mask hit testing', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <mask id="mask" type="luminance"
                    maskUnits="userSpaceOnUse"
                    maskContentUnits="userSpaceOnUse"
                    x="0" y="0" width="200" height="100">
                <rect x="25%" width="50%" height="100%" fill="white"/>
              </mask>
            </defs>
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="target" width="200" height="100" fill="red"
                  mask="url(#mask)"/>
          </svg>
        ''',
        // Correct mask range is x=50..150; raw values would reject x=120.
        documentOffset: const Offset(120, 50),
        targetId: 'target',
      );
    });

    testWidgets(
      'resolves percentage circle geometry in clip-path hit testing',
      (WidgetTester tester) async {
        await expectTapTarget(
          tester,
          svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <clipPath id="clip">
                <circle cx="75%" cy="50%" r="10%"/>
              </clipPath>
            </defs>
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="target" width="200" height="100" fill="red"
                  clip-path="url(#clip)"/>
          </svg>
        ''',
          // Correct circle is centered at x=150 with a normalized-diagonal
          // radius; raw values would reject this point.
          documentOffset: const Offset(160, 50),
          targetId: 'target',
        );
      },
    );

    testWidgets('resolves percentage use geometry in clip-path hit testing', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <rect id="source" width="30" height="30"/>
              <clipPath id="clip">
                <use href="#source" x="25%" y="25%"/>
              </clipPath>
            </defs>
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="target" width="200" height="100" fill="red"
                  clip-path="url(#clip)"/>
          </svg>
        ''',
        // Correct clip position is x=50..80; raw x=25 would miss x=70.
        documentOffset: const Offset(70, 40),
        targetId: 'target',
      );
    });

    testWidgets('resolves percentage use geometry in mask hit testing', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <rect id="source" width="40" height="20" fill="white"/>
              <mask id="mask" type="luminance"
                    maskUnits="userSpaceOnUse"
                    maskContentUnits="userSpaceOnUse"
                    x="0" y="0" width="200" height="100">
                <use href="#source" x="25%" y="25%"/>
              </mask>
            </defs>
            <rect id="background" width="200" height="100" fill="black"/>
            <rect id="target" width="200" height="100" fill="red"
                  mask="url(#mask)"/>
          </svg>
        ''',
        // Correct mask position is x=50..90; raw x=25 would miss x=70.
        documentOffset: const Offset(70, 40),
        targetId: 'target',
      );
    });
    testWidgets(
      'resolves percentage foreignObject coordinates in hit testing',
      (WidgetTester tester) async {
        await expectForeignObjectClickStartsAnimation(
          tester,
          svg: '''
          <svg viewBox="0 0 200 100">
            <foreignObject x="25%" y="10%" width="50%" height="50%">
              <rect id="target" width="100" height="50" fill="blue"/>
            </foreignObject>
            <rect x="10" y="80" width="20" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s"
                       begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''',
          // Actual foreignObject viewport is x=50..150 and y=10..60.
          documentOffset: const Offset(100, 35),
        );
      },
    );

    testWidgets(
      'resolves percentage nested SVG viewport in foreignObject hit testing',
      (WidgetTester tester) async {
        await expectForeignObjectClickStartsAnimation(
          tester,
          svg: '''
            <svg viewBox="0 0 200 100">
              <foreignObject x="25%" y="10%" width="25%" height="50%">
                <svg x="50%" y="50%" width="50%" height="50%"
                     viewBox="0 0 25 25" preserveAspectRatio="none">
                  <rect id="target" width="25" height="25" fill="blue"/>
                </svg>
              </foreignObject>
              <rect x="10" y="80" width="20" height="10" fill="red">
                <animate attributeName="x" from="10" to="150" dur="1s"
                         begin="target.click" fill="freeze"/>
              </rect>
            </svg>
          ''',
          // The nested SVG is x=75..100 and y=35..60 in document space.
          documentOffset: const Offset(85, 45),
        );
      },
    );

    testWidgets('resolves use viewport percentages before hit testing', (
      WidgetTester tester,
    ) async {
      await expectTapTarget(
        tester,
        svg: '''
          <svg viewBox="0 0 200 100">
            <defs>
              <symbol id="symbol-source" viewBox="0 0 100 100">
                <rect id="symbol-child" width="100" height="100" fill="black"/>
              </symbol>
            </defs>
            <use id="use-target" href="#symbol-source" x="25%"
                 width="50%" height="50%"/>
          </svg>
        ''',
        // Correct symbol content is x=75..125; raw x=25 would miss x=120.
        documentOffset: const Offset(120, 25),
        targetId: 'symbol-child',
        retargetedId: 'use-target',
      );
    });
  });
}
