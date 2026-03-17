import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/playground/playground_analyzer.dart';

void main() {
  group('PlaygroundAnalyzer', () {
    const analyzer = PlaygroundAnalyzer();

    test('analyzes basic valid svg', () {
      const svg = '''
<svg viewBox="0 0 10 10">
  <rect id="shape" x="0" y="0" width="10" height="10" fill="red"/>
</svg>
''';

      final report = analyzer.analyze(svg);
      expect(report.parseSuccess, isTrue);
      expect(report.canRender, isTrue);
      expect(
        report.issues.where((issue) => issue.severity.name == 'error'),
        isEmpty,
      );
      expect(report.unsupportedTags, isEmpty);
      expect(report.brokenReferences, isEmpty);
    });

    test('reports unsupported tags and broken references', () {
      const svg = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fx">
      <feConvolveMatrix/>
    </filter>
  </defs>
  <pattern id="label"/>
  <rect
    id="shape"
    x="0"
    y="0"
    width="50"
    height="50"
    fill="url(#missingGradient)"
    filter="url(#missingFilter)"/>
</svg>
''';

      final report = analyzer.analyze(svg);

      expect(report.unsupportedTags, contains('pattern'));
      expect(report.unsupportedFilterPrimitives, contains('feConvolveMatrix'));
      expect(
        report.brokenReferences.any(
          (entry) => entry.contains('missingGradient'),
        ),
        isTrue,
      );
      expect(
        report.brokenReferences.any((entry) => entry.contains('missingFilter')),
        isTrue,
      );
      expect(
        report.issues.any((issue) => issue.code == 'parity.unsupported_tag'),
        isTrue,
      );
      expect(
        report.issues.any((issue) => issue.code == 'refs.missing_target'),
        isTrue,
      );
    });

    test('reports missing event target ids', () {
      const svg = '''
<svg viewBox="0 0 100 100">
  <rect id="box" x="0" y="0" width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="50" dur="1s" begin="ghost.click"/>
  </rect>
</svg>
''';

      final report = analyzer.analyze(svg);

      expect(report.missingEventTargets, contains('ghost'));
      expect(
        report.issues.any((issue) => issue.code == 'event.missing_target'),
        isTrue,
      );
    });
  });
}
