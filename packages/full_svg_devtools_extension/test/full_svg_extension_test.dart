import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/full_svg_debug_protocol.dart';

import 'package:full_svg_devtools_extension/src/full_svg_extension.dart';
import 'package:full_svg_devtools_extension/src/full_svg_inspector_controller.dart';
import 'package:full_svg_devtools_extension/src/full_svg_transport.dart';

void main() {
  testWidgets('shows a loading state while connecting', (tester) async {
    final transport = _FakeTransport(connected: true);
    final controller = FullSvgInspectorController(
      transport: transport,
      enablePolling: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));
    expect(find.text('Connecting to FullSVG runtime…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows disconnected state without a VM connection', (
    tester,
  ) async {
    final transport = _FakeTransport(connected: false);
    final controller = FullSvgInspectorController(
      transport: transport,
      enablePolling: false,
    );
    addTearDown(controller.dispose);
    await controller.start();

    await tester.pumpWidget(_testApp(controller));
    expect(find.text('No Flutter application connected.'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('shows an intentional empty state', (tester) async {
    final transport = _FakeTransport(connected: true, hasInstances: false);
    final controller = FullSvgInspectorController(
      transport: transport,
      enablePolling: false,
    );
    addTearDown(controller.dispose);
    await controller.start();

    await tester.pumpWidget(_testApp(controller));
    expect(find.text('No mounted FullSVG instances.'), findsOneWidget);
    expect(find.text('Refresh'), findsWidgets);
  });

  testWidgets(
    'renders instances, lazy DOM, properties, and playback controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transport = _FakeTransport(connected: true);
      final controller = FullSvgInspectorController(
        transport: transport,
        enablePolling: false,
      );
      addTearDown(controller.dispose);
      await controller.start();

      await tester.pumpWidget(_testApp(controller));
      expect(find.text('assets/hero.svg'), findsWidgets);
      expect(find.text('Animated • 3 nodes'), findsOneWidget);
      expect(find.text('svg#scene'), findsOneWidget);
      expect(find.text('Runtime ID'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);

      await tester.tap(find.byTooltip('Load children'));
      await tester.pumpAndSettle();
      expect(find.text('path#shape.hero'), findsOneWidget);

      await tester.tap(find.text('path#shape.hero'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Debug node ID'), findsOneWidget);
      expect(find.text('fill'), findsOneWidget);
      expect(find.text('#ff0000'), findsOneWidget);
      expect(find.text('animate • opacity'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(transport.highlightCalls, 1);

      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(transport.playCalls, 1);

      await tester.tap(find.byTooltip('Clear selection highlight'));
      await tester.pumpAndSettle();
      expect(transport.clearHighlightCalls, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('shows unavailable state when the runtime bridge is absent', (
    tester,
  ) async {
    final transport = _FakeTransport(connected: true, bridgeAvailable: false);
    final controller = FullSvgInspectorController(
      transport: transport,
      enablePolling: false,
    );
    addTearDown(controller.dispose);
    await controller.start();

    await tester.pumpWidget(_testApp(controller));
    expect(find.text('FullSVG debugging is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a request error after the bridge is verified', (
    tester,
  ) async {
    final transport = _FakeTransport(connected: true, requestError: true);
    final controller = FullSvgInspectorController(
      transport: transport,
      enablePolling: false,
    );
    addTearDown(controller.dispose);
    await controller.start();

    await tester.pumpWidget(_testApp(controller));
    expect(find.text('Could not load the FullSVG inspector.'), findsOneWidget);
    expect(find.textContaining('Synthetic request failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _testApp(FullSvgInspectorController controller) {
  return MaterialApp(home: FullSvgInspectorView(controller: controller));
}

class _FakeTransport extends ChangeNotifier implements FullSvgTransport {
  _FakeTransport({
    required bool connected,
    this.hasInstances = true,
    this.bridgeAvailable = true,
    this.requestError = false,
  }) : _connected = connected;

  bool _connected;
  final bool hasInstances;
  final bool bridgeAvailable;
  final bool requestError;
  int highlightCalls = 0;
  int clearHighlightCalls = 0;
  int playCalls = 0;

  @override
  bool get connected => _connected;

  void setConnected(bool value) {
    _connected = value;
    notifyListeners();
  }

  @override
  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> args = const <String, Object?>{},
  }) async {
    if (!connected) {
      throw const FullSvgTransportException('Disconnected');
    }
    if (!bridgeAvailable) {
      throw const FullSvgTransportException('Method not found');
    }
    if (requestError && method != FullSvgDebugProtocol.getProtocolVersion) {
      throw const FullSvgTransportException('Synthetic request failure');
    }
    switch (method) {
      case FullSvgDebugProtocol.getProtocolVersion:
        return fullSvgDebugSuccess();
      case FullSvgDebugProtocol.getInstances:
        return fullSvgDebugSuccess(<String, Object?>{
          'instances': hasInstances
              ? <Map<String, Object?>>[_instance().toJson()]
              : <Map<String, Object?>>[],
        });
      case FullSvgDebugProtocol.getInstance:
        return fullSvgDebugSuccess(<String, Object?>{
          'instance': _instance(playing: playCalls > 0).toJson(),
          'root': _root.toJson(),
        });
      case FullSvgDebugProtocol.getTree:
        return fullSvgDebugSuccess(<String, Object?>{
          'parentNodeId': args['nodeId'],
          'nodes': <Map<String, Object?>>[_path.toJson()],
        });
      case FullSvgDebugProtocol.getNode:
        return fullSvgDebugSuccess(<String, Object?>{
          'node': SvgDebugNodeDetails(
            summary: _path,
            attributes: const <SvgDebugAttribute>[
              SvgDebugAttribute(
                name: 'fill',
                rawValue: '#ff0000',
                resolvedValue: '#ff0000',
                animated: false,
              ),
            ],
            animations: const <SvgDebugAnimationDescriptor>[
              SvgDebugAnimationDescriptor(
                type: 'animate',
                attributeName: 'opacity',
                durationMs: 2000,
                beginMs: 0,
                repeatCount: 'indefinite',
                active: true,
              ),
            ],
          ).toJson(),
        });
      case FullSvgDebugProtocol.getStats:
        return fullSvgDebugSuccess(<String, Object?>{
          'stats': const SvgDebugStats(
            domNodes: 3,
            animationCount: 1,
            activeAnimationCount: 1,
            filterPrimitiveCount: 0,
            maskCount: 0,
            gradientCount: 0,
            clipPathCount: 0,
            javaScriptEnabled: false,
            currentTimeMs: 420,
            durationMs: 2000,
          ).toJson(),
        });
      case FullSvgDebugProtocol.highlightNode:
        highlightCalls++;
        return fullSvgDebugSuccess();
      case FullSvgDebugProtocol.clearHighlight:
        clearHighlightCalls++;
        return fullSvgDebugSuccess();
      case FullSvgDebugProtocol.play:
        playCalls++;
        return fullSvgDebugSuccess();
      case FullSvgDebugProtocol.pause:
      case FullSvgDebugProtocol.seek:
      case FullSvgDebugProtocol.setPlaybackRate:
        return fullSvgDebugSuccess();
    }
    throw FullSvgTransportException('Unexpected method $method');
  }

  SvgDebugInstanceSummary _instance({bool playing = false}) {
    return SvgDebugInstanceSummary(
      instanceId: 'svg-1',
      sourceType: 'asset',
      sourceLabel: 'assets/hero.svg',
      width: 200,
      height: 120,
      animated: true,
      playing: playing,
      currentTimeMs: 420,
      durationMs: 2000,
      playbackRate: 1,
      nodeCount: 3,
      animationCount: 1,
      hasJavaScript: false,
      hasFilters: false,
      hasMasks: false,
      hasClipPaths: false,
    );
  }

  static const _root = SvgDebugNodeSummary(
    nodeId: 'n1',
    tagName: 'svg',
    svgId: 'scene',
    classes: <String>[],
    childCount: 1,
    animated: true,
  );

  static const _path = SvgDebugNodeSummary(
    nodeId: 'n2',
    tagName: 'path',
    svgId: 'shape',
    classes: <String>['hero'],
    childCount: 0,
    animated: true,
  );
}
