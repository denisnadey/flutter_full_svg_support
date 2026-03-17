import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SVG Anchor Element (<a>)', () {
    group('basic rendering', () {
      testWidgets('renders children of <a> element like <g>', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com">
              <rect id="link-rect" x="10" y="10" width="80" height="80" fill="blue"/>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders nested elements inside <a>', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com">
              <g transform="translate(10, 10)">
                <rect x="0" y="0" width="80" height="80" fill="red"/>
                <circle cx="40" cy="40" r="30" fill="white"/>
              </g>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders <a> with transform attribute', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com" transform="translate(20, 20)">
              <rect x="0" y="0" width="40" height="40" fill="green"/>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedSvgPicture.string(svg, width: 100, height: 100),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('onLinkTap callback', () {
      testWidgets('triggers onLinkTap when child element is clicked',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com/page1">
              <rect id="clickable" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap inside the rect (center of widget)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://example.com/page1');
      });

      testWidgets('passes target attribute to onLinkTap callback',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com" target="_blank">
              <rect id="clickable" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://example.com');
        expect(tappedLink!.target, '_blank');
      });

      testWidgets('supports xlink:href attribute', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" 
               xmlns:xlink="http://www.w3.org/1999/xlink">
            <a xlink:href="https://xlink-example.com">
              <rect id="clickable" x="10" y="10" width="80" height="80" fill="red">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://xlink-example.com');
      });

      testWidgets('does not trigger when clicking outside anchor children',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <rect id="outside" x="0" y="0" width="100" height="100" fill="gray">
              <animate attributeName="opacity" from="1" to="1" dur="1s"/>
            </rect>
            <a href="https://example.com">
              <rect id="inside" x="60" y="60" width="30" height="30" fill="blue"/>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap outside the anchor rect (top-left area)
        await tester.tapAt(topLeft + const Offset(20, 20));
        await tester.pump();

        expect(tappedLink, isNull);
      });
    });

    group('nested anchors', () {
      testWidgets('inner anchor takes precedence over outer anchor',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://outer.com">
              <rect x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
              <a href="https://inner.com">
                <rect id="inner-rect" x="30" y="30" width="40" height="40" fill="red"/>
              </a>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap on inner rect (center) - should trigger inner anchor
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://inner.com');
      });

      testWidgets('clicking outer anchor area triggers outer link',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://outer.com">
              <rect id="outer-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
              <a href="https://inner.com">
                <rect x="60" y="60" width="20" height="20" fill="red"/>
              </a>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap on outer rect area (not overlapping with inner) - near top-left
        await tester.tapAt(topLeft + const Offset(50, 50));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://outer.com');
      });
    });

    group('anchor with various child elements', () {
      testWidgets('works with circle children', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://circle-link.com">
              <circle id="link-circle" cx="50" cy="50" r="40" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </circle>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap center of circle
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://circle-link.com');
      });

      testWidgets('works with path children', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://path-link.com">
              <path id="link-path" d="M10,10 L90,10 L90,90 L10,90 Z" fill="green">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </path>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap center
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://path-link.com');
      });

      testWidgets('works with text children', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <a href="https://text-link.com">
              <text id="link-text" x="10" y="30" font-size="20">Click me
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </text>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 400,
                  height: 100,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap on text area
        await tester.tapAt(topLeft + const Offset(80, 50));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://text-link.com');
      });
    });

    group('anchor with use element', () {
      testWidgets('anchor works with use element references', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <rect id="myRect" width="40" height="40" fill="purple"/>
            </defs>
            <a href="https://use-link.com">
              <use href="#myRect" x="30" y="30">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </use>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Tap on the used rect
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'https://use-link.com');
      });
    });

    group('anchor without href', () {
      testWidgets('does not trigger callback when anchor has no href',
          (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a>
              <rect id="no-link-rect" x="10" y="10" width="80" height="80" fill="gray">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNull);
      });
    });

    group('anchor with different URL types', () {
      testWidgets('handles relative URLs', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="/relative/path">
              <rect id="link-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, '/relative/path');
      });

      testWidgets('handles anchor fragment URLs', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="#section1">
              <rect id="link-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, '#section1');
      });

      testWidgets('handles mailto URLs', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="mailto:test@example.com">
              <rect id="link-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.href, 'mailto:test@example.com');
      });
    });

    group('anchor target attribute values', () {
      testWidgets('handles target="_self"', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com" target="_self">
              <rect id="target-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink?.target, '_self');
      });

      testWidgets('handles target="_parent"', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com" target="_parent">
              <rect id="target-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink?.target, '_parent');
      });

      testWidgets('handles target="_top"', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com" target="_top">
              <rect id="target-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink?.target, '_top');
      });

      testWidgets('target is null when not specified', (tester) async {
        SvgLinkInfo? tappedLink;

        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <a href="https://example.com">
              <rect id="target-rect" x="10" y="10" width="80" height="80" fill="blue">
                <animate attributeName="opacity" from="1" to="1" dur="1s"/>
              </rect>
            </a>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                  onLinkTap: (info) {
                    tappedLink = info;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();

        expect(tappedLink, isNotNull);
        expect(tappedLink!.target, isNull);
      });
    });

    group('SvgLinkInfo class', () {
      test('stores href correctly', () {
        const info = SvgLinkInfo(href: 'https://example.com');
        expect(info.href, 'https://example.com');
        expect(info.target, isNull);
      });

      test('stores href and target correctly', () {
        const info = SvgLinkInfo(href: 'https://example.com', target: '_blank');
        expect(info.href, 'https://example.com');
        expect(info.target, '_blank');
      });
    });
  });
}
