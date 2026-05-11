// SVG animation debug viewer.
//
// Frame-accurate scrubber, layer tree (search + per-element visibility
// toggle), live attribute inspector, and JSON / PNG snapshot exporter
// for the currently loaded SVG.
//
// The scrubber drives BOTH the SMIL timeline (via the controller's seek)
// AND any SVGator JS player attached to the document (via JS eval through
// the bridge). This means it works for declarative SMIL animations AND for
// SVGator-generated SVGs whose timing is owned by JavaScript.
//
// Use the "Copy JSON" button to grab a full dump of every element's live
// attribute values at the current animation time — paste that JSON back
// into chat and the next analysis can proceed without screenshots.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/svg_animations.dart';
import '../widgets/svg_gallery_card.dart' show svgNetworkCache;

class SvgDebugViewerPage extends StatefulWidget {
  const SvgDebugViewerPage({super.key, required this.item});

  final SvgAnimationItem item;

  @override
  State<SvgDebugViewerPage> createState() => _SvgDebugViewerPageState();
}

class _SvgDebugViewerPageState extends State<SvgDebugViewerPage> {
  String? _svg;
  bool _loading = true;
  String? _error;

  final AnimatedSvgController _controller = AnimatedSvgController();
  final GlobalKey _canvasKey = GlobalKey();

  /// Scrubber position in ms (drives both SMIL `controller.seek` and the
  /// JS-side `svg.svgatorPlayer.seekTo`).
  double _seekMs = 0;

  /// Total duration in ms. For SMIL we read it from the snapshot; for
  /// SVGator we leave a user-editable default since the SMIL timeline
  /// reports 0.
  double _totalMs = 5000;

  /// Last captured snapshot from the controller. Used to render the layer
  /// list and inspector.
  Map<String, Object?>? _snapshot;

  /// Currently selected element id (highlighted in the layer tree).
  String? _selectedId;

  /// Element ids that the user has temporarily hidden via the eye-toggle.
  /// We restore their original `opacity`/`visibility` on un-toggle.
  final Map<String, String?> _hiddenIds = {};

  /// User-typed search filter for the layer tree.
  String _filter = '';

  /// True while the user actively drags the slider — we suppress
  /// auto-following of the controller's live time during a drag.
  bool _isUserDragging = false;

  /// 50 Hz polling so the inspector reflects live SVGator-applied attrs.
  Timer? _refreshTimer;

  /// Pause state. We track it locally because the SVGator player has its
  /// own pause/play independent of SMIL.
  bool _localPaused = false;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_onControllerChange);
    _refreshTimer = Timer.periodic(
        const Duration(milliseconds: 50), (_) => _refreshSnapshot());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _refreshSnapshot() {
    if (!mounted) return;
    final snap = _controller.captureDebugSnapshot();
    final t = _controller.currentTimeMs;
    if (snap == null) return;
    setState(() {
      _snapshot = snap;
      if (!_isUserDragging && !_localPaused && t != null) {
        _seekMs = t;
      }
      final reportedTotal = snap['totalDurationMs'];
      if (reportedTotal is num && reportedTotal > 0) {
        _totalMs = reportedTotal.toDouble();
      }
    });
  }

  // ── load ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final cached = svgNetworkCache[widget.item.url];
    if (cached != null) {
      setState(() {
        _svg = cached;
        _loading = false;
      });
      return;
    }
    try {
      final res = await http.get(Uri.parse(widget.item.url));
      if (!mounted) return;
      if (res.statusCode == 200) {
        svgNetworkCache[widget.item.url] = res.body;
        setState(() {
          _svg = res.body;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'HTTP ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── playback / seek ───────────────────────────────────────────────────

  /// Seeks BOTH the SMIL timeline and any SVGator JS player.
  void _seekTo(double ms) {
    final clamped = ms.clamp(0.0, _totalMs);
    setState(() => _seekMs = clamped);
    // 1) SMIL timeline.
    _controller.seek(Duration(microseconds: (clamped * 1000).round()));
    // 2) SVGator JS players (no-op if no JS bridge or no players).
    _seekJsPlayers(clamped);
  }

  void _seekJsPlayers(double ms) {
    final code = '''
(function() {
  try {
    var roots = document.querySelectorAll('svg');
    var n = 0;
    for (var i = 0; i < roots.length; i++) {
      var p = roots[i].svgatorPlayer;
      if (p && typeof p.seekTo === 'function') {
        try { if (${_localPaused ? 'true' : 'false'}) p.pause(); } catch(e) {}
        try { p.seekTo(${ms.toStringAsFixed(1)}); n++; } catch(e) {}
      }
    }
    return n;
  } catch(e) { return -1; }
})();
''';
    _controller.evaluateJsForDebug(code);
  }

  void _step(double deltaMs) => _seekTo(_seekMs + deltaMs);

  void _togglePlay() {
    setState(() => _localPaused = !_localPaused);
    if (_localPaused) {
      _controller.pause();
      _controller.evaluateJsForDebug(
        '(function(){var r=document.querySelectorAll("svg");'
        'for(var i=0;i<r.length;i++){var p=r[i].svgatorPlayer;'
        'if(p&&typeof p.pause==="function"){try{p.pause();}catch(e){}}}})();',
      );
    } else {
      _controller.resume();
      _controller.evaluateJsForDebug(
        '(function(){var r=document.querySelectorAll("svg");'
        'for(var i=0;i<r.length;i++){var p=r[i].svgatorPlayer;'
        'if(p&&typeof p.play==="function"){try{p.play();}catch(e){}}}})();',
      );
    }
  }

  void _restart() {
    _controller.restart();
    _seekTo(0);
  }

  // ── visibility toggle (per-layer eye icon) ────────────────────────────

  void _toggleVisibility(String elementId) {
    final isHidden = _hiddenIds.containsKey(elementId);
    if (isHidden) {
      final originalOpacity = _hiddenIds.remove(elementId);
      // Restore opacity (or remove the attribute entirely if it had no
      // explicit value before we touched it).
      if (originalOpacity == null) {
        _controller.evaluateJsForDebug(
          'document.getElementById(${jsonEncode(elementId)})'
          '.removeAttribute("opacity");',
        );
      } else {
        _controller.evaluateJsForDebug(
          'document.getElementById(${jsonEncode(elementId)})'
          '.setAttribute("opacity", ${jsonEncode(originalOpacity)});',
        );
      }
    } else {
      // Capture the current opacity so we can restore it later.
      final snap = _snapshot;
      String? current;
      if (snap != null) {
        final elements = (snap['elements'] as List?)
                ?.cast<Map<String, Object?>>() ??
            const <Map<String, Object?>>[];
        final e = elements.firstWhere(
          (m) => m['id'] == elementId,
          orElse: () => const <String, Object?>{},
        );
        final attrs = (e['attrs'] as Map?)?.cast<String, String>();
        current = attrs?['opacity'];
      }
      _hiddenIds[elementId] = current;
      _controller.evaluateJsForDebug(
        'document.getElementById(${jsonEncode(elementId)})'
        '.setAttribute("opacity", "0");',
      );
    }
    setState(() {});
  }

  // ── JSON export ──────────────────────────────────────────────────────────

  String _exportJson({String? note}) {
    final snap = _controller.captureDebugSnapshot() ?? <String, Object?>{};
    final payload = <String, Object?>{
      'meta': <String, Object?>{
        'sourceUrl': widget.item.url,
        'title': widget.item.title,
        if (note != null) 'note': note,
        'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
        'selectedId': _selectedId,
        'seekMs': _seekMs,
        'isPaused': _localPaused,
        'totalMs': _totalMs,
        'hiddenIds': _hiddenIds.keys.toList(),
      },
      ...snap,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> _copyJsonToClipboard() async {
    final json = _exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    final bytes = utf8.encode(json).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('JSON copied (${(bytes / 1024).toStringAsFixed(1)} KB, '
            '${(_snapshot?['elementCount'] ?? '?')} elements)'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<File> _writeToDownloadsOrTemp(String filename, List<int> bytes) async {
    final home = Platform.environment['HOME'];
    Directory targetDir;
    if (home != null && Directory('$home/Downloads').existsSync()) {
      targetDir = Directory('$home/Downloads');
    } else {
      targetDir = Directory.systemTemp;
    }
    final file = File('${targetDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _stamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');

  String _slugTitle() => widget.item.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  Future<void> _saveJsonToFile() async {
    final json = _exportJson();
    try {
      final file = await _writeToDownloadsOrTemp(
          'svg-debug-${_slugTitle()}-${_stamp()}.json',
          utf8.encode(json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved → ${file.path}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Copy path',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save JSON: $e')),
      );
    }
  }

  // ── PNG screenshot ───────────────────────────────────────────────────

  Future<void> _saveScreenshot() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Use a high DPR for legibility on retina screens.
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('toByteData returned null');
      }
      final file = await _writeToDownloadsOrTemp(
        'svg-debug-${_slugTitle()}-t${_seekMs.toStringAsFixed(0)}ms-${_stamp()}.png',
        byteData.buffer.asUint8List(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved → ${file.path}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Copy path',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Screenshot failed: $e')),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          'DEBUG · ${widget.item.title}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            tooltip: _localPaused ? 'Play' : 'Pause',
            icon: Icon(_localPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded),
            color: Colors.white,
            onPressed: _togglePlay,
          ),
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.restart_alt_rounded),
            color: Colors.white,
            onPressed: _restart,
          ),
          if (_selectedId != null)
            IconButton(
              tooltip: 'Clear selection ($_selectedId)',
              icon: const Icon(Icons.deselect_rounded),
              color: Colors.amberAccent,
              onPressed: () => setState(() => _selectedId = null),
            ),
          IconButton(
            tooltip: 'Save PNG screenshot',
            icon: const Icon(Icons.photo_camera_rounded),
            color: Colors.white,
            onPressed: _saveScreenshot,
          ),
          IconButton(
            tooltip: 'Copy JSON snapshot to clipboard',
            icon: const Icon(Icons.content_copy_rounded),
            color: Colors.white,
            onPressed: _copyJsonToClipboard,
          ),
          IconButton(
            tooltip: 'Save JSON snapshot to ~/Downloads',
            icon: const Icon(Icons.save_alt_rounded),
            color: Colors.white,
            onPressed: _saveJsonToFile,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
      );
    }
    return Column(
      children: [
        _buildBridgeStatsBar(),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildSvgPane()),
              const VerticalDivider(width: 1, color: Color(0xFF1F1F26)),
              SizedBox(width: 380, child: _buildSidePanel()),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF1F1F26)),
        _buildScrubber(),
      ],
    );
  }

  /// Tiny status bar — just the current seek time for now. The bridge
  /// counters used to live here back when we had a Dart-side override; now
  /// that we trust the JS player wholesale this widget mostly serves as
  /// a scrubber readout.
  Widget _buildBridgeStatsBar() {
    return Container(
      color: const Color(0xFF0F1320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
            color: Colors.white70, fontFamily: 'monospace', fontSize: 11),
        child: Row(
          children: [
            const Icon(Icons.precision_manufacturing_rounded,
                size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            const Text('JS bridge'),
            const Spacer(),
            Text('seekMs: ${_seekMs.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgPane() {
    return Container(
      color: const Color(0xFF14141A),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: RepaintBoundary(
          key: _canvasKey,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 900, maxHeight: 720),
            child: AspectRatio(
              aspectRatio: _aspect(),
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.precise,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _pickElementAt(
                          details.localPosition,
                          constraints.biggest,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedSvgPicture.string(
                              _svg!,
                              controller: _controller,
                              autoPlay: true,
                            ),
                            if (_selectedId != null)
                              _buildSelectionOverlay(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hit-tests the snapshot's bboxes against [localPosition] and selects the
  /// deepest element whose bbox contains the point. Ties broken by smallest
  /// bbox area — i.e. picks the most specific child.
  ///
  /// [canvasSize] is the size of the SVG pane in widget pixels. The SVG
  /// is laid out at viewBox aspect, so this maps to viewBox via a uniform
  /// scale.
  void _pickElementAt(Offset localPosition, Size canvasSize) {
    final snap = _snapshot;
    if (snap == null) return;
    final vb = snap['viewBox'];
    if (vb is! Map) return;
    final vbX = (vb['x'] as num).toDouble();
    final vbY = (vb['y'] as num).toDouble();
    final vbW = (vb['width'] as num).toDouble();
    final vbH = (vb['height'] as num).toDouble();
    if (vbW <= 0 ||
        vbH <= 0 ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return;
    }
    final px = vbX + localPosition.dx / canvasSize.width * vbW;
    final py = vbY + localPosition.dy / canvasSize.height * vbH;

    final elements = (snap['elements'] as List?)
            ?.cast<Map<String, Object?>>() ??
        const <Map<String, Object?>>[];

    String? bestId;
    int bestDepth = -1;
    double bestArea = double.infinity;
    for (final e in elements) {
      final id = e['id'] as String?;
      final bb = e['bboxRoot'] as Map?;
      if (id == null || bb == null) continue;
      final x = (bb['x'] as num).toDouble();
      final y = (bb['y'] as num).toDouble();
      final w = (bb['w'] as num).toDouble();
      final h = (bb['h'] as num).toDouble();
      if (px < x || py < y || px > x + w || py > y + h) continue;
      final depth = (e['depth'] as int?) ?? 0;
      final area = w * h;
      // Prefer deeper element; among same depth, the smaller one.
      if (depth > bestDepth ||
          (depth == bestDepth && area < bestArea)) {
        bestDepth = depth;
        bestArea = area;
        bestId = id;
      }
    }
    setState(() {
      // Clicking on empty space (outside any id'd bbox) deselects.
      _selectedId = bestId;
    });
  }

  Widget _buildSelectionOverlay() {
    final snap = _snapshot;
    if (snap == null || _selectedId == null) return const SizedBox.shrink();
    final elements =
        (snap['elements'] as List?)?.cast<Map<String, Object?>>() ??
            const <Map<String, Object?>>[];
    final sel = elements.firstWhere(
      (e) => e['id'] == _selectedId,
      orElse: () => const <String, Object?>{},
    );
    final bb = sel['bboxRoot'] as Map?;
    final vb = snap['viewBox'] as Map?;
    if (bb == null || vb == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _SelectionPainter(
          bbox: Rect.fromLTWH(
            (bb['x'] as num).toDouble(),
            (bb['y'] as num).toDouble(),
            (bb['w'] as num).toDouble(),
            (bb['h'] as num).toDouble(),
          ),
          viewBox: Rect.fromLTWH(
            (vb['x'] as num).toDouble(),
            (vb['y'] as num).toDouble(),
            (vb['width'] as num).toDouble(),
            (vb['height'] as num).toDouble(),
          ),
          label: _selectedId!,
        ),
      ),
    );
  }

  double _aspect() {
    final vb = _snapshot?['viewBox'];
    if (vb is Map) {
      final w = (vb['width'] as num?)?.toDouble() ?? 1;
      final h = (vb['height'] as num?)?.toDouble() ?? 1;
      if (w > 0 && h > 0) return w / h;
    }
    return 16 / 9;
  }

  // ── Side panel: tabs ───────────────────────────────────────────────

  Widget _buildSidePanel() {
    final elements = (_snapshot?['elements'] as List?)
            ?.cast<Map<String, Object?>>() ??
        const <Map<String, Object?>>[];

    return Container(
      color: const Color(0xFF101015),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Layers'),
                Tab(text: 'Inspector'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLayerList(elements),
                  _buildInspector(elements),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerList(List<Map<String, Object?>> elements) {
    final filtered = _filter.trim().isEmpty
        ? elements
        : elements.where((e) {
            final id = (e['id'] as String?) ?? '';
            final tag = (e['tag'] as String?) ?? '';
            final q = _filter.toLowerCase();
            return id.toLowerCase().contains(q) ||
                tag.toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            decoration: InputDecoration(
              hintText: 'Filter layers by id or tag…',
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: const Icon(Icons.filter_alt_rounded,
                  color: Colors.white38, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF222230)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF222230)),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No matches.',
                  style: TextStyle(color: Colors.white24)),
            ),
          )
        else
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => _buildLayerRow(filtered[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLayerRow(Map<String, Object?> e) {
    final id = e['id'] as String?;
    final tag = e['tag'] as String? ?? '';
    final depth = (e['depth'] as int?) ?? 0;
    final isSelected = id != null && id == _selectedId;
    final hasAnim = e['hasAnimations'] == true;
    final isHidden = id != null && _hiddenIds.containsKey(id);

    return InkWell(
      onTap: id == null
          ? null
          : () => setState(
              () => _selectedId = _selectedId == id ? null : id),
      child: Container(
        padding: EdgeInsets.only(
            left: 4.0 + depth * 12, right: 4, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F3056) : Colors.transparent,
          border: Border(
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            if (id != null)
              GestureDetector(
                onTap: () => _toggleVisibility(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                    color: isHidden
                        ? const Color(0xFFEF5350)
                        : Colors.white38,
                  ),
                ),
              )
            else
              const SizedBox(width: 22),
            Icon(
              hasAnim ? Icons.animation_rounded : Icons.circle_outlined,
              size: 11,
              color: hasAnim
                  ? const Color(0xFFFFB74D)
                  : Colors.white24,
            ),
            const SizedBox(width: 6),
            Text(
              '<$tag>',
              style: const TextStyle(
                color: Color(0xFF80CBC4),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            if (id != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '#$id',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isHidden ? Colors.white30 : Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    decoration:
                        isHidden ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
            ],
            if ((e['childCount'] as int? ?? 0) > 0)
              Text(
                '${e['childCount']}',
                style: const TextStyle(
                    color: Colors.white24, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspector(List<Map<String, Object?>> elements) {
    if (_selectedId == null) {
      return const Center(
        child: Text('Select a layer to inspect its attributes.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final sel = elements.firstWhere(
      (e) => e['id'] == _selectedId,
      orElse: () => const <String, Object?>{},
    );
    if (sel.isEmpty) {
      return const Center(
        child: Text('Selected element not in current snapshot.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final live =
        (sel['attrs'] as Map?)?.cast<String, String>() ??
            const <String, String>{};
    final base =
        (sel['base'] as Map?)?.cast<String, String>() ??
            const <String, String>{};
    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _kv('Tag', sel['tag']?.toString() ?? ''),
          _kv('ID', sel['id']?.toString() ?? '—'),
          _kv('Depth', sel['depth']?.toString() ?? ''),
          _kv('Animated', sel['hasAnimations']?.toString() ?? 'false'),
          _kv('Children', sel['childCount']?.toString() ?? '0'),
          const Divider(color: Color(0xFF222230)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Live attributes',
                style:
                    TextStyle(color: Colors.white60, fontSize: 11)),
          ),
          for (final entry in live.entries) _attrRow(entry.key, entry.value),
          if (base.isNotEmpty) ...[
            const Divider(color: Color(0xFF222230)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Base (authored) attributes',
                  style: TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ),
            for (final entry in base.entries)
              _attrRow(entry.key, entry.value, dim: true),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(k,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ),
            Expanded(
              child: SelectableText(
                v,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _attrRow(String name, String value, {bool dim = false}) {
    final col = dim ? Colors.white38 : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(name,
                style: TextStyle(
                    color:
                        dim ? Colors.white30 : const Color(0xFF80CBC4),
                    fontFamily: 'monospace',
                    fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                  color: col, fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom timeline scrubber ──────────────────────────────────────────

  Widget _buildScrubber() {
    final stepButtons = [
      (-500, Icons.keyboard_double_arrow_left_rounded, '−500'),
      (-100, Icons.chevron_left_rounded, '−100'),
      (-10, Icons.remove_rounded, '−10'),
      (-1, null, '−1'),
    ];
    final stepButtonsRight = [
      (1, null, '+1'),
      (10, Icons.add_rounded, '+10'),
      (100, Icons.chevron_right_rounded, '+100'),
      (500, Icons.keyboard_double_arrow_right_rounded, '+500'),
    ];
    return Container(
      color: const Color(0xFF101015),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final btn in stepButtons)
            _StepButton(
              tooltip: '${btn.$3} ms',
              icon: btn.$2,
              label: btn.$2 == null ? btn.$3 : null,
              onPressed: () => _step(btn.$1.toDouble()),
            ),
          SizedBox(
            width: 150,
            child: Text(
              '${_seekMs.toStringAsFixed(0).padLeft(5)} / '
              '${_totalMs.toStringAsFixed(0)} ms',
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          for (final btn in stepButtonsRight)
            _StepButton(
              tooltip: '${btn.$3} ms',
              icon: btn.$2,
              label: btn.$2 == null ? btn.$3 : null,
              onPressed: () => _step(btn.$1.toDouble()),
            ),
          Expanded(
            child: Slider(
              value: _seekMs.clamp(0.0, _totalMs),
              min: 0,
              max: _totalMs,
              onChangeStart: (_) {
                _isUserDragging = true;
                if (!_localPaused) {
                  // Auto-pause on drag so the scrub position is stable.
                  setState(() => _localPaused = true);
                  _controller.pause();
                }
              },
              onChanged: (v) {
                _isUserDragging = true;
                _seekTo(v);
              },
              onChangeEnd: (_) => _isUserDragging = false,
              divisions: _totalMs.clamp(10, 10000).toInt(),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'duration ms',
                hintStyle:
                    const TextStyle(color: Colors.white24, fontSize: 11),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: Color(0xFF222230)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: Color(0xFF222230)),
                ),
              ),
              style:
                  const TextStyle(color: Colors.white, fontSize: 12),
              keyboardType: TextInputType.number,
              onSubmitted: (s) {
                final v = double.tryParse(s);
                if (v != null && v > 0) setState(() => _totalMs = v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a red-outline bounding box over the SVG canvas for the currently
/// selected layer. Coordinates come from the snapshot's `bboxRoot` (in
/// viewBox space). The pane is sized to match viewBox aspect, so mapping
/// to widget coords is a simple uniform scale.
class _SelectionPainter extends CustomPainter {
  _SelectionPainter({
    required this.bbox,
    required this.viewBox,
    required this.label,
  });

  final Rect bbox;
  final Rect viewBox;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    if (viewBox.width <= 0 || viewBox.height <= 0) return;
    final sx = size.width / viewBox.width;
    final sy = size.height / viewBox.height;
    final left = (bbox.left - viewBox.left) * sx;
    final top = (bbox.top - viewBox.top) * sy;
    final right = (bbox.right - viewBox.left) * sx;
    final bottom = (bbox.bottom - viewBox.top) * sy;
    final r = Rect.fromLTRB(left, top, right, bottom);

    // Dim everything outside the bbox very slightly to draw attention.
    final outlinePaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()
      ..color = const Color(0x22FF1744)
      ..style = PaintingStyle.fill;

    canvas.drawRect(r, fillPaint);
    canvas.drawRect(r, outlinePaint);

    // Cross-hair to make small bboxes locatable.
    final cross = Paint()
      ..color = const Color(0x88FF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = (r.left + r.right) / 2;
    final cy = (r.top + r.bottom) / 2;
    canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 10, cy), cross);
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 10), cross);

    // Label.
    final tp = TextPainter(
      text: TextSpan(
        text: '$label  ${bbox.width.toStringAsFixed(1)}×'
            '${bbox.height.toStringAsFixed(1)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelBg = Rect.fromLTWH(
      r.left,
      (r.top - tp.height - 4).clamp(0.0, size.height - tp.height - 4),
      tp.width + 8,
      tp.height + 4,
    );
    canvas.drawRect(
      labelBg,
      Paint()..color = const Color(0xCCFF1744),
    );
    tp.paint(canvas, Offset(labelBg.left + 4, labelBg.top + 2));
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.bbox != bbox || old.viewBox != viewBox || old.label != label;
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 18)
              : Text(
                  label ?? '',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12),
                ),
        ),
      ),
    );
  }
}
