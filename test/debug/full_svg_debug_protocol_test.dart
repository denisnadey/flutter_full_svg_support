import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/debug/full_svg_debug_protocol.dart';
import 'package:full_svg_flutter/src/debug/full_svg_debug_registry.dart';

void main() {
  group('FullSVG debug protocol', () {
    test('round-trips instance summaries', () {
      const summary = SvgDebugInstanceSummary(
        instanceId: 'svg-7',
        sourceType: 'asset',
        sourceLabel: 'assets/hero.svg',
        width: 120,
        height: 80,
        animated: true,
        playing: false,
        currentTimeMs: 420,
        durationMs: 2000,
        playbackRate: 1.5,
        nodeCount: 14,
        animationCount: 2,
        hasJavaScript: false,
        hasFilters: true,
        hasMasks: false,
        hasClipPaths: true,
      );

      expect(
        SvgDebugInstanceSummary.fromJson(summary.toJson()).toJson(),
        summary.toJson(),
      );
    });

    test('returns structured errors for malformed and stale requests', () {
      final registry = FullSvgDebugRegistry.instance;
      registry.debugResetForTesting();
      final service = FullSvgDebugService(registry);

      final missingParameter = service.handle(
        FullSvgDebugProtocol.getInstance,
        const <String, String>{},
      );
      expect(missingParameter['ok'], isFalse);
      expect(
        (missingParameter['error']! as Map<String, Object?>)['code'],
        FullSvgDebugErrorCode.invalidParameter,
      );

      final stale = service.handle(
        FullSvgDebugProtocol.getInstance,
        const <String, String>{'instanceId': 'svg-404'},
      );
      expect(stale['ok'], isFalse);
      expect(
        (stale['error']! as Map<String, Object?>)['code'],
        FullSvgDebugErrorCode.instanceNotFound,
      );
    });

    test('validates numeric command parameters before dispatch', () {
      final registry = FullSvgDebugRegistry.instance;
      registry.debugResetForTesting();
      final inspectable = _FakeInspectable();
      final id = registry.register(inspectable);
      final service = FullSvgDebugService(registry);

      final invalidSeek = service.handle(
        FullSvgDebugProtocol.seek,
        <String, String>{'instanceId': id, 'positionMs': 'NaN'},
      );
      expect(
        (invalidSeek['error']! as Map<String, Object?>)['code'],
        FullSvgDebugErrorCode.invalidParameter,
      );

      final invalidRate = service.handle(
        FullSvgDebugProtocol.setPlaybackRate,
        <String, String>{'instanceId': id, 'rate': '0'},
      );
      expect(
        (invalidRate['error']! as Map<String, Object?>)['code'],
        FullSvgDebugErrorCode.invalidParameter,
      );
      expect(inspectable.seekCalls, 0);
      expect(inspectable.rateCalls, 0);
    });
  });
}

class _FakeInspectable implements FullSvgDebugInspectable {
  @override
  String debugInstanceId = '';

  int seekCalls = 0;
  int rateCalls = 0;

  @override
  bool get debugCanAnimate => true;

  @override
  SvgDebugNodeSummary get debugRootNode => const SvgDebugNodeSummary(
    nodeId: 'n1',
    tagName: 'svg',
    svgId: null,
    classes: <String>[],
    childCount: 0,
    animated: false,
  );

  @override
  void debugClearHighlight() {}

  @override
  bool debugHighlightNode(String nodeId) => nodeId == 'n1';

  @override
  void debugPause() {}

  @override
  void debugPlay() {}

  @override
  void debugSeek(Duration position) => seekCalls++;

  @override
  void debugSetPlaybackRate(double rate) => rateCalls++;

  @override
  SvgDebugInstanceSummary createDebugSummary() => SvgDebugInstanceSummary(
    instanceId: debugInstanceId,
    sourceType: 'string',
    sourceLabel: 'Inline SVG',
    width: 10,
    height: 10,
    animated: true,
    playing: false,
    currentTimeMs: 0,
    durationMs: 1000,
    playbackRate: 1,
    nodeCount: 1,
    animationCount: 1,
    hasJavaScript: false,
    hasFilters: false,
    hasMasks: false,
    hasClipPaths: false,
  );

  @override
  SvgDebugStats createDebugStats() => const SvgDebugStats(
    domNodes: 1,
    animationCount: 1,
    activeAnimationCount: 0,
    filterPrimitiveCount: 0,
    maskCount: 0,
    gradientCount: 0,
    clipPathCount: 0,
    javaScriptEnabled: false,
    currentTimeMs: 0,
    durationMs: 1000,
  );

  @override
  List<SvgDebugNodeSummary>? getDebugChildren(String nodeId) =>
      nodeId == 'n1' ? const <SvgDebugNodeSummary>[] : null;

  @override
  SvgDebugNodeDetails? getDebugNode(String nodeId) => nodeId == 'n1'
      ? SvgDebugNodeDetails(
          summary: debugRootNode,
          attributes: const <SvgDebugAttribute>[],
          animations: const <SvgDebugAnimationDescriptor>[],
        )
      : null;
}
