import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/smil/timing_condition.dart';
import 'package:full_svg_flutter/src/animation/smil/timing_parser.dart';

void main() {
  group('TimingParser', () {
    group('Offset parsing', () {
      test('parses simple seconds', () {
        final conditions = TimingParser.parse('2s');

        expect(conditions.length, 1);
        expect(conditions[0], isA<OffsetCondition>());
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset, const Duration(seconds: 2));
      });

      test('parses milliseconds', () {
        final conditions = TimingParser.parse('500ms');

        expect(conditions.length, 1);
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset, const Duration(milliseconds: 500));
      });

      test('parses fractional seconds', () {
        final conditions = TimingParser.parse('2.5s');

        expect(conditions.length, 1);
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset.inMilliseconds, 2500);
      });

      test('parses minutes', () {
        final conditions = TimingParser.parse('1min');

        expect(conditions.length, 1);
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset, const Duration(minutes: 1));
      });

      test('parses hours', () {
        final conditions = TimingParser.parse('2h');

        expect(conditions.length, 1);
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset, const Duration(hours: 2));
      });

      test('parses zero offset', () {
        final conditions = TimingParser.parse('0s');

        expect(conditions.length, 1);
        final offset = conditions[0] as OffsetCondition;
        expect(offset.offset, Duration.zero);
      });
    });

    group('Syncbase parsing', () {
      test('parses simple begin syncbase', () {
        final conditions = TimingParser.parse('anim1.begin');

        expect(conditions.length, 1);
        expect(conditions[0], isA<SyncbaseCondition>());
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.animationId, 'anim1');
        expect(syncbase.type, SyncbaseType.begin);
        expect(syncbase.offset, Duration.zero);
        expect(syncbase.repeatIndex, isNull);
      });

      test('parses simple end syncbase', () {
        final conditions = TimingParser.parse('anim1.end');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.animationId, 'anim1');
        expect(syncbase.type, SyncbaseType.end);
      });

      test('parses syncbase with positive offset', () {
        final conditions = TimingParser.parse('anim1.end+2s');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.animationId, 'anim1');
        expect(syncbase.type, SyncbaseType.end);
        expect(syncbase.offset, const Duration(seconds: 2));
      });

      test('parses syncbase with negative offset', () {
        final conditions = TimingParser.parse('anim1.begin-500ms');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.offset, const Duration(milliseconds: -500));
      });

      test('parses repeat syncbase without index', () {
        final conditions = TimingParser.parse('anim1.repeat');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.type, SyncbaseType.repeat);
        expect(syncbase.repeatIndex, isNull);
      });

      test('parses repeat syncbase with index', () {
        final conditions = TimingParser.parse('anim1.repeat(2)');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.type, SyncbaseType.repeat);
        expect(syncbase.repeatIndex, 2);
      });

      test('parses repeat with offset', () {
        final conditions = TimingParser.parse('anim1.repeat(3)+1s');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.type, SyncbaseType.repeat);
        expect(syncbase.repeatIndex, 3);
        expect(syncbase.offset, const Duration(seconds: 1));
      });

      test('handles IDs with dashes and underscores', () {
        final conditions = TimingParser.parse('my-anim_1.begin');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.animationId, 'my-anim_1');
      });
    });

    group('Event parsing', () {
      test('parses simple click event', () {
        final conditions = TimingParser.parse('click');

        expect(conditions.length, 1);
        expect(conditions[0], isA<EventCondition>());
        final event = conditions[0] as EventCondition;
        expect(event.eventType, 'click');
        expect(event.offset, Duration.zero);
      });

      test('parses event with offset', () {
        final conditions = TimingParser.parse('mouseover+1s');

        expect(conditions.length, 1);
        final event = conditions[0] as EventCondition;
        expect(event.eventType, 'mouseover');
        expect(event.offset, const Duration(seconds: 1));
      });

      test('parses various event types', () {
        final eventTypes = [
          'mousedown',
          'mouseup',
          'mousemove',
          'focusin',
          'focusout',
          'beginEvent',
          'endEvent',
          'repeatEvent',
        ];

        for (final eventType in eventTypes) {
          final conditions = TimingParser.parse(eventType);
          expect(conditions.length, 1);
          final event = conditions[0] as EventCondition;
          expect(event.eventType, eventType);
        }
      });
    });

    group('Indefinite parsing', () {
      test('parses indefinite', () {
        final conditions = TimingParser.parse('indefinite');

        expect(conditions.length, 1);
        expect(conditions[0], isA<IndefiniteCondition>());
      });
    });

    group('Multiple conditions', () {
      test('parses semicolon-separated list', () {
        final conditions = TimingParser.parse('2s; anim1.end+1s; click');

        expect(conditions.length, 3);
        expect(conditions[0], isA<OffsetCondition>());
        expect(conditions[1], isA<SyncbaseCondition>());
        expect(conditions[2], isA<EventCondition>());
      });

      test('handles extra whitespace', () {
        final conditions = TimingParser.parse('  2s  ;  anim1.begin  ');

        expect(conditions.length, 2);
        expect(conditions[0], isA<OffsetCondition>());
        expect(conditions[1], isA<SyncbaseCondition>());
      });

      test('handles trailing semicolons', () {
        final conditions = TimingParser.parse('2s;anim1.end;');

        expect(conditions.length, 2);
      });

      test('handles empty segments', () {
        final conditions = TimingParser.parse('2s;;anim1.end');

        expect(conditions.length, 2);
      });
    });

    group('Edge cases', () {
      test('returns empty list for empty string', () {
        final conditions = TimingParser.parse('');
        expect(conditions, isEmpty);
      });

      test('returns empty list for whitespace only', () {
        final conditions = TimingParser.parse('   ');
        expect(conditions, isEmpty);
      });

      test('handles invalid syncbase format', () {
        final conditions = TimingParser.parse('invalid.unknown');
        expect(conditions, isEmpty);
      });

      test('handles invalid time value', () {
        final conditions = TimingParser.parse('abcs');
        expect(conditions, isEmpty);
      });
    });

    group('Real-world examples', () {
      test('W3C example 1', () {
        // <animate begin="3s;5s;7s" ... />
        final conditions = TimingParser.parse('3s;5s;7s');

        expect(conditions.length, 3);
        expect((conditions[0] as OffsetCondition).offset.inSeconds, 3);
        expect((conditions[1] as OffsetCondition).offset.inSeconds, 5);
        expect((conditions[2] as OffsetCondition).offset.inSeconds, 7);
      });

      test('W3C example 2', () {
        // <animate begin="anim1.end+2s" ... />
        final conditions = TimingParser.parse('anim1.end+2s');

        expect(conditions.length, 1);
        final syncbase = conditions[0] as SyncbaseCondition;
        expect(syncbase.animationId, 'anim1');
        expect(syncbase.type, SyncbaseType.end);
        expect(syncbase.offset.inSeconds, 2);
      });

      test('W3C example 3', () {
        // <animate begin="click;anim1.repeat(2)" ... />
        final conditions = TimingParser.parse('click;anim1.repeat(2)');

        expect(conditions.length, 2);
        expect(conditions[0], isA<EventCondition>());
        final syncbase = conditions[1] as SyncbaseCondition;
        expect(syncbase.type, SyncbaseType.repeat);
        expect(syncbase.repeatIndex, 2);
      });
    });
  });

  group('TimingCondition', () {
    test('OffsetCondition equality', () {
      final cond1 = OffsetCondition(const Duration(seconds: 2));
      final cond2 = OffsetCondition(const Duration(seconds: 2));
      final cond3 = OffsetCondition(const Duration(seconds: 3));

      expect(cond1, equals(cond2));
      expect(cond1, isNot(equals(cond3)));
    });

    test('SyncbaseCondition equality', () {
      final cond1 = SyncbaseCondition(
        animationId: 'anim1',
        type: SyncbaseType.begin,
      );
      final cond2 = SyncbaseCondition(
        animationId: 'anim1',
        type: SyncbaseType.begin,
      );
      final cond3 = SyncbaseCondition(
        animationId: 'anim2',
        type: SyncbaseType.begin,
      );

      expect(cond1, equals(cond2));
      expect(cond1, isNot(equals(cond3)));
    });

    test('OffsetCondition isMet', () {
      final cond = OffsetCondition(const Duration(seconds: 2));

      expect(cond.isMet(const Duration(seconds: 1)), isFalse);
      expect(cond.isMet(const Duration(seconds: 2)), isTrue);
      expect(cond.isMet(const Duration(seconds: 3)), isTrue);
    });

    test('OffsetCondition getResolvedTime', () {
      final cond = OffsetCondition(const Duration(seconds: 2));
      expect(cond.getResolvedTime(), const Duration(seconds: 2));
    });
  });
}
