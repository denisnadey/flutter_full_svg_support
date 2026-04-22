import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

void main() {
  group('SVG Accessibility - Title and Desc Parsing', () {
    test('parses title element text content on parent', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>My SVG Image</title>
          <rect x="10" y="10" width="80" height="80" fill="red"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.titleText, equals('My SVG Image'));
    });

    test('parses desc element text content on parent', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <desc>This is a description of the SVG</desc>
          <rect x="10" y="10" width="80" height="80" fill="red"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.descText, equals('This is a description of the SVG'));
    });

    test('parses both title and desc on root SVG', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Chart Title</title>
          <desc>A bar chart showing quarterly sales data</desc>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.titleText, equals('Chart Title'));
      expect(
        doc.root.descText,
        equals('A bar chart showing quarterly sales data'),
      );
    });

    test('normalizes whitespace in title/desc', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>  Multiple   spaces   here  </title>
          <desc>
            This has
            line breaks
            and extra spaces
          </desc>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.titleText, equals('Multiple spaces here'));
      expect(
        doc.root.descText,
        equals('This has line breaks and extra spaces'),
      );
    });

    test('parses title/desc on nested elements', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Root Title</title>
          <g id="group1">
            <title>Group Title</title>
            <desc>Group description</desc>
            <rect x="10" y="10" width="30" height="30" fill="red">
              <title>Rectangle Title</title>
            </rect>
          </g>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final group = doc.getElementById('group1');

      expect(doc.root.titleText, equals('Root Title'));
      expect(group!.titleText, equals('Group Title'));
      expect(group.descText, equals('Group description'));

      // Find rect by traversing children
      final rect = group.children.firstWhere(
        (n) => n.tagName == 'rect',
        orElse: () => throw StateError('rect not found'),
      );
      expect(rect.titleText, equals('Rectangle Title'));
    });

    test('ignores empty title/desc elements', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title></title>
          <desc>   </desc>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.titleText, isNull);
      expect(doc.root.descText, isNull);
    });
  });

  group('SVG Accessibility - ARIA Attributes', () {
    test('parses aria-label attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" aria-label="Decorative icon">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.ariaLabel, equals('Decorative icon'));
    });

    test('parses aria-describedby attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" aria-describedby="desc-text">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.ariaDescribedby, equals('desc-text'));
    });

    test('parses role attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" role="img">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.ariaRole, equals('img'));
    });

    test('parses all ARIA attributes together', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" 
             aria-label="Navigation menu"
             aria-describedby="menu-desc"
             role="navigation">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.ariaLabel, equals('Navigation menu'));
      expect(doc.root.ariaDescribedby, equals('menu-desc'));
      expect(doc.root.ariaRole, equals('navigation'));
    });

    test('parses ARIA attributes on nested elements', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <g id="btn" role="button" aria-label="Click me">
            <rect x="10" y="10" width="80" height="30" fill="blue"/>
            <text x="50" y="30" aria-hidden="true">Click</text>
          </g>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final group = doc.getElementById('btn');

      expect(group!.ariaRole, equals('button'));
      expect(group.ariaLabel, equals('Click me'));
    });
  });

  group('SVG Accessibility - SvgDocument Accessors', () {
    test('accessibleName returns aria-label when present', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" aria-label="ARIA Label">
          <title>Title Text</title>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      // aria-label takes precedence over title
      expect(doc.accessibleName, equals('ARIA Label'));
    });

    test('accessibleName falls back to title when no aria-label', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Title Text</title>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.accessibleName, equals('Title Text'));
    });

    test('accessibleDescription returns aria-describedby when present', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" aria-describedby="external-desc">
          <desc>Internal Description</desc>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      // aria-describedby takes precedence over desc
      expect(doc.accessibleDescription, equals('external-desc'));
    });

    test(
      'accessibleDescription falls back to desc when no aria-describedby',
      () {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <desc>Internal Description</desc>
        </svg>
      ''';

        final doc = SvgParser.parse(svgXml);

        expect(doc.accessibleDescription, equals('Internal Description'));
      },
    );

    test('accessibleRole defaults to img when not specified', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.accessibleRole, equals('img'));
    });

    test('accessibleRole returns specified role attribute', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100" role="button">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.accessibleRole, equals('button'));
    });

    test('returns null when no accessibility info present', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.accessibleName, isNull);
      expect(doc.accessibleDescription, isNull);
    });
  });

  group('SVG Accessibility - Widget Integration', () {
    testWidgets('AnimatedSvgPicture wraps with Semantics when title present', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Accessible SVG</title>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
          ),
        ),
      );

      // Find Semantics widget that wraps the CustomPaint
      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.label == 'Accessible SVG';
        }
        return false;
      });
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('AnimatedSvgPicture wraps with Semantics when desc present', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <desc>A blue rectangle</desc>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.hint == 'A blue rectangle';
        }
        return false;
      });
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('AnimatedSvgPicture uses aria-label over title', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100" aria-label="ARIA Label">
          <title>Title Text</title>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.label == 'ARIA Label';
        }
        return false;
      });
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('AnimatedSvgPicture sets image role for role=img', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100" role="img">
          <title>Image</title>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.image == true && props.label == 'Image';
        }
        return false;
      });
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('AnimatedSvgPicture sets button role', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100" role="button">
          <title>Click me</title>
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.button == true && props.label == 'Click me';
        }
        return false;
      });
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets(
      'AnimatedSvgPicture does not add Semantics when no accessibility info',
      (tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="blue"/>
        </svg>
      ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 100, height: 100),
            ),
          ),
        );

        // Should find the CustomPaint but not as a descendant of Semantics with label
        final ancestorSemantics = find.byWidgetPredicate((widget) {
          if (widget is Semantics) {
            final props = widget.properties;
            return props.label != null || props.hint != null;
          }
          return false;
        });
        expect(ancestorSemantics, findsNothing);
      },
    );
  });

  group('SVG Accessibility - Edge Cases', () {
    test('handles multiple title elements (uses first)', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>First Title</title>
          <title>Second Title</title>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      // First title should be used
      expect(doc.root.titleText, equals('First Title'));
    });

    test('handles title with nested elements', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Title with <tspan>nested</tspan> content</title>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      // Should extract all text content
      expect(doc.root.titleText, equals('Title with nested content'));
    });

    test('title and desc nodes are added as children', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Title</title>
          <desc>Description</desc>
          <rect x="0" y="0" width="100" height="100"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      // Title and desc should be children of root
      final titleNode = doc.root.children.firstWhere(
        (n) => n.tagName == 'title',
        orElse: () => throw StateError('title not found'),
      );
      final descNode = doc.root.children.firstWhere(
        (n) => n.tagName == 'desc',
        orElse: () => throw StateError('desc not found'),
      );

      expect(titleNode, isNotNull);
      expect(descNode, isNotNull);
      expect(doc.root.children.length, equals(3)); // title, desc, rect
    });

    test('handles special characters in title/desc', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <title>Title with &lt;special&gt; &amp; "characters"</title>
          <desc>Description with émojis 🎉 and ñ</desc>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.titleText, equals('Title with <special> & "characters"'));
      expect(doc.root.descText, equals('Description with émojis 🎉 and ñ'));
    });
  });
}
