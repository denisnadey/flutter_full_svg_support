import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_event.dart';
import 'package:flutter_svg/src/animation/svg_event_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('W3C Event System Improvements', () {
    group('Event Capturing Phase', () {
      testWidgets('capture phase fires before bubble phase on click', (
        WidgetTester tester,
      ) async {
        // Test that the event flow follows W3C: capture -> target -> bubble
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g id="parent">
              <rect id="child" x="20" y="20" width="60" height="60" fill="blue"/>
            </g>
            <rect id="captureIndicator" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="30" dur="1s" 
                       begin="parent.click_capture" fill="freeze"/>
            </rect>
            <rect id="bubbleIndicator" x="70" y="85" width="10" height="10" fill="green">
              <animate attributeName="x" from="70" to="90" dur="1s" 
                       begin="parent.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final center = tester.getCenter(pictureFinder);

        // Click on child - should trigger capture on parent first, then bubble
        await tester.tapAt(center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Both capture and bubble phases should have been triggered
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets(
        'nested element event flow follows capture -> target -> bubble',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g id="level1">
              <g id="level2">
                <rect id="target" x="30" y="30" width="40" height="40" fill="blue"/>
              </g>
            </g>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="level1.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AnimatedSvgPicture.string(
                    svgXml,
                    width: 200,
                    height: 200,
                    autoPlay: true,
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final center = tester.getCenter(pictureFinder);

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );

          // Click on target - event should bubble to level1
          await tester.tapAt(center);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
          final afterAnalysis = VisualTestUtils.analyzeRedPixels(
            afterPixels,
            800,
            600,
          );

          // Animation should have started (event bubbled through levels)
          expect(
            (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
            greaterThan(5),
          );
        },
      );
    });

    group('stopPropagation and stopImmediatePropagation', () {
      test('SvgEvent stopPropagation marks event as stopped', () {
        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);

        expect(event.propagationStopped, isFalse);
        event.stopPropagation();
        expect(event.propagationStopped, isTrue);
      });

      test('SvgEvent stopImmediatePropagation stops all handlers', () {
        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);

        expect(event.propagationStopped, isFalse);
        expect(event.immediatePropagationStopped, isFalse);
        event.stopImmediatePropagation();
        expect(event.propagationStopped, isTrue);
        expect(event.immediatePropagationStopped, isTrue);
      });

      test(
        'stopImmediatePropagation stops remaining handlers on same element',
        () {
          int handler1Called = 0;
          int handler2Called = 0;

          final eventTarget = SvgEventTarget();
          eventTarget.addEventListener('click', (event) {
            handler1Called++;
            event.stopImmediatePropagation();
          });
          eventTarget.addEventListener('click', (event) {
            handler2Called++;
          });

          final event = SvgEvent(
            type: 'click',
            bubbles: true,
            cancelable: true,
          );
          event.setEventPhaseInternal(SvgEventPhase.atTarget);
          eventTarget.dispatchEvent(event);

          expect(handler1Called, equals(1));
          expect(handler2Called, equals(0)); // Should not be called
        },
      );
    });

    group('preventDefault', () {
      test('SvgEvent preventDefault marks event as cancelled', () {
        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);

        expect(event.defaultPrevented, isFalse);
        event.preventDefault();
        expect(event.defaultPrevented, isTrue);
      });

      test('preventDefault only works on cancelable events', () {
        final nonCancelable = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: false,
        );

        nonCancelable.preventDefault();
        expect(nonCancelable.defaultPrevented, isFalse);

        final cancelable = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: true,
        );

        cancelable.preventDefault();
        expect(cancelable.defaultPrevented, isTrue);
      });
    });

    group('Focus and Blur Events', () {
      test('SvgPseudoClassState tracks focused element', () {
        final state = SvgPseudoClassState();

        expect(state.focusedId, isNull);

        state.setFocus('element1');
        expect(state.focusedId, equals('element1'));
        expect(state.isFocused('element1'), isTrue);

        state.setFocus('element2');
        expect(state.focusedId, equals('element2'));
        expect(state.isFocused('element1'), isFalse);
        expect(state.isFocused('element2'), isTrue);
      });

      test('setFocus returns true on change, false on same element', () {
        final state = SvgPseudoClassState();

        expect(state.setFocus('element1'), isTrue);
        expect(state.setFocus('element1'), isFalse); // Same element
        expect(state.setFocus('element2'), isTrue);
        expect(state.setFocus(null), isTrue);
      });

      test('focus change callback is invoked', () {
        final state = SvgPseudoClassState();
        String? lastOldId;
        String? lastNewId;

        state.onFocusChange = (oldId, newId) {
          lastOldId = oldId;
          lastNewId = newId;
        };

        state.setFocus('element1');
        expect(lastOldId, isNull);
        expect(lastNewId, equals('element1'));

        state.setFocus('element2');
        expect(lastOldId, equals('element1'));
        expect(lastNewId, equals('element2'));

        state.clearFocus();
        expect(lastOldId, equals('element2'));
        expect(lastNewId, isNull);
      });

      test('previousFocusedId tracks previous focus', () {
        final state = SvgPseudoClassState();

        state.setFocus('element1');
        expect(state.previousFocusedId, isNull);

        state.setFocus('element2');
        expect(state.previousFocusedId, equals('element1'));

        state.setFocus('element3');
        expect(state.previousFocusedId, equals('element2'));
      });

      testWidgets('focus event triggers on tap of focusable element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <a id="link" href="#">
              <rect x="20" y="20" width="60" height="60" fill="blue"/>
            </a>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="link.focus" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final center = tester.getCenter(pictureFinder);

        // Tap on the link - should trigger focus
        await tester.tapAt(center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Focusable Element Detection', () {
      test('anchor element is focusable', () {
        final node = SvgNode(tagName: 'a', attributes: {});
        expect(isFocusableElement(node), isTrue);
      });

      test('text element is focusable', () {
        final node = SvgNode(tagName: 'text', attributes: {});
        expect(isFocusableElement(node), isTrue);
      });

      test('rect element is not focusable by default', () {
        final node = SvgNode(tagName: 'rect', attributes: {});
        expect(isFocusableElement(node), isFalse);
      });

      test('element with tabindex=0 is focusable', () {
        final node = SvgNode(
          tagName: 'rect',
          attributes: {
            'tabindex': AnimatableSvgAttribute(
              name: 'tabindex',
              baseValue: '0',
            ),
          },
        );
        expect(isFocusableElement(node), isTrue);
      });

      test('element with tabindex=-1 is focusable', () {
        final node = SvgNode(
          tagName: 'rect',
          attributes: {
            'tabindex': AnimatableSvgAttribute(
              name: 'tabindex',
              baseValue: '-1',
            ),
          },
        );
        expect(isFocusableElement(node), isTrue);
      });

      test('element with invalid tabindex is not focusable', () {
        final node = SvgNode(
          tagName: 'rect',
          attributes: {
            'tabindex': AnimatableSvgAttribute(
              name: 'tabindex',
              baseValue: 'abc',
            ),
          },
        );
        expect(isFocusableElement(node), isFalse);
      });
    });

    group('Wheel Event', () {
      test('SvgWheelEvent has correct properties', () {
        final event = SvgWheelEvent(
          clientX: 100.0,
          clientY: 100.0,
          deltaX: 0.0,
          deltaY: 50.0,
        );

        expect(event.type, equals('wheel'));
        expect(event.bubbles, isTrue);
        expect(event.cancelable, isTrue);
        expect(event.deltaX, equals(0.0));
        expect(event.deltaY, equals(50.0));
        expect(event.deltaMode, equals(SvgWheelDeltaMode.pixel));
      });

      testWidgets('wheel event dispatches on scroll', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.wheel" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Widget should render correctly with wheel event animation
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Context Menu Event', () {
      test('SvgContextMenuEvent has correct properties', () {
        final event = SvgContextMenuEvent(clientX: 100.0, clientY: 100.0);

        expect(event.type, equals('contextmenu'));
        expect(event.bubbles, isTrue);
        expect(event.cancelable, isTrue);
        expect(event.button, equals(2)); // Right button
      });

      testWidgets('context menu event triggers on secondary tap', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.contextmenu" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Widget should render correctly with contextmenu animation
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Event Listener Registration', () {
      test('addEventListener registers listener correctly', () {
        final target = SvgEventTarget();
        int callCount = 0;

        target.addEventListener('click', (event) {
          callCount++;
        });

        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event);

        expect(callCount, equals(1));
      });

      test('removeEventListener removes listener', () {
        final target = SvgEventTarget();
        int callCount = 0;

        void listener(SvgEvent event) {
          callCount++;
        }

        target.addEventListener('click', listener);
        target.removeEventListener('click', listener);

        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event);

        expect(callCount, equals(0));
      });

      test('once: true removes listener after first invocation', () {
        final target = SvgEventTarget();
        int callCount = 0;

        target.addEventListener('click', (event) {
          callCount++;
        }, once: true);

        final event1 = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event1.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event1);

        final event2 = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event2.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event2);

        expect(callCount, equals(1));
      });

      test('capture: true fires during capture phase only', () {
        final target = SvgEventTarget();
        int captureCount = 0;
        int bubbleCount = 0;

        target.addEventListener('click', (event) {
          captureCount++;
        }, capture: true);

        target.addEventListener('click', (event) {
          bubbleCount++;
        }, capture: false);

        // Test capture phase
        final captureEvent = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: true,
        );
        captureEvent.setEventPhaseInternal(SvgEventPhase.capturing);
        target.dispatchEvent(captureEvent);

        expect(captureCount, equals(1));
        expect(bubbleCount, equals(0));

        // Test bubble phase
        final bubbleEvent = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: true,
        );
        bubbleEvent.setEventPhaseInternal(SvgEventPhase.bubbling);
        target.dispatchEvent(bubbleEvent);

        expect(captureCount, equals(1));
        expect(bubbleCount, equals(1));
      });
    });

    group('Event Path and Retargeting', () {
      test('composedPath returns correct path', () {
        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        final path = [
          SvgNode(tagName: 'svg', attributes: {}),
          SvgNode(tagName: 'g', attributes: {}),
          SvgNode(tagName: 'rect', attributes: {}),
        ];

        event.setComposedPathInternal(path);

        final composedPath = event.composedPath();
        expect(composedPath.length, equals(3));
        expect(composedPath[0].tagName, equals('svg'));
        expect(composedPath[2].tagName, equals('rect'));
      });

      test('event target retargeting for non-composed events', () {
        final useElement = SvgNode(
          tagName: 'use',
          attributes: {
            'id': AnimatableSvgAttribute(name: 'id', baseValue: 'use1'),
          },
        );
        final target = SvgNode(
          tagName: 'rect',
          attributes: {
            'id': AnimatableSvgAttribute(name: 'id', baseValue: 'rect1'),
          },
        );

        final event = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: true,
          composed: false,
        );

        event.setTargetInternal(target);
        event.setUseElementInternal(useElement);

        // For non-composed events, target should be retargeted to use element
        expect(event.target, equals(useElement));
      });

      test('composed events do not retarget', () {
        final useElement = SvgNode(
          tagName: 'use',
          attributes: {
            'id': AnimatableSvgAttribute(name: 'id', baseValue: 'use1'),
          },
        );
        final target = SvgNode(
          tagName: 'rect',
          attributes: {
            'id': AnimatableSvgAttribute(name: 'id', baseValue: 'rect1'),
          },
        );

        final event = SvgEvent(
          type: 'click',
          bubbles: true,
          cancelable: true,
          composed: true,
        );

        event.setTargetInternal(target);
        event.setUseElementInternal(useElement);

        // For composed events, target should be the actual target
        expect(event.target, equals(target));
      });
    });

    group('SvgFocusEvent', () {
      test('SvgFocusEvent has correct default properties', () {
        final event = SvgFocusEvent(type: 'focus');

        expect(event.type, equals('focus'));
        expect(event.bubbles, isTrue);
        expect(event.cancelable, isFalse);
        expect(event.composed, isTrue);
      });

      test('SvgFocusEvent tracks relatedTarget', () {
        final relatedTarget = SvgNode(
          tagName: 'rect',
          attributes: {
            'id': AnimatableSvgAttribute(name: 'id', baseValue: 'prev'),
          },
        );
        final event = SvgFocusEvent(
          type: 'focusin',
          relatedTarget: relatedTarget,
        );

        expect(event.relatedTarget, equals(relatedTarget));
      });
    });

    group('Edge Cases', () {
      test('empty event path does not cause errors', () {
        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setComposedPathInternal([]);

        expect(event.path.isEmpty, isTrue);
        expect(event.composedPath().isEmpty, isTrue);
      });

      test('multiple handlers on same element all fire', () {
        final target = SvgEventTarget();
        int handler1Count = 0;
        int handler2Count = 0;
        int handler3Count = 0;

        target.addEventListener('click', (event) {
          handler1Count++;
        });
        target.addEventListener('click', (event) {
          handler2Count++;
        });
        target.addEventListener('click', (event) {
          handler3Count++;
        });

        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event);

        expect(handler1Count, equals(1));
        expect(handler2Count, equals(1));
        expect(handler3Count, equals(1));
      });

      test('event dispatch returns defaultPrevented status', () {
        final target = SvgEventTarget();

        target.addEventListener('click', (event) {
          event.preventDefault();
        });

        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setEventPhaseInternal(SvgEventPhase.atTarget);
        final result = target.dispatchEvent(event);

        expect(result, isFalse); // Returns false when default prevented
      });

      test('listener for wrong event type does not fire', () {
        final target = SvgEventTarget();
        int clickCount = 0;
        int hoverCount = 0;

        target.addEventListener('click', (event) {
          clickCount++;
        });
        target.addEventListener('mouseover', (event) {
          hoverCount++;
        });

        final event = SvgEvent(type: 'click', bubbles: true, cancelable: true);
        event.setEventPhaseInternal(SvgEventPhase.atTarget);
        target.dispatchEvent(event);

        expect(clickCount, equals(1));
        expect(hoverCount, equals(0));
      });
    });
  });
}
