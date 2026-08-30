import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

/// Paint/hit parity regressions for `<tref>` text (issue #47).
///
/// `<tref>` children of `<text>` are painted with their own x/y/dx/dy/rotate
/// lists, so both hit-testing paths must build runs for them with the same
/// list resolution as `tspan`. These tests pin the glyph-precision path (the
/// primary path in `_nodeContainsPoint`); the text-runs fallback builder
/// received the identical treatment.
void main() {
  Future<String?> tapTargetAt(
    WidgetTester tester, {
    required String svg,
    required Offset documentOffset,
    bool autoPlay = true,
    Duration? initialTime,
  }) async {
    final traceEvents = <SvgTraceEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AnimatedSvgPicture.string(
              svg,
              width: 300,
              height: 100,
              autoPlay: autoPlay,
              initialTime: initialTime,
              onTrace: traceEvents.add,
              // Providing a link callback forces the gesture layer to be
              // installed even though these fixtures have no animations.
              onLinkTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pictureTopLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
    await tester.tapAt(pictureTopLeft + documentOffset);
    await tester.pump();

    final tapTrace = traceEvents.lastWhere(
      (event) => event.category == 'event' && event.message == 'Tap detected',
    );
    return tapTrace.data['targetId'] as String?;
  }

  group('tref hit testing', () {
    testWidgets(
      'tap on painted tref glyphs registers a hit on the text element',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="src">Hello</text>
        </defs>
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          <tref href="#src"/>
        </text>
      </svg>''';

        // "Hello" is painted from x=10 with a 20px font, so the glyph area
        // spans roughly x=10..65 around baseline y=60.
        expect(
          await tapTargetAt(
            tester,
            svg: svg,
            documentOffset: const Offset(30, 55),
          ),
          'text-target',
        );
        expect(
          await tapTargetAt(
            tester,
            svg: svg,
            documentOffset: const Offset(280, 90),
          ),
          isNull,
        );
      },
    );

    testWidgets(
      'tap on tref glyphs targets the tref element when it has an id',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="src">Hello</text>
        </defs>
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          <tref id="tref-target" href="#src"/>
        </text>
      </svg>''';

        expect(
          await tapTargetAt(
            tester,
            svg: svg,
            documentOffset: const Offset(30, 55),
          ),
          'tref-target',
        );
      },
    );

    testWidgets('tref own x/y positioning is honored during hit testing', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="posRef">Positioned</text>
        </defs>
        <text id="text-target" x="10" y="70" font-size="20" fill="black">
          Start <tref href="#posRef" x="140" y="30"/>
        </text>
      </svg>''';

      // The tref run is repositioned to x=140 / baseline y=30, so taps near
      // that location hit the owning text element.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(170, 25),
        ),
        'text-target',
      );
      // The parent text's own "Start" run stays at x=10 / baseline y=70.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(25, 65),
        ),
        'text-target',
      );
      // Below the repositioned tref run nothing is painted.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(170, 65),
        ),
        isNull,
      );
    });

    testWidgets('tref dx shifts hit targets with the painted glyphs', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="src">Hello</text>
        </defs>
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          <tref href="#src" dx="50"/>
        </text>
      </svg>''';

      // dx shifts the painted run to start at x=60, so the hit area moves
      // with it and the pre-shift position becomes empty.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(80, 55),
        ),
        'text-target',
      );
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(25, 55),
        ),
        isNull,
      );
    });

    testWidgets('tref referencing nested text content is hittable', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="nested">Hello <tspan>World</tspan></text>
        </defs>
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          <tref href="#nested"/>
        </text>
      </svg>''';

      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(30, 55),
        ),
        'text-target',
      );
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(100, 55),
        ),
        'text-target',
      );
    });

    testWidgets('tref with missing reference contributes no hit runs', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          Fallback <tref href="#nonExistent"/>
        </text>
      </svg>''';

      // The direct text still hits.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(25, 55),
        ),
        'text-target',
      );
      // Where the referenced glyphs would have been, nothing is hit.
      expect(
        await tapTargetAt(
          tester,
          svg: svg,
          documentOffset: const Offset(200, 55),
        ),
        isNull,
      );
    });

    testWidgets(
      'animated percentage tref dx shifts hit targets with the paint path',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="src">Hello</text>
        </defs>
        <text id="text-target" x="10" y="60" font-size="20" fill="black">
          <tref href="#src">
            <animate attributeName="dx" from="0%" to="100%" dur="2s"/>
          </tref>
        </text>
      </svg>''';

        // At t=1s the dx percentage resolves to 50% of the 300-wide viewport,
        // shifting the painted run to start near x=160. The hit path must use
        // the same deferred resolution as the paint path (via #43's resolver).
        expect(
          await tapTargetAt(
            tester,
            svg: svg,
            documentOffset: const Offset(180, 55),
            autoPlay: false,
            initialTime: const Duration(seconds: 1),
          ),
          'text-target',
        );
        // The pre-animation position near x=10 is no longer occupied.
        expect(
          await tapTargetAt(
            tester,
            svg: svg,
            documentOffset: const Offset(25, 55),
            autoPlay: false,
            initialTime: const Duration(seconds: 1),
          ),
          isNull,
        );
      },
    );
  });
}
