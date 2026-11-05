// The web stub is plain Dart, so its contract can be checked on the VM even
// though `dart_test.yaml` restricts the suite to `test_on: vm`.
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_js_bridge_platform.dart'
    as selected;
import 'package:full_svg_flutter/src/animation/svg_js_bridge_web.dart' as web;
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  test('native builds select the QuickJS bridge', () {
    expect(selected.svgJsBridgeSupported, isTrue);
  });

  group('web stub', () {
    const svg = '''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
        <rect id="r" width="10" height="10" fill="red"/>
        <script>document.getElementById('r').setAttribute('fill', 'green');</script>
      </svg>
    ''';

    test('reports scripts as unsupported', () {
      expect(web.svgJsBridgeSupported, isFalse);
    });

    test('never runs scripts and settles immediately', () async {
      final doc = SvgParser.parse(svg);
      expect(doc.scripts, isNotEmpty);
      String fill() =>
          doc.getElementById('r')!.getAttributeValue('fill').toString();
      final fillBefore = fill();
      var repaints = 0;
      var handlers = 0;
      final bridge = web.SvgJsBridge(
        document: doc,
        markNeedsRepaint: () => repaints++,
        addEventHandler: (_, _, _) => handlers++,
      );

      for (final script in doc.scripts!) {
        bridge.executeScript(script);
      }
      bridge
        ..onInlinesDone()
        ..fireLoadEvents()
        ..dispatchInlineHandler('r', "this.setAttribute('fill','blue')");

      await expectLater(bridge.externalScriptsLoaded, completes);
      expect(bridge.evaluateForDebug('1 + 1'), isNull);
      expect(fill(), fillBefore);
      expect(repaints, 0);
      expect(handlers, 0);
      bridge.dispose();
    });
  });
}
