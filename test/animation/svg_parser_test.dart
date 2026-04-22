import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animation_detector.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('AnimationDetector', () {
    test('detects SMIL animate elements', () {
      const svg = '''
        <svg>
          <rect>
            <animate attributeName="x" from="0" to="100" dur="1s"/>
          </rect>
        </svg>
      ''';

      expect(AnimationDetector.hasAnimations(svg), isTrue);
      expect(AnimationDetector.hasSmilAnimations(svg), isTrue);
      expect(AnimationDetector.hasCssAnimations(svg), isFalse);
    });

    test('detects SMIL animateTransform elements', () {
      const svg = '''
        <svg>
          <rect>
            <animateTransform attributeName="transform" 
                              type="rotate" 
                              from="0" to="360" dur="2s"/>
          </rect>
        </svg>
      ''';

      expect(AnimationDetector.hasAnimations(svg), isTrue);
      expect(AnimationDetector.hasSmilAnimations(svg), isTrue);
    });

    test('detects CSS keyframes', () {
      const svg = '''
        <svg>
          <style>
            @keyframes rotate {
              from { transform: rotate(0deg); }
              to { transform: rotate(360deg); }
            }
          </style>
        </svg>
      ''';

      expect(AnimationDetector.hasAnimations(svg), isTrue);
      expect(AnimationDetector.hasCssAnimations(svg), isTrue);
      expect(AnimationDetector.hasSmilAnimations(svg), isFalse);
    });

    test('detects CSS animation properties', () {
      const svg = '''
        <svg>
          <rect style="animation: rotate 2s infinite"/>
        </svg>
      ''';

      expect(AnimationDetector.hasAnimations(svg), isTrue);
      expect(AnimationDetector.hasCssAnimations(svg), isTrue);
    });

    test('returns false for static SVG', () {
      const svg = '''
        <svg>
          <rect x="10" y="10" width="100" height="100" fill="red"/>
        </svg>
      ''';

      expect(AnimationDetector.hasAnimations(svg), isFalse);
    });

    test('analyzeAnimations provides detailed info', () {
      const svg = '''
        <svg>
          <rect>
            <animate attributeName="x"/>
            <animateTransform attributeName="transform"/>
          </rect>
          <style>
            @keyframes test {}
          </style>
        </svg>
      ''';

      final info = AnimationDetector.analyzeAnimations(svg);

      expect(info.hasSmilAnimate, isTrue);
      expect(info.hasSmilAnimateTransform, isTrue);
      expect(info.hasCssKeyframes, isTrue);
      expect(info.hasAnySmil, isTrue);
      expect(info.hasAnyCss, isTrue);
      expect(info.hasAny, isTrue);
    });
  });

  group('SvgParser', () {
    test('parses simple rect element', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="myRect" x="10" y="20" width="30" height="40" fill="red"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(doc.root.tagName, equals('svg'));
      expect(doc.viewBox, equals(const ui.Rect.fromLTWH(0, 0, 100, 100)));
      expect(doc.root.children.length, equals(1));

      final rect = doc.root.children[0];
      expect(rect.tagName, equals('rect'));
      expect(rect.id, equals('myRect'));
      expect(rect.getAttributeValue('x'), equals(10.0));
      expect(rect.getAttributeValue('y'), equals(20.0));
      expect(rect.getAttributeValue('width'), equals(30.0));
      expect(rect.getAttributeValue('height'), equals(40.0));
    });

    test('parses text spacing attributes as numeric values', () {
      const svgXml = '''
        <svg>
          <text id="label" x="10" y="20" font-size="16" letter-spacing="12" word-spacing="18" textLength="64">A A</text>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final text = doc.root.children[0];

      expect(text.tagName, equals('text'));
      expect(text.getAttributeValue('font-size'), equals(16.0));
      expect(text.getAttributeValue('letter-spacing'), equals(12.0));
      expect(text.getAttributeValue('word-spacing'), equals(18.0));
      expect(text.getAttributeValue('textLength'), equals(64.0));
    });

    test('parses circle element', () {
      const svgXml = '''
        <svg>
          <circle cx="50" cy="50" r="25" fill="blue"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final circle = doc.root.children[0];

      expect(circle.tagName, equals('circle'));
      expect(circle.getAttributeValue('cx'), equals(50.0));
      expect(circle.getAttributeValue('cy'), equals(50.0));
      expect(circle.getAttributeValue('r'), equals(25.0));
    });

    test('parses nested groups', () {
      const svgXml = '''
        <svg>
          <g id="group1">
            <g id="group2">
              <rect id="rect1"/>
            </g>
          </g>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final group1 = doc.root.children[0];
      final group2 = group1.children[0];
      final rect = group2.children[0];

      expect(group1.id, equals('group1'));
      expect(group2.id, equals('group2'));
      expect(rect.id, equals('rect1'));
      expect(rect.parent, equals(group2));
      expect(group2.parent, equals(group1));
    });

    test('parses hex colors', () {
      const svgXml = '''
        <svg>
          <rect fill="#FF0000"/>
          <circle fill="#00F"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final rect = doc.root.children[0];
      final circle = doc.root.children[1];

      expect(
        rect.getAttributeValue('fill'),
        equals(const ui.Color(0xFFFF0000)),
      );
      expect(
        circle.getAttributeValue('fill'),
        equals(const ui.Color(0xFF0000FF)),
      );
    });

    test('parses extended hex colors with alpha', () {
      const svgXml = '''
        <svg>
          <rect fill="#1234"/>
          <circle fill="#11223344"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final rect = doc.root.children[0];
      final circle = doc.root.children[1];

      expect(
        rect.getAttributeValue('fill'),
        equals(const ui.Color(0x44112233)),
      );
      expect(
        circle.getAttributeValue('fill'),
        equals(const ui.Color(0x44112233)),
      );
    });

    test('parses rgb and rgba colors', () {
      const svgXml = '''
        <svg>
          <rect fill="rgb(255, 0, 0)"/>
          <circle fill="rgb(100% 0% 0%)"/>
          <ellipse fill="rgba(255 0 0 / 50%)"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(
        doc.root.children[0].getAttributeValue('fill'),
        equals(const ui.Color(0xFFFF0000)),
      );
      expect(
        doc.root.children[1].getAttributeValue('fill'),
        equals(const ui.Color(0xFFFF0000)),
      );
      expect(
        doc.root.children[2].getAttributeValue('fill'),
        equals(const ui.Color(0x80FF0000)),
      );
    });

    test('parses hsl and hsla colors', () {
      const svgXml = '''
        <svg>
          <rect fill="hsl(120, 100%, 50%)"/>
          <circle fill="hsla(240deg 100% 50% / 25%)"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(
        doc.root.children[0].getAttributeValue('fill'),
        equals(const ui.Color(0xFF00FF00)),
      );
      expect(
        doc.root.children[1].getAttributeValue('fill'),
        equals(const ui.Color(0x400000FF)),
      );
    });

    test('parses named colors', () {
      const svgXml = '''
        <svg>
          <rect fill="red"/>
          <circle fill="blue"/>
          <ellipse fill="green"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(
        doc.root.children[0].getAttributeValue('fill'),
        equals(const ui.Color(0xFFFF0000)),
      );
      expect(
        doc.root.children[1].getAttributeValue('fill'),
        equals(const ui.Color(0xFF0000FF)),
      );
      expect(
        doc.root.children[2].getAttributeValue('fill'),
        equals(const ui.Color(0xFF008000)),
      );
    });

    test('parses extended CSS named colors', () {
      const svgXml = '''
        <svg>
          <rect fill="rebeccapurple"/>
          <circle fill="lightgoldenrodyellow"/>
          <ellipse fill="darkslategray"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      expect(
        doc.root.children[0].getAttributeValue('fill'),
        equals(const ui.Color(0xFF663399)),
      );
      expect(
        doc.root.children[1].getAttributeValue('fill'),
        equals(const ui.Color(0xFFFAFAD2)),
      );
      expect(
        doc.root.children[2].getAttributeValue('fill'),
        equals(const ui.Color(0xFF2F4F4F)),
      );
    });

    test('parses class attribute', () {
      const svgXml = '''
        <svg>
          <rect class="red-box large"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final rect = doc.root.children[0];

      expect(rect.className, equals('red-box large'));
    });

    test('handles viewBox with commas and spaces', () {
      const svgXml = '<svg viewBox="0, 0,  100,  100"/>';
      final doc = SvgParser.parse(svgXml);

      expect(doc.viewBox, equals(const ui.Rect.fromLTWH(0, 0, 100, 100)));
    });

    test('handles width and height attributes', () {
      const svgXml = '<svg width="200" height="150"/>';
      final doc = SvgParser.parse(svgXml);

      expect(doc.width, equals(200.0));
      expect(doc.height, equals(150.0));
    });

    test('preserves path data as string', () {
      const svgXml = '''
        <svg>
          <path d="M10 10 L20 20 Z"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final path = doc.root.children[0];

      expect(path.getAttributeValue('d'), equals('M10 10 L20 20 Z'));
    });

    test('preserves transform as string', () {
      const svgXml = '''
        <svg>
          <rect transform="translate(10, 20) rotate(45)"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final rect = doc.root.children[0];

      expect(
        rect.getAttributeValue('transform'),
        equals('translate(10, 20) rotate(45)'),
      );
    });
  });

  group('SvgDocument', () {
    test('getElementById finds node by id', () {
      const svgXml = '''
        <svg>
          <g id="group1">
            <rect id="rect1"/>
            <circle id="circle1"/>
          </g>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      final group = doc.getElementById('group1');
      expect(group, isNotNull);
      expect(group!.tagName, equals('g'));

      final rect = doc.getElementById('rect1');
      expect(rect, isNotNull);
      expect(rect!.tagName, equals('rect'));

      final notFound = doc.getElementById('nonexistent');
      expect(notFound, isNull);
    });

    test('getElementsByClass finds nodes by class', () {
      const svgXml = '''
        <svg>
          <rect class="shape red"/>
          <circle class="shape blue"/>
          <ellipse class="shape red"/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      final shapes = doc.getElementsByClass('shape');
      expect(shapes.length, equals(3));

      final redShapes = doc.getElementsByClass('red');
      expect(redShapes.length, equals(2));
    });

    test('getElementsByTag finds nodes by tag name', () {
      const svgXml = '''
        <svg>
          <rect/>
          <circle/>
          <rect/>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);

      final rects = doc.getElementsByTag('rect');
      expect(rects.length, equals(2));

      final circles = doc.getElementsByTag('circle');
      expect(circles.length, equals(1));
    });
  });

  group('SvgNode', () {
    test('AnimatableSvgAttribute tracks animated value', () {
      final attr = AnimatableSvgAttribute(
        name: 'x',
        baseValue: 10.0,
        type: SvgAttributeType.number,
      );

      expect(attr.effectiveValue, equals(10.0));
      expect(attr.isAnimated, isFalse);

      attr.setAnimatedValue(50.0);
      expect(attr.effectiveValue, equals(50.0));
      expect(attr.isAnimated, isTrue);

      attr.clearAnimation();
      expect(attr.effectiveValue, equals(10.0));
      expect(attr.isAnimated, isFalse);
    });

    test('hasAnimations flag propagates to parents', () {
      final root = SvgNode(tagName: 'svg');
      final group = SvgNode(tagName: 'g');
      final rect = SvgNode(tagName: 'rect');

      root.addChild(group);
      group.addChild(rect);

      expect(root.hasAnimations, isFalse);
      expect(group.hasAnimations, isFalse);
      expect(rect.hasAnimations, isFalse);

      // Добавляем дочерний элемент с анимацией
      final animatedChild = SvgNode(tagName: 'circle');
      animatedChild.hasAnimations = true;
      rect.addChild(animatedChild);

      // Флаг должен распространиться вверх через addChild
      expect(root.hasAnimations, isTrue);
      expect(group.hasAnimations, isTrue);
      expect(rect.hasAnimations, isTrue);
    });
  });
}
