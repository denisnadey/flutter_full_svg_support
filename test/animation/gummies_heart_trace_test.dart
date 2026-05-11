// ignore_for_file: avoid_print
/// Trace-diff: for the "Glowing Gummies" SVG, log every `sendMessage` the
/// JS runtime fires during `seekTo(1000)` (a known-good moment) vs
/// `seekTo(1559)` (the broken moment where the gummy heart's transform
/// collapses to `data.t` only). Diffing the two traces will pinpoint
/// which DOM call the player makes that returns wrong data in the broken
/// window — that is the API our bridge needs to fix.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _gummiesSvg() =>
    File('$_fixturesDir/glowing_gummies_full.svg').readAsStringSync();
String _svgatorPlayerJs() =>
    File('test/animation/_svgator_player_91c80d77.js').readAsStringSync();

String _svgWithTracer(int seekMs) {
  final svg = _gummiesSvg();
  // ── 1) install tracer FIRST (before bootstrap or player) ────────────────
  const tracerInstall = '''
<script><![CDATA[
  globalThis._trace = [];
  globalThis._tracerActive = true;
  var orig = globalThis.sendMessage;
  globalThis.sendMessage = function(name, args) {
    if (globalThis._tracerActive) {
      try { globalThis._trace.push(name + '|' + (args == null ? '' : String(args))); }
      catch(e) {}
    }
    return orig(name, args);
  };
]]></script>''';
  final playerScript =
      '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
  final seekProbe = '''
<script><![CDATA[
  globalThis._trace.push('--- SEEK_BOUNDARY ---');
  try {
    var roots = document.querySelectorAll('svg');
    for (var i = 0; i < roots.length; i++) {
      var p = roots[i].svgatorPlayer;
      if (p) {
        try { p.pause(); } catch(e) { globalThis._trace.push('ERR_pause|' + String(e)); }
        try { p.seekTo($seekMs); } catch(e) { globalThis._trace.push('ERR_seek|' + String(e)); }
      }
    }
  } catch(e) { globalThis._trace.push('ERR_outer|' + String(e)); }
]]></script>''';
  // Order: <svg>...defs/etc... bootstrap-script(inline) → tracer → player → seekProbe → </svg>
  // The original bootstrap script in the SVG is BEFORE </svg>, and we splice
  // tracer / player / seek immediately before </svg>. But the original
  // bootstrap actually runs at its native position in the document; since
  // the tracer install runs after the bootstrap script when injected here,
  // we will MISS calls the bootstrap makes. To capture those too, prepend
  // the tracer right after <svg>'s opening tag.
  final openEnd = svg.indexOf('>') + 1;
  final closeIdx = svg.lastIndexOf('</svg>');
  return svg.substring(0, openEnd) +
      tracerInstall +
      svg.substring(openEnd, closeIdx) +
      playerScript +
      seekProbe +
      svg.substring(closeIdx);
}

Future<List<String>> _capture(
  WidgetTester tester,
  AnimatedSvgController controller,
  int seekMs,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedSvgPicture.string(
          _svgWithTracer(seekMs),
          controller: controller,
          autoPlay: false,
          width: 700,
          height: 400,
        ),
      ),
    ),
  );
  await tester.pump();
  // Let the inline scripts execute.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
  final raw =
      controller.evaluateJsForDebug('JSON.stringify(globalThis._trace || [])');
  if (raw == null) return const [];
  try {
    return (jsonDecode(raw) as List).cast<String>();
  } catch (_) {
    return const [];
  }
}

/// Filter the trace down to only setAttribute / getAttribute calls for the
/// heart element `egCFBHozAYS3`. These are the most informative — anything
/// the player reads/writes on the buggy group will show up here.
List<String> _filterHeart(List<String> trace) => trace
    .where((line) =>
        (line.startsWith('setAttribute|') ||
         line.startsWith('getAttribute|') ||
         line.startsWith('getStyle|') ||
         line.startsWith('setStyle|') ||
         line.startsWith('getElementById|')) &&
        line.contains('egCFBHozAYS3'))
    .toList();

void _printTrace(String label, List<String> trace) {
  print('=== $label  (${trace.length} entries) ===');
  for (int i = 0; i < trace.length; i++) {
    final l = trace[i];
    // Truncate huge attribute values so the log stays readable.
    final clipped = l.length > 200 ? '${l.substring(0, 200)}…' : l;
    print('  $i: $clipped');
  }
}

void main() {
  testWidgets('TRACE DIFF: seekTo(1000) good vs seekTo(1559) bad',
      (tester) async {
    final c1 = AnimatedSvgController();
    final goodTrace = await _capture(tester, c1, 1000);
    await tester.pumpWidget(const SizedBox.shrink());
    c1.dispose();

    final c2 = AnimatedSvgController();
    final badTrace = await _capture(tester, c2, 1559);
    await tester.pumpWidget(const SizedBox.shrink());
    c2.dispose();

    print('\n--- GOOD trace (t=1000): ${goodTrace.length} sendMessage calls');
    print('--- BAD  trace (t=1559): ${badTrace.length} sendMessage calls');

    final goodHeart = _filterHeart(goodTrace);
    final badHeart = _filterHeart(badTrace);

    _printTrace('GOOD t=1000 — heart-only', goodHeart);
    _printTrace('BAD  t=1559 — heart-only', badHeart);

    // Also surface the final transform write for the heart in each trace.
    String? lastHeartTransform(List<String> tr) => tr.lastWhere(
          (l) => l.startsWith('setAttribute|') &&
              l.contains('egCFBHozAYS3') &&
              l.contains('"name":"transform"'),
          orElse: () => '(no transform write)',
        );

    print('\nGOOD t=1000 last heart transform: '
        '${lastHeartTransform(goodTrace)}');
    print('BAD  t=1559 last heart transform: '
        '${lastHeartTransform(badTrace)}');

    // Dump full traces to /tmp for offline diffing.
    final tmp = Directory.systemTemp;
    File('${tmp.path}/gummies_trace_good_1000.txt')
        .writeAsStringSync(goodTrace.join('\n'));
    File('${tmp.path}/gummies_trace_bad_1559.txt')
        .writeAsStringSync(badTrace.join('\n'));
    print('\nFull traces dumped to:');
    print('  ${tmp.path}/gummies_trace_good_1000.txt');
    print('  ${tmp.path}/gummies_trace_bad_1559.txt');
  });
}
