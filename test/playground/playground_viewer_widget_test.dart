import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/pages/custom_svg_viewer_page.dart';

void main() {
  group('CustomSvgViewerPage', () {
    Future<void> pumpViewer(WidgetTester tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.setSurfaceSize(const Size(1600, 1800));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: CustomSvgViewerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('filters trace logs by search query', (
      WidgetTester tester,
    ) async {
      await pumpViewer(tester);

      expect(find.text('Playback started in forward mode'), findsOneWidget);
      expect(find.text('Animation controller created'), findsOneWidget);

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search logs...',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'playback');
      await tester.pump();

      expect(find.text('Playback started in forward mode'), findsOneWidget);
      expect(find.text('Animation controller created'), findsNothing);
    });

    testWidgets('changes problems grouping mode in diagnostics tab', (
      WidgetTester tester,
    ) async {
      await pumpViewer(tester);

      final importedPayload = <String, Object?>{
        'runId': 41,
        'svgSource': '<svg viewBox="0 0 10 10"></svg>',
        'report': <String, Object?>{
          'diagnosticVersion': 'v1',
          'parseSuccess': true,
          'canRender': true,
          'parseError': null,
          'parseTimeMs': 3,
          'rootTag': 'svg',
          'hasViewBox': true,
          'hasAnimationMarkers': false,
          'animationCount': 0,
          'eventConditionCount': 0,
          'missingEventTargets': const <String>[],
          'usedTags': const <String>['svg'],
          'unsupportedTags': const <String>['switch'],
          'unsupportedFilterPrimitives': const <String>[],
          'brokenReferences': const <String>['shape|fill|missingGradient'],
          'issues': <Map<String, Object?>>[
            const <String, Object?>{
              'code': 'parse.missing_viewbox',
              'severity': 'warning',
              'category': 'parse',
              'title': 'viewBox is missing',
              'details':
                  'Scaling and hit-testing are more predictable with viewBox.',
            },
            const <String, Object?>{
              'code': 'parity.unsupported_tag',
              'severity': 'warning',
              'category': 'parity',
              'title': 'Tag is outside current animated-pipeline support',
              'details': '<switch> is not fully supported in this pipeline.',
            },
            const <String, Object?>{
              'code': 'refs.missing_target',
              'severity': 'error',
              'category': 'reference',
              'title': 'Broken reference',
              'details': 'fill points to missing id \"missingGradient\".',
            },
          ],
        },
        'runtimeIssues': const <Object?>[],
        'traceLogs': const <Object?>[],
      };
      final encodedPayload = jsonEncode(importedPayload);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        methodCall,
      ) async {
        switch (methodCall.method) {
          case 'Clipboard.getData':
            return <String, Object?>{'text': encodedPayload};
          case 'Clipboard.setData':
            return null;
          default:
            return null;
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.tap(find.byTooltip('Import report JSON from clipboard'));
      await tester.pump(const Duration(milliseconds: 500));

      final diagnosticsTabBarFinder = find.byWidgetPredicate((widget) {
        if (widget is! TabBar) {
          return false;
        }
        return widget.tabs.any((tab) => tab is Tab && tab.text == 'Trace Logs');
      });
      expect(diagnosticsTabBarFinder, findsOneWidget);
      final diagnosticsTabBar = tester.widget<TabBar>(diagnosticsTabBarFinder);
      diagnosticsTabBar.controller!.animateTo(
        1,
        duration: Duration.zero,
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Groups: '), findsOneWidget);
      dynamic groupingDropdown() {
        final candidates = find
            .byWidgetPredicate((widget) => widget is DropdownButton)
            .evaluate();
        for (final element in candidates) {
          final dropdown = element.widget as dynamic;
          final items = dropdown.items as List<dynamic>?;
          if (items == null ||
              !items.any(
                (item) =>
                    item.child is Text && (item.child as Text).data == 'none',
              )) {
            continue;
          }
          final renderObject = element.renderObject;
          if (renderObject is RenderBox &&
              renderObject.hasSize &&
              renderObject.size.width > 0 &&
              renderObject.size.height > 0) {
            return dropdown;
          }
        }
        throw StateError('Visible grouping dropdown not found');
      }

      dynamic groupingValue(String label) {
        final items = (groupingDropdown() as dynamic).items as List<dynamic>;
        final item = items.firstWhere(
          (entry) => entry.child is Text && (entry.child as Text).data == label,
        );
        return item.value;
      }

      expect(find.text('Groups: 3'), findsOneWidget);
      expect(find.textContaining('parity.unsupported_tag ('), findsOneWidget);
      expect(find.textContaining('parse.missing_viewbox ('), findsOneWidget);
      expect(find.textContaining('refs.missing_target ('), findsOneWidget);
      expect(groupingValue('none'), isNotNull);
      expect(groupingValue('code'), isNotNull);
      expect(groupingValue('category'), isNotNull);
    });
  });
}
