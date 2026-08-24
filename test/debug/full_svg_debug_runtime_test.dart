import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:full_svg_flutter/src/debug/full_svg_debug_protocol.dart';
import 'package:full_svg_flutter/src/debug/full_svg_debug_registry.dart';

const _animatedSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="paint"><stop offset="0" stop-color="red"/></linearGradient></defs>
  <g id="hero" class="character featured">
    <path id="shape" fill="url(#paint)" d="M10 10 L90 10 L50 90 Z">
      <animate attributeName="opacity" from="0" to="1" dur="2s"/>
    </path>
  </g>
</svg>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FullSvgDebugRegistry.instance.debugResetForTesting();
  });

  testWidgets('tracks, lazily inspects, controls, and removes live instances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FSvgPicture.string(
          _animatedSvg,
          width: 100,
          height: 100,
          autoPlay: true,
        ),
      ),
    );
    await tester.pump();

    final service = FullSvgDebugService(FullSvgDebugRegistry.instance);
    final instances = service.handle(
      FullSvgDebugProtocol.getInstances,
      const <String, String>{},
    );
    final rows = (instances['instances']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(rows, hasLength(1));
    expect(rows.single['instanceId'], 'svg-1');
    expect(rows.single['nodeCount'], 7);
    expect(rows.single['animationCount'], 1);
    expect(rows.single['sourceLabel'], 'Inline SVG');

    final instance = service.handle(
      FullSvgDebugProtocol.getInstance,
      const <String, String>{'instanceId': 'svg-1'},
    );
    final root = instance['root']! as Map<String, Object?>;
    expect(root['nodeId'], 'n1');
    expect(root['tagName'], 'svg');

    final firstLevel = service.handle(
      FullSvgDebugProtocol.getTree,
      const <String, String>{'instanceId': 'svg-1', 'nodeId': 'n1'},
    );
    final firstLevelNodes = (firstLevel['nodes']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(firstLevelNodes.map((node) => node['tagName']), <String>[
      'defs',
      'g',
    ]);
    final groupNodeId = firstLevelNodes.last['nodeId']! as String;

    final groupChildren = service.handle(
      FullSvgDebugProtocol.getTree,
      <String, String>{'instanceId': 'svg-1', 'nodeId': groupNodeId},
    );
    final path = (groupChildren['nodes']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    final pathNodeId = path['nodeId']! as String;

    final details = service.handle(
      FullSvgDebugProtocol.getNode,
      <String, String>{'instanceId': 'svg-1', 'nodeId': pathNodeId},
    );
    final node = details['node']! as Map<String, Object?>;
    final attributes = (node['attributes']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(attributes.any((attribute) => attribute['name'] == 'd'), isTrue);
    expect((node['animations']! as List<Object?>), hasLength(1));

    expect(
      service.handle(FullSvgDebugProtocol.pause, const <String, String>{
        'instanceId': 'svg-1',
      })['ok'],
      isTrue,
    );
    final paused = service.handle(
      FullSvgDebugProtocol.getInstance,
      const <String, String>{'instanceId': 'svg-1'},
    );
    expect((paused['instance']! as Map<String, Object?>)['playing'], isFalse);

    expect(
      service.handle(FullSvgDebugProtocol.seek, const <String, String>{
        'instanceId': 'svg-1',
        'positionMs': '750',
      })['ok'],
      isTrue,
    );
    expect(
      service.handle(
        FullSvgDebugProtocol.setPlaybackRate,
        const <String, String>{'instanceId': 'svg-1', 'rate': '1.5'},
      )['ok'],
      isTrue,
    );
    expect(
      service.handle(FullSvgDebugProtocol.highlightNode, <String, String>{
        'instanceId': 'svg-1',
        'nodeId': pathNodeId,
      })['ok'],
      isTrue,
    );
    expect(
      service.handle(
        FullSvgDebugProtocol.clearHighlight,
        const <String, String>{'instanceId': 'svg-1'},
      )['ok'],
      isTrue,
    );
    expect(
      service.handle(FullSvgDebugProtocol.play, const <String, String>{
        'instanceId': 'svg-1',
      })['ok'],
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final afterDispose = service.handle(
      FullSvgDebugProtocol.getInstances,
      const <String, String>{},
    );
    expect(afterDispose['instances'], isEmpty);
  });

  testWidgets('assigns distinct stable IDs to identical mounted SVGs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: <Widget>[
            FSvgPicture.string(_animatedSvg, width: 50, height: 50),
            FSvgPicture.string(_animatedSvg, width: 50, height: 50),
          ],
        ),
      ),
    );
    await tester.pump();

    final ids = FullSvgDebugRegistry.instance.liveInstances
        .map((instance) => instance.debugInstanceId)
        .toList();
    expect(ids, <String>['svg-1', 'svg-2']);
  });
}
