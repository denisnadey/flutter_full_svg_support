import 'package:flutter_svg/src/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/playground/playground_models.dart';

void main() {
  group('PlaygroundModels', () {
    test('PlaygroundReport roundtrip via json', () {
      const issue = PlaygroundIssue(
        code: 'parse.missing_viewbox',
        severity: PlaygroundIssueSeverity.warning,
        category: 'parse',
        title: 'viewBox is missing',
        details: 'Add viewBox for predictable scaling.',
      );

      final original = PlaygroundReport(
        parseSuccess: true,
        canRender: true,
        parseError: null,
        parseTimeMs: 12,
        rootTag: 'svg',
        hasViewBox: false,
        hasAnimationMarkers: true,
        animationCount: 1,
        eventConditionCount: 2,
        missingEventTargets: const <String>{'targetX'},
        usedTags: const <String>{'svg', 'rect'},
        unsupportedTags: const <String>{'text'},
        unsupportedFilterPrimitives: const <String>{'feBlend'},
        brokenReferences: const <String>{'rect|fill|missing'},
        issues: const <PlaygroundIssue>[issue],
      );

      final parsed = PlaygroundReport.fromJson(original.toJson());

      expect(parsed.parseSuccess, isTrue);
      expect(parsed.rootTag, 'svg');
      expect(parsed.missingEventTargets, contains('targetX'));
      expect(parsed.unsupportedTags, contains('text'));
      expect(parsed.issues, hasLength(1));
      expect(parsed.issues.first.code, 'parse.missing_viewbox');
    });

    test('PlaygroundLogEntry parses level and payload from json', () {
      final parsed = PlaygroundLogEntry.fromJson(<String, Object?>{
        'timestamp': '2026-02-21T10:00:00.000Z',
        'level': 'warning',
        'category': 'run',
        'message': 'Something happened',
        'data': <String, Object?>{'a': 1, 'b': 'x'},
        'error': null,
        'stackTrace': null,
      });

      expect(parsed.level, SvgTraceLevel.warning);
      expect(parsed.category, 'run');
      expect(parsed.data['a'], 1);
      expect(parsed.data['b'], 'x');
    });
  });
}
