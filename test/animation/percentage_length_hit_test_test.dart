import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

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
            <use id="use-target" href="#symbol-source" width="50%" height="50%"/>
          </svg>
        ''',
        documentOffset: const Offset(60, 25),
        targetId: 'symbol-child',
        retargetedId: 'use-target',
      );
    });
  });
}
