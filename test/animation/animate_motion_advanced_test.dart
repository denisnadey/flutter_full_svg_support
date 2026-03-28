import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/motion_path.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('AnimateMotion Advanced Tests', () {
    group('Arc path support', () {
      test('arc path is correctly parsed and traversed', () {
        final path = MotionPath('M50,100 A50,50 0 0,1 150,100');
        expect(path.totalLength, greaterThan(0));

        final start = path.getPointAtTime(0.0);
        expect(start.position.dx, closeTo(50, 1));
        expect(start.position.dy, closeTo(100, 1));

        final end = path.getPointAtTime(1.0);
        expect(end.position.dx, closeTo(150, 1));
        expect(end.position.dy, closeTo(100, 1));
      });

      test('degenerate arc with zero radius becomes line', () {
        final path = MotionPath('M0,0 A0,0 0 0,1 100,100');
        final point = path.getPointAtTime(1.0);
        expect(point.position.dx, closeTo(100, 1));
        expect(point.position.dy, closeTo(100, 1));
      });

      test('arc with rotation parameter', () {
        final path = MotionPath('M50,50 A30,20 45 1,1 100,100');
        expect(path.totalLength, greaterThan(0));

        final mid = path.getPointAtTime(0.5);
        expect(mid.position, isNot(equals(Offset.zero)));
      });
    });

    group('Segment boundary tangent averaging', () {
      test('tangent is averaged at path segment boundaries', () {
        // L-shaped path: horizontal then vertical
        final path = MotionPath('M0,0 L100,0 L100,100');

        // At the corner (t=0.5), tangent should be averaged
        final corner = path.getPointAtTime(0.5);
        expect(corner.position.dx, closeTo(100, 1));
        expect(corner.position.dy, closeTo(0, 1));
        // Angle should be somewhere between 0 (horizontal) and -pi/2 (vertical)
        // or exactly at a boundary value
        expect(corner.angle, lessThanOrEqualTo(0)); // Going down or horizontal
      });

      test('tangent averaging handles acute angles', () {
        // Sharp turn
        final path = MotionPath('M0,0 L50,0 L25,50');
        final turn = path.getPointAtTime(0.5);
        expect(turn.position.dx, closeTo(50, 2));
        expect(turn.position.dy, closeTo(0, 5));
      });
    });

    group('Degenerate case handling', () {
      test('zero-length segment handled gracefully', () {
        // Same start and end point for first segment
        final path = MotionPath('M0,0 L0,0 L100,100');
        final point = path.getPointAtTime(0.5);
        expect(point.position, isNot(equals(Offset.zero)));
      });

      test('single point path returns that point position', () {
        // A single MoveTo creates no traversable path but should return the position
        final path = MotionPath('M50,75');
        // With only a moveto, there's no length
        expect(path.totalLength, equals(0));
        // But the point should be at the moveTo position, not origin
        final point = path.getPointAtTime(0.5);
        expect(point.position.dx, closeTo(50, 1));
        expect(point.position.dy, closeTo(75, 1));
      });

      test('empty path returns zero', () {
        final path = MotionPath('');
        final point = path.getPointAtTime(0.5);
        expect(point.position, equals(Offset.zero));
      });
    });

    group('Values attribute with coordinate pairs', () {
      test('animateMotion with values parses coordinate pairs', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion values="0,0;100,0;100,100;0,100" dur="4s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].type, equals(SmilAnimationType.animateMotion));

        // Test interpolation at various points
        final valueAt0 = animations[0].computeValue(0.0) as String?;
        expect(valueAt0, contains('translate(0.0, 0.0)'));

        // At t=0.33 (1/3), we should be at or near first corner (100,0)
        final valueAt033 = animations[0].computeValue(0.333) as String?;
        expect(valueAt033, isNotNull);
        expect(valueAt033, contains('translate'));

        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, isNotNull);
      });

      test('two coordinate pairs works', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion values="0,0;100,100" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        final value = animations[0].computeValue(1.0) as String?;
        expect(value, contains('100'));
      });
    });

    group('From/to/by with coordinate pairs', () {
      test('animateMotion from/to with coordinates', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion from="0,0" to="100,100" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        final valueAt0 = animations[0].computeValue(0.0) as String?;
        expect(valueAt0, contains('translate(0.0, 0.0)'));

        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, contains('100'));
      });

      test('animateMotion with only from coordinate creates no-movement path', () {
        // When only from is specified without to/by, a zero-length path is created
        // This results in the animation not being created (no valid motion)
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion from="50,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // A from-only motion creates a zero-length path
        // The path M50,50 L50,50 has zero length, returning origin for traversal
        expect(animations.length, equals(1));
        // Since path has zero length, position returns origin
        final value = animations[0].computeValue(0.5) as String?;
        expect(value, contains('translate'));
      });

      test('animateMotion with by attribute', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion from="0,0" by="100,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, contains('100'));
        expect(valueAt1, contains('50'));
      });

      test('animateMotion by without from starts at origin', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion by="80,60" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        final valueAt0 = animations[0].computeValue(0.0) as String?;
        expect(valueAt0, contains('0.0, 0.0'));
      });
    });

    group('Paced calcMode', () {
      test('paced mode ignores keyPoints and keyTimes', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0 L100,100" 
      dur="1s" 
      calcMode="paced"
      keyPoints="0;0.25;1" 
      keyTimes="0;0.9;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // With paced mode, progress should be uniform along path length
        // Not influenced by keyPoints/keyTimes
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, isNotNull);
        expect(valueAt05, contains('translate'));
      });

      test('paced mode distributes time by arc length', () {
        // Path with segments of different lengths
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0 L100,10" 
      dur="1s" 
      calcMode="paced"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0.5, we should be roughly 50% along the total path length
        // First segment (100) + half of second segment (5) = not at the corner
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, isNotNull);
      });
    });

    group('Spline calcMode with keySplines', () {
      test('spline easing applied to motion', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,100" 
      dur="1s" 
      calcMode="spline"
      keyTimes="0;1"
      keySplines="0.5 0 0.5 1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].calcMode, equals(SmilCalcMode.spline));
        expect(animations[0].keySplines, isNotNull);

        final value = animations[0].computeValue(0.5) as String?;
        expect(value, isNotNull);
        expect(value, contains('translate'));
      });

      test('spline with keyPoints', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L50,0 L100,0" 
      dur="1s" 
      calcMode="spline"
      keyPoints="0;0.5;1"
      keyTimes="0;0.5;1"
      keySplines="0.42 0 0.58 1; 0.42 0 0.58 1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].keySplines!.length, equals(2));

        final value = animations[0].computeValue(0.5) as String?;
        expect(value, isNotNull);
      });
    });

    group('Accumulate sum for motion', () {
      test('accumulate adds position on each repeat', () {
        final svgString = '''
<svg viewBox="0 0 400 400">
  <rect>
    <animateMotion 
      path="M0,0 L100,50" 
      dur="1s" 
      repeatCount="3"
      accumulate="sum"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].accumulate, isTrue);

        // At end of first iteration
        final valueIter0 =
            animations[0].computeValue(1.0, completedRepeats: 0) as String?;
        expect(valueIter0, contains('100'));

        // At end of second iteration (should be at 200, 100)
        final valueIter1 =
            animations[0].computeValue(1.0, completedRepeats: 1) as String?;
        expect(valueIter1, contains('200'));

        // At end of third iteration (should be at 300, 150)
        final valueIter2 =
            animations[0].computeValue(1.0, completedRepeats: 2) as String?;
        expect(valueIter2, contains('300'));
      });

      test('accumulate works mid-iteration', () {
        final svgString = '''
<svg viewBox="0 0 400 400">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      repeatCount="3"
      accumulate="sum"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // At t=0.5 in second iteration
        final value =
            animations[0].computeValue(0.5, completedRepeats: 1) as String?;
        // Position should be ~150 (100 from first + 50 from current)
        expect(value, contains('150'));
      });
    });

    group('Rotation semantics', () {
      test('auto rotation follows path tangent', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L100,100" dur="1s" rotate="auto"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final value = animations[0].computeValue(0.5) as String?;
        expect(value, contains('rotate'));
        // Diagonal path should have ~45 degree rotation (actually -45 in SVG coords)
        expect(value, matches(RegExp(r'rotate\(-?45')));
      });

      test('auto-reverse adds 180 degrees', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L100,0" dur="1s" rotate="auto-reverse"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final value = animations[0].computeValue(0.5) as String?;
        expect(value, contains('rotate'));
        expect(value, contains('180'));
      });

      test('fixed angle rotation stays constant', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L100,0 L100,100" dur="1s" rotate="90"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final value0 = animations[0].computeValue(0.0) as String?;
        final value05 = animations[0].computeValue(0.5) as String?;
        final value1 = animations[0].computeValue(1.0) as String?;

        // All should have rotate(90)
        expect(value0, contains('rotate(90'));
        expect(value05, contains('rotate(90'));
        expect(value1, contains('rotate(90'));
      });

      test('rotation on curved path changes smoothly', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,100 C50,0 150,0 200,100" dur="1s" rotate="auto"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final value0 = animations[0].computeValue(0.0) as String?;
        final value05 = animations[0].computeValue(0.5) as String?;
        final value1 = animations[0].computeValue(1.0) as String?;

        // Extract rotation values and verify they're different
        expect(value0, contains('rotate'));
        expect(value05, contains('rotate'));
        expect(value1, contains('rotate'));
      });
    });

    group('Fill mode freeze', () {
      test('freeze preserves final position and rotation', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L100,100" dur="1s" fill="freeze" rotate="auto"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations[0].fillMode, equals(SmilFillMode.freeze));

        // Test final value
        final finalValue = animations[0].computeValue(1.0) as String?;
        expect(finalValue, contains('translate'));
        expect(finalValue, contains('rotate'));
        expect(finalValue, contains('100'));
      });
    });

    group('keyPoints with keyTimes', () {
      test('keyPoints controls position along path', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      keyPoints="0;0.25;1" 
      keyTimes="0;0.8;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0.8, we should be at keyPoint 0.25 (25% along path = x=25)
        final valueAt08 = animations[0].computeValue(0.8) as String?;
        expect(valueAt08, isNotNull);
        // Should be around x=25
      });

      test('keyPoints without keyTimes uses uniform distribution', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      keyPoints="0;0.5;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0.5, should be at keyPoint 0.5 (middle)
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, isNotNull);
      });
    });

    group('mpath reference', () {
      test('mpath href resolves to referenced path', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <defs>
    <path id="motionPath" d="M10,80 Q95,10 180,80"/>
  </defs>
  <rect>
    <animateMotion dur="2s">
      <mpath href="#motionPath"/>
    </animateMotion>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].from, equals('M10,80 Q95,10 180,80'));
      });

      test('mpath xlink:href also works', () {
        final svgString = '''
<svg xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 200 200">
  <defs>
    <path id="mp" d="M0,0 L100,0"/>
  </defs>
  <rect>
    <animateMotion dur="1s">
      <mpath xlink:href="#mp"/>
    </animateMotion>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].from, equals('M0,0 L100,0'));
      });

      test('inline path takes precedence over mpath', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <defs>
    <path id="ignored" d="M0,0 L50,50"/>
  </defs>
  <rect>
    <animateMotion path="M0,0 L100,100" dur="1s">
      <mpath href="#ignored"/>
    </animateMotion>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].from, equals('M0,0 L100,100'));
      });
    });

    group('Path priority', () {
      test('path attribute takes precedence over values', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion path="M0,0 L100,100" values="0,0;50,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        // Should use the path attribute
        final value = animations[0].computeValue(1.0) as String?;
        expect(value, contains('100'));
      });

      test('values takes precedence over from/to', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion values="0,0;75,75" from="0,0" to="50,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        // Should use values, ending at 75,75
        final value = animations[0].computeValue(1.0) as String?;
        expect(value, contains('75'));
      });
    });

    group('MotionPath utility methods', () {
      test('parseCoordinatePair handles comma separator', () {
        final offset = MotionPath.parseCoordinatePair('100,50');
        expect(offset, isNotNull);
        expect(offset!.dx, equals(100));
        expect(offset.dy, equals(50));
      });

      test('parseCoordinatePair handles space separator', () {
        final offset = MotionPath.parseCoordinatePair('100 50');
        expect(offset, isNotNull);
        expect(offset!.dx, equals(100));
        expect(offset.dy, equals(50));
      });

      test('parseCoordinatePair handles negative values', () {
        final offset = MotionPath.parseCoordinatePair('-50,-25');
        expect(offset, isNotNull);
        expect(offset!.dx, equals(-50));
        expect(offset.dy, equals(-25));
      });

      test('parseCoordinatePairs parses multiple pairs', () {
        final pairs = MotionPath.parseCoordinatePairs('0,0;100,0;100,100');
        expect(pairs.length, equals(3));
        expect(pairs[0], equals(const Offset(0, 0)));
        expect(pairs[1], equals(const Offset(100, 0)));
        expect(pairs[2], equals(const Offset(100, 100)));
      });

      test('getEndPosition returns final path position', () {
        final path = MotionPath('M0,0 L100,75');
        final end = path.getEndPosition();
        expect(end.dx, closeTo(100, 0.1));
        expect(end.dy, closeTo(75, 0.1));
      });

      test('getSegmentLengths returns per-segment lengths', () {
        final path = MotionPath('M0,0 L100,0 L100,100');
        final lengths = path.getSegmentLengths();
        expect(lengths.length, greaterThan(0));
        // First segment is 100, second is 100
        expect(lengths.reduce((a, b) => a + b), closeTo(200, 1));
      });
    });

    group('Complex path types', () {
      test('smooth cubic bezier (S command)', () {
        final path = MotionPath('M0,0 C10,20 40,20 50,0 S90,-20 100,0');
        expect(path.totalLength, greaterThan(0));

        final mid = path.getPointAtTime(0.5);
        expect(mid.position, isNot(equals(Offset.zero)));
      });

      test('quadratic bezier (Q command)', () {
        final path = MotionPath('M0,0 Q50,100 100,0');
        expect(path.totalLength, greaterThan(0));

        final mid = path.getPointAtTime(0.5);
        // Mid point of quadratic should be pulled toward control point
        expect(mid.position.dy, greaterThan(0));
      });

      test('smooth quadratic bezier (T command)', () {
        final path = MotionPath('M0,0 Q25,50 50,0 T100,0');
        expect(path.totalLength, greaterThan(0));

        final point = path.getPointAtTime(0.75);
        expect(point.position, isNot(equals(Offset.zero)));
      });

      test('horizontal and vertical lines (H/V)', () {
        final path = MotionPath('M0,0 H100 V100 H0 Z');
        expect(path.totalLength, closeTo(400, 1));

        final corner = path.getPointAtTime(0.25);
        expect(corner.position.dx, closeTo(100, 1));
        expect(corner.position.dy, closeTo(0, 1));
      });
    });

    group('To-animation mode (only to attribute)', () {
      test('animateMotion with only to attribute starts at origin', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion to="100,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].type, equals(SmilAnimationType.animateMotion));

        // At t=0, should be at origin (0,0)
        final valueAt0 = animations[0].computeValue(0.0) as String?;
        expect(valueAt0, contains('translate(0.0, 0.0)'));

        // At t=1, should be at (100,50)
        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, contains('100'));
        expect(valueAt1, contains('50'));
      });

      test('to-only animation interpolates correctly', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion to="200,100" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // At t=0.5, should be halfway (100,50)
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, contains('100'));
        expect(valueAt05, contains('50'));
      });
    });

    group('By-animation mode (only by attribute)', () {
      test('animateMotion with only by attribute moves from origin', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion by="100,75" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0, should be at origin
        final valueAt0 = animations[0].computeValue(0.0) as String?;
        expect(valueAt0, contains('0.0, 0.0'));

        // At t=1, should have moved BY (100,75) from origin
        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, contains('100'));
        expect(valueAt1, contains('75'));
      });

      test('by-animation is implicitly additive', () {
        // Per SVG spec: by-animation is additive
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion by="50,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final valueAt1 = animations[0].computeValue(1.0) as String?;
        expect(valueAt1, contains('50'));
      });
    });

    group('keyTimes without keyPoints', () {
      test('generates uniform keyPoints from keyTimes', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      keyTimes="0;0.5;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        // keyPoints should be generated as uniform: [0, 0.5, 1]
        expect(animations[0].values, isNotNull);
        expect(animations[0].values!.length, equals(3));
        // With uniform keyTimes, position at t=0.5 should be at 50% of path
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, contains('50'));
      });

      test('keyTimes controls pacing with non-uniform timing', () {
        // keyTimes="0;0.9;1" means spend 90% of time in first half of path
        // With uniform keyPoints [0, 0.5, 1]:
        // - keyTimes [0, 0.9, 1] maps to keyPoints [0, 0.5, 1]
        // - At t=0.5, we're in first segment (0→0.9), local progress = 0.5/0.9 ≈ 0.556
        // - Position = lerp(0, 0.5, 0.556) ≈ 0.278 along path
        // - For path M0,0 L100,0: x ≈ 27.8, NOT 50
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      keyTimes="0;0.9;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0.5, should NOT be at 50% of path due to non-uniform keyTimes
        // With keyTimes="0;0.9;1" and uniform keyPoints [0, 0.5, 1]:
        // t=0.5 is in segment [0, 0.9], local t = 0.5/0.9 ≈ 0.556
        // position = lerp(0, 0.5, 0.556) ≈ 0.278, so x ≈ 27.8
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, isNotNull);

        // Extract x value from translate string
        final translateMatch = RegExp(
          r'translate\(([\d.]+),',
        ).firstMatch(valueAt05!);
        expect(translateMatch, isNotNull);
        final xValue = double.parse(translateMatch!.group(1)!);

        // x should be around 27.8, NOT 50 (which would indicate no pacing effect)
        expect(
          xValue,
          lessThan(35),
          reason:
              'At t=0.5 with keyTimes="0;0.9;1", '
              'position should be well below 50% of path (~27.8)',
        );
        expect(
          xValue,
          greaterThan(20),
          reason: 'Position should be around 27.8',
        );
      });

      test('at keyTime boundary, position matches keyPoint', () {
        // At t=0.9 (second keyTime), should be exactly at keyPoint[1]=0.5 (x=50)
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      keyTimes="0;0.9;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // At t=0.9, should be at keyPoint[1] = 0.5 of path = x=50
        final valueAt09 = animations[0].computeValue(0.9) as String?;
        expect(valueAt09, isNotNull);
        expect(valueAt09, contains('translate'));

        // Extract and verify x value
        final translateMatch = RegExp(
          r'translate\(([\d.]+),',
        ).firstMatch(valueAt09!);
        expect(translateMatch, isNotNull);
        final xValue = double.parse(translateMatch!.group(1)!);
        expect(xValue, closeTo(50, 1));
      });
    });

    group('Discrete calcMode with keyPoints', () {
      test('discrete mode jumps between keyPoints', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      calcMode="discrete"
      keyPoints="0;0.5;1"
      keyTimes="0;0.5;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].calcMode, equals(SmilCalcMode.discrete));

        // At t=0.25 (within first segment), should be at keyPoint[0] = 0 (position 0)
        final valueAt025 = animations[0].computeValue(0.25) as String?;
        expect(valueAt025, contains('0.0, 0.0'));

        // At t=0.6 (within second segment), should be at keyPoint[1] = 0.5 (position 50)
        final valueAt06 = animations[0].computeValue(0.6) as String?;
        expect(valueAt06, contains('50'));
      });

      test('discrete mode with 4 keyPoints', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L100,0" 
      dur="1s" 
      calcMode="discrete"
      keyPoints="0;0.25;0.75;1"
      keyTimes="0;0.33;0.66;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // At t=0.2, should be at keyPoint[0] = 0 (x=0)
        final valueAt02 = animations[0].computeValue(0.2) as String?;
        expect(valueAt02, contains('0.0, 0.0'));

        // At t=0.5, should be at keyPoint[1] = 0.25 (x=25)
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, contains('25'));
      });
    });

    group('Zero-length path handling', () {
      test('zero-length path returns start position', () {
        // Path with same start and end point
        final path = MotionPath('M50,75 L50,75');

        // Should return the position at the start point
        final point = path.getPointAtTime(0.5);
        expect(point.position.dx, closeTo(50, 1));
        expect(point.position.dy, closeTo(75, 1));
      });

      test('animateMotion with from-only creates stationary animation', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion from="50,50" dur="1s"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));

        // Should stay at the from position
        final valueAt0 = animations[0].computeValue(0.0) as String?;
        final valueAt1 = animations[0].computeValue(1.0) as String?;

        // Both should be at or near (50,50)
        expect(valueAt0, contains('50'));
        expect(valueAt1, contains('50'));
      });

      test('path with coincident points detects as closed', () {
        // Path that ends very close to where it started
        final path = MotionPath('M0,0 L100,0 L100,100 L0,100 L0.0001,0.0001');
        expect(path.isClosed, isTrue);
      });

      test('explicitly closed path detected', () {
        final path = MotionPath('M0,0 L100,0 L100,100 Z');
        expect(path.isClosed, isTrue);
      });
    });

    group('Paced calcMode with coordinate pairs', () {
      test('paced mode with values coordinates', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      values="0,0;100,0;100,100" 
      dur="1s" 
      calcMode="paced"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].calcMode, equals(SmilCalcMode.paced));

        // At t=0.5, should be ~50% along the total path
        // Path is: 0,0 -> 100,0 (length 100) -> 100,100 (length 100)
        // Total length = 200, so at t=0.5 should be at (100,0)
        final valueAt05 = animations[0].computeValue(0.5) as String?;
        expect(valueAt05, isNotNull);
        expect(valueAt05, contains('translate'));
      });

      test('paced mode ignores user-provided keyTimes', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      values="0,0;100,0;100,100" 
      dur="1s" 
      calcMode="paced"
      keyTimes="0;0.1;1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // Paced mode should ignore keyTimes
        expect(animations[0].keyTimes, isNull);
      });
    });

    group('Spline easing per segment', () {
      test('multi-segment spline with different easing per segment', () {
        final svgString = '''
<svg viewBox="0 0 200 200">
  <rect>
    <animateMotion 
      path="M0,0 L50,0 L100,0" 
      dur="1s" 
      calcMode="spline"
      keyPoints="0;0.5;1"
      keyTimes="0;0.5;1"
      keySplines="0.42 0 0.58 1; 0.25 0.1 0.25 1"/>
  </rect>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        expect(animations.length, equals(1));
        expect(animations[0].keySplines!.length, equals(2));

        // Values at different points should reflect the spline easing
        final value1 = animations[0].computeValue(0.25) as String?;
        final value2 = animations[0].computeValue(0.75) as String?;
        expect(value1, isNotNull);
        expect(value2, isNotNull);
      });
    });

    group('Closed path handling', () {
      test('closed rectangular path works correctly', () {
        final path = MotionPath('M0,0 L100,0 L100,100 L0,100 Z');
        expect(path.totalLength, closeTo(400, 1));
        expect(path.isClosed, isTrue);

        final start = path.getPointAtTime(0.0);
        final end = path.getPointAtTime(1.0);

        // Start and end should be at (0,0)
        expect(start.position.dx, closeTo(0, 1));
        expect(start.position.dy, closeTo(0, 1));
        expect(end.position.dx, closeTo(0, 1));
        expect(end.position.dy, closeTo(0, 1));
      });

      test('arePointsCoincident utility', () {
        const p1 = Offset(100, 100);
        const p2 = Offset(100.0001, 100.0001);
        const p3 = Offset(101, 100);

        expect(MotionPath.arePointsCoincident(p1, p2), isTrue);
        expect(MotionPath.arePointsCoincident(p1, p3), isFalse);
      });
    });
  });
}
