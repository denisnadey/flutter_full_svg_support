import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:quickjs_engine/quickjs_engine.dart';
import 'package:http/http.dart' as http;

import 'css_animations.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'svg_dom.dart';

/// JS runtime bridge: maps SVG DOM API calls from JS to the [SvgDocument] tree.
///
/// Executes inline `<script>` blocks and routes DOM operations
/// (getElementById, setAttribute, style, addEventListener, timers)
/// back into the Dart node tree with automatic repaint.
class SvgJsBridge {
  SvgJsBridge({
    required SvgDocument document,
    required void Function() markNeedsRepaint,
    required void Function(
      String elementId,
      String eventType,
      void Function() callback,
    )
    addEventHandler,
  }) : _document = document,
       _repaint = markNeedsRepaint,
       _addEventHandler = addEventHandler {
    // xhr: false — we handle HTTP via Dart's http.get in _fetchAndExecuteUrl.
    // Leaving xhr: true (default) creates a 40ms Timer.periodic inside flutter_js
    // that leaks across tests.
    _runtime = getJavascriptRuntime(xhr: false);
    _registerHandlers();
    _injectPolyfill();
  }

  final SvgDocument _document;
  final void Function() _repaint;
  final void Function(String, String, void Function()) _addEventHandler;

  late final JavascriptRuntime _runtime;
  final Map<String, Timer> _timers = {};
  final List<String> _loadListenerKeys = [];
  final Set<String> _rafKeys = {};
  bool _rafFrameScheduled = false;

  // External script loading state
  int _pendingExternal = 0;
  bool _inlinesDone = false;
  bool _disposed = false;
  final Completer<void> _externalCompleter = Completer<void>();

  /// Resolves when all external scripts triggered by inline scripts have loaded.
  Future<void> get externalScriptsLoaded => _externalCompleter.future;

  // ── DOM message handlers ─────────────────────────────────────────────────

  void _registerHandlers() {
    _runtime.onMessage('getElementById', (dynamic args) {
      final id = (args as Map)['id'] as String;
      final found = _document.getElementById(id);
      return jsonEncode(found != null ? id : null);
    });

    _runtime.onMessage('getAttribute', (dynamic args) {
      final map = args as Map;
      final node = _document.getElementById(map['id'] as String);
      if (node == null) return jsonEncode(null);
      final value = node.getAttributeValue(map['name'] as String);
      return jsonEncode(value?.toString());
    });

    _runtime.onMessage('getAttributeNames', (dynamic args) {
      final id = (args as Map)['id'] as String;
      final node = _document.getElementById(id);
      if (node == null) return jsonEncode(<String>[]);
      final names = node.attributes.keys.toList();
      if (node.id != null && !names.contains('id')) names.add('id');
      if (node.className != null && !names.contains('class')) names.add('class');
      return jsonEncode(names);
    });

    _runtime.onMessage('setAttribute', (dynamic args) {
      final map = args as Map;
      final id = map['id'] as String;
      final name = map['name'] as String;
      final value = map['value'] as String;
      final node = _document.getElementById(id);
      if (node != null) {
        _setAttr(node, name, value);
        _repaint();
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('getStyle', (dynamic args) {
      final map = args as Map;
      final node = _document.getElementById(map['id'] as String);
      if (node == null) return jsonEncode('');
      final kebab = _camelToKebab(map['name'] as String);
      return jsonEncode(node.getAttributeValue(kebab)?.toString() ?? '');
    });

    _runtime.onMessage('setStyle', (dynamic args) {
      final map = args as Map;
      final node = _document.getElementById(map['id'] as String);
      if (node != null) {
        _setAttr(node, _camelToKebab(map['name'] as String), map['value'] as String);
        _repaint();
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('getTagName', (dynamic args) {
      final node = _document.getElementById((args as Map)['id'] as String);
      return jsonEncode(node?.tagName);
    });

    _runtime.onMessage('querySelector', (dynamic args) {
      final map = args as Map;
      final contextId = map['id'] as String?;
      final root = contextId != null
          ? _document.getElementById(contextId)
          : _document.root;
      if (root == null) return jsonEncode(null);
      final node = _querySelector(root, map['selector'] as String);
      return jsonEncode(node?.id);
    });

    _runtime.onMessage('querySelectorAll', (dynamic args) {
      final map = args as Map;
      final contextId = map['id'] as String?;
      final root = contextId != null
          ? _document.getElementById(contextId)
          : _document.root;
      if (root == null) return jsonEncode(<String>[]);
      final nodes = _querySelectorAll(root, map['selector'] as String);
      return jsonEncode(nodes.map((n) => n.id).whereType<String>().toList());
    });

    _runtime.onMessage('addEventListener', (dynamic args) {
      final map = args as Map;
      final elementId = map['id'] as String;
      final eventType = map['type'] as String;
      final key = map['key'] as String;
      _addEventHandler(elementId, eventType, () => _fireListener(key));
      return jsonEncode(null);
    });

    _runtime.onMessage('addWindowLoadListener', (dynamic args) {
      _loadListenerKeys.add((args as Map)['key'] as String);
      return jsonEncode(null);
    });

    _runtime.onMessage('setTimeout', (dynamic args) {
      final map = args as Map;
      final key = map['key'] as String;
      final ms = (map['ms'] as num).toInt();
      _timers[key] = Timer(Duration(milliseconds: ms), () {
        _timers.remove(key);
        _fireListener(key);
      });
      return jsonEncode(null);
    });

    _runtime.onMessage('clearTimeout', (dynamic args) {
      final key = (args as Map)['key'] as String;
      _timers.remove(key)?.cancel();
      return jsonEncode(null);
    });

    _runtime.onMessage('setInterval', (dynamic args) {
      final map = args as Map;
      final key = map['key'] as String;
      final ms = (map['ms'] as num).toInt().clamp(16, 60000);
      _timers[key] = Timer.periodic(Duration(milliseconds: ms), (_) {
        _fireListener(key);
      });
      return jsonEncode(null);
    });

    _runtime.onMessage('clearInterval', (dynamic args) {
      final key = (args as Map)['key'] as String;
      _timers.remove(key)?.cancel();
      return jsonEncode(null);
    });

    _runtime.onMessage('requestRAF', (dynamic args) {
      final key = (args as Map)['key'] as String;
      _rafKeys.add(key);
      _scheduleRafFrame();
      return jsonEncode(null);
    });

    _runtime.onMessage('cancelRAF', (dynamic args) {
      _rafKeys.remove((args as Map)['key'] as String);
      return jsonEncode(null);
    });

    _runtime.onMessage('getParentId', (dynamic args) {
      final node = _document.getElementById((args as Map)['id'] as String);
      return jsonEncode(node?.parent?.id);
    });

    _runtime.onMessage('getChildrenIds', (dynamic args) {
      final node = _document.getElementById((args as Map)['id'] as String);
      if (node == null) return jsonEncode(<String>[]);
      return jsonEncode(
        node.children.map((c) => c.id).whereType<String>().toList(),
      );
    });

    _runtime.onMessage('getRootId', (dynamic args) {
      return jsonEncode(_document.root.id);
    });

    _runtime.onMessage('getBoundingClientRect', (dynamic args) {
      final id = (args as Map)['id'] as String;
      final node = _document.getElementById(id);
      double w = 0, h = 0;
      if (node != null) {
        w = _parseAttrDouble(node.getAttributeValue('width')?.toString()) ?? 0;
        h = _parseAttrDouble(node.getAttributeValue('height')?.toString()) ?? 0;
        if (w == 0 || h == 0) {
          final vb = node.getAttributeValue('viewBox')?.toString() ?? '';
          final parts = vb.trim().split(RegExp(r'[\s,]+'));
          if (parts.length >= 4) {
            w = double.tryParse(parts[2]) ?? w;
            h = double.tryParse(parts[3]) ?? h;
          }
        }
      }
      return jsonEncode({
        'x': 0, 'y': 0, 'width': w, 'height': h,
        'top': 0, 'left': 0, 'right': w, 'bottom': h,
      });
    });

    _runtime.onMessage('removeChild', (dynamic args) {
      final map = args as Map;
      final parent = _document.getElementById(map['parentId'] as String);
      final childId = map['childId'] as String;
      if (parent != null) {
        parent.children.removeWhere((c) => c.id == childId);
        _repaint();
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('replaceChild', (dynamic args) {
      final map = args as Map;
      final parent = _document.getElementById(map['parentId'] as String);
      final oldId = map['oldId'] as String;
      if (parent != null) {
        parent.children.removeWhere((c) => c.id == oldId);
        _repaint();
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('getBBox', (dynamic args) {
      final node = _document.getElementById((args as Map)['id'] as String);
      if (node == null) {
        return jsonEncode({'x': 0.0, 'y': 0.0, 'width': 0.0, 'height': 0.0});
      }
      final r = _computeBBox(node);
      return jsonEncode({'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height});
    });

    _runtime.onMessage('getTotalLength', (dynamic args) {
      final node = _document.getElementById((args as Map)['id'] as String);
      return jsonEncode(node != null ? _computeTotalLength(node) : 0.0);
    });

    _runtime.onMessage('getPointAtLength', (dynamic args) {
      final map = args as Map;
      final node = _document.getElementById(map['id'] as String);
      final distance = (map['distance'] as num).toDouble();
      if (node == null) return jsonEncode({'x': 0.0, 'y': 0.0});
      final pt = _computePointAtLength(node, distance);
      return jsonEncode({'x': pt.dx, 'y': pt.dy});
    });

    _runtime.onMessage('matches', (dynamic args) {
      final map = args as Map;
      final id = map['id'] as String;
      final node = _document.getElementById(id);
      if (node == null) return jsonEncode(false);
      final matches = _querySelectorAll(_document.root, map['selector'] as String);
      return jsonEncode(matches.any((n) => n.id == id));
    });

    _runtime.onMessage('closest', (dynamic args) {
      final map = args as Map;
      final selector = map['selector'] as String;
      SvgNode? node = _document.getElementById(map['id'] as String);
      while (node != null) {
        final matches = _querySelectorAll(_document.root, selector);
        if (matches.any((n) => n.id == node!.id)) return jsonEncode(node.id);
        node = node.parent;
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('contains', (dynamic args) {
      final map = args as Map;
      final parentId = map['parentId'] as String;
      SvgNode? node = _document.getElementById(map['childId'] as String);
      while (node != null) {
        if (node.id == parentId) return jsonEncode(true);
        node = node.parent;
      }
      return jsonEncode(false);
    });

    _runtime.onMessage('injectCSS', (dynamic args) {
      final html = (args as Map)['html'] as String? ?? '';
      final styleRe = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false);
      for (final m in styleRe.allMatches(html)) {
        _applyCssToDocument(m.group(1) ?? '');
      }
      // Also handle a bare CSS block (no <style> wrapper)
      if (!styleRe.hasMatch(html) && html.contains('{')) {
        _applyCssToDocument(html);
      }
      return jsonEncode(null);
    });

    _runtime.onMessage('loadExternalScript', (dynamic args) {
      final url = (args as Map)['src'] as String;
      _pendingExternal++;
      developer.log('loadExternalScript: $url', name: 'SVG/JS');
      _fetchAndExecuteUrl(url);
      return jsonEncode(null);
    });

    _runtime.onMessage('console.log', (dynamic args) {
      developer.log(
        (args as List).map((e) => e.toString()).join(' '),
        name: 'SVG/JS',
      );
      return jsonEncode(null);
    });

    _runtime.onMessage('console.warn', (dynamic args) {
      developer.log(
        '[warn] ${(args as List).map((e) => e.toString()).join(' ')}',
        name: 'SVG/JS',
      );
      return jsonEncode(null);
    });

    _runtime.onMessage('console.error', (dynamic args) {
      developer.log(
        '[error] ${(args as List).map((e) => e.toString()).join(' ')}',
        name: 'SVG/JS',
      );
      return jsonEncode(null);
    });
  }

  // ── External script loading ───────────────────────────────────────────────

  Future<void> _fetchAndExecuteUrl(String url) async {
    try {
      developer.log('Fetching external script: $url', name: 'SVG/JS');
      final response = await http.get(Uri.parse(url));
      if (_disposed) return;
      if (response.statusCode == 200) {
        developer.log(
          'Executing external script (${response.body.length} bytes): $url',
          name: 'SVG/JS',
        );
        _eval(response.body, label: 'external:$url');
      } else {
        developer.log('Fetch failed ${response.statusCode}: $url', name: 'SVG/JS');
      }
    } catch (e) {
      if (!_disposed) developer.log('Fetch error: $url → $e', name: 'SVG/JS');
    } finally {
      if (!_disposed) {
        _pendingExternal--;
        _maybeCompleteExternal();
      }
    }
  }

  void _maybeCompleteExternal() {
    if (_inlinesDone && _pendingExternal == 0 && !_externalCompleter.isCompleted) {
      _externalCompleter.complete();
    }
  }

  // ── DOM polyfill (injected once into the JS runtime) ─────────────────────

  // ignore: avoid_single_cascade_in_expression_statements
  static const String _polyfill = r'''
(function() {
  var _listeners = {};
  var _seq = 0;
  var _virtAttrs = {}; // id -> {tag, attrs: {}}
  var _loadedScripts = {}; // dedup external script loads

  function _requestScriptLoad(src) {
    if (src && !_loadedScripts[src]) {
      _loadedScripts[src] = true;
      try { sendMessage('loadExternalScript', JSON.stringify({src: src})); } catch(e) {}
    }
  }

  function _handleInsert(parent, child) {
    if (!child) return;
    var childId = child.id;
    if (typeof childId === 'string' && childId.indexOf('__virt_') === 0) {
      var info = _virtAttrs[childId];
      if (info && info.tag === 'script') {
        var src = info.attrs['src'];
        if (src) _requestScriptLoad(src);
      }
    }
  }

  // ── SVG Matrix / Transform API ───────────────────────────────────────────
  function _makeSVGMatrix(a, b, c, d, e, f) {
    var m = {
      a: a !== undefined ? a : 1, b: b !== undefined ? b : 0,
      c: c !== undefined ? c : 0, d: d !== undefined ? d : 1,
      e: e !== undefined ? e : 0, f: f !== undefined ? f : 0
    };
    m.multiply = function(o) {
      return _makeSVGMatrix(
        m.a*o.a + m.c*o.b, m.b*o.a + m.d*o.b,
        m.a*o.c + m.c*o.d, m.b*o.c + m.d*o.d,
        m.a*o.e + m.c*o.f + m.e, m.b*o.e + m.d*o.f + m.f
      );
    };
    m.inverse = function() {
      var det = m.a*m.d - m.b*m.c;
      if (Math.abs(det) < 1e-10) return _makeSVGMatrix();
      return _makeSVGMatrix(m.d/det, -m.b/det, -m.c/det, m.a/det,
        (m.c*m.f - m.d*m.e)/det, (m.b*m.e - m.a*m.f)/det);
    };
    m.translate = function(x, y) {
      return _makeSVGMatrix(m.a, m.b, m.c, m.d, m.e+m.a*x+m.c*y, m.f+m.b*x+m.d*y);
    };
    m.scale = function(s) { return _makeSVGMatrix(m.a*s, m.b*s, m.c*s, m.d*s, m.e, m.f); };
    m.scaleNonUniform = function(sx, sy) { return _makeSVGMatrix(m.a*sx, m.b*sx, m.c*sy, m.d*sy, m.e, m.f); };
    m.rotate = function(angle) {
      var r = angle * Math.PI / 180, cos = Math.cos(r), sin = Math.sin(r);
      return m.multiply(_makeSVGMatrix(cos, sin, -sin, cos, 0, 0));
    };
    m.flipX = function() { return _makeSVGMatrix(-m.a, -m.b, m.c, m.d, m.e, m.f); };
    m.flipY = function() { return _makeSVGMatrix(m.a, m.b, -m.c, -m.d, m.e, m.f); };
    m.skewX = function(angle) {
      return m.multiply(_makeSVGMatrix(1, 0, Math.tan(angle*Math.PI/180), 1, 0, 0));
    };
    m.skewY = function(angle) {
      return m.multiply(_makeSVGMatrix(1, Math.tan(angle*Math.PI/180), 0, 1, 0, 0));
    };
    return m;
  }

  function _makeSVGTransform() {
    var t = { type: 0, matrix: _makeSVGMatrix(), angle: 0 };
    t.setMatrix = function(mx) {
      t.type = 1; t.matrix = _makeSVGMatrix(mx.a, mx.b, mx.c, mx.d, mx.e, mx.f);
    };
    t.setTranslate = function(tx, ty) {
      t.type = 2; t.matrix = _makeSVGMatrix(1,0,0,1,tx,ty); t.angle = 0;
    };
    t.setScale = function(sx, sy) {
      t.type = 3; t.matrix = _makeSVGMatrix(sx,0,0,sy,0,0); t.angle = 0;
    };
    t.setRotate = function(angle, cx, cy) {
      t.type = 4; t.angle = angle;
      var r = angle*Math.PI/180, cos = Math.cos(r), sin = Math.sin(r);
      cx = cx || 0; cy = cy || 0;
      t.matrix = _makeSVGMatrix(cos, sin, -sin, cos,
        cx - cx*cos + cy*sin, cy - cx*sin - cy*cos);
    };
    t.setSkewX = function(angle) {
      t.type = 5; t.angle = angle;
      t.matrix = _makeSVGMatrix(1, 0, Math.tan(angle*Math.PI/180), 1, 0, 0);
    };
    t.setSkewY = function(angle) {
      t.type = 6; t.angle = angle;
      t.matrix = _makeSVGMatrix(1, Math.tan(angle*Math.PI/180), 0, 1, 0, 0);
    };
    return t;
  }

  function _parseSVGTransformList(str) {
    var list = [];
    if (!str) return list;
    var re = /(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)/g;
    var match;
    while ((match = re.exec(str)) !== null) {
      var t = _makeSVGTransform();
      var args = match[2].trim().split(/[\s,]+/).map(Number);
      switch (match[1]) {
        case 'matrix':    t.setMatrix({a:args[0],b:args[1],c:args[2],d:args[3],e:args[4],f:args[5]}); break;
        case 'translate': t.setTranslate(args[0]||0, args[1]||0); break;
        case 'scale':     t.setScale(args[0]||1, args.length>1?args[1]:args[0]); break;
        case 'rotate':    t.setRotate(args[0]||0, args[1]||0, args[2]||0); break;
        case 'skewX':     t.setSkewX(args[0]||0); break;
        case 'skewY':     t.setSkewY(args[0]||0); break;
      }
      list.push(t);
    }
    return list;
  }

  function _serializeSVGTransformList(list) {
    return list.map(function(t) {
      var m = t.matrix;
      return 'matrix('+m.a+','+m.b+','+m.c+','+m.d+','+m.e+','+m.f+')';
    }).join(' ');
  }

  function _makeSVGTransformList(getAttrFn, setAttrFn) {
    var _list = null;
    function _load() {
      if (_list !== null) return;
      _list = _parseSVGTransformList(getAttrFn ? getAttrFn('transform') : null);
    }
    function _flush() { if (setAttrFn) setAttrFn('transform', _serializeSVGTransformList(_list)); }
    var tl = {};
    Object.defineProperty(tl, 'numberOfItems', { get: function() { _load(); return _list.length; } });
    tl.initialize = function(t) { _list = [t]; _flush(); return t; };
    tl.appendItem = function(t) { _load(); _list.push(t); _flush(); return t; };
    tl.insertItemBefore = function(t, i) { _load(); _list.splice(i,0,t); _flush(); return t; };
    tl.replaceItem = function(t, i) { _load(); _list[i] = t; _flush(); return t; };
    tl.removeItem = function(i) { _load(); var t = _list.splice(i,1)[0]; _flush(); return t; };
    tl.clear = function() { _list = []; _flush(); };
    tl.getItem = function(i) { _load(); return _list[i]; };
    tl.consolidate = function() {
      _load();
      if (!_list.length) return null;
      var r = _list[0].matrix;
      for (var i=1; i<_list.length; i++) r = r.multiply(_list[i].matrix);
      var t = _makeSVGTransform(); t.setMatrix(r); _list = [t]; _flush(); return t;
    };
    tl.createSVGTransformFromMatrix = function(m) { var t = _makeSVGTransform(); t.setMatrix(m); return t; };
    return tl;
  }

  // ── Path-length / point-at-length for virtual <path> elements ──────────
  //
  // SVGator's player builds a hidden <path> via createElementNS, sets its
  // `d` attribute (one of three shapes: M..L.., M..Q.., M..C..), then
  // calls getTotalLength / getPointAtLength to do arc-length-parameterized
  // bezier interpolation. The native browser implements these on the
  // SVGPathElement; we have to do the math ourselves.
  //
  // Approach: tokenize `d`, sample each curve segment at 100 sub-steps,
  // build a cumulative arc-length table, then binary-search for the
  // target distance. Cached per-vid keyed by the literal `d` string.
  var _pathCache = {};
  function _parsePathSegs(d) {
    var tokens = d.match(/[MLCQ]|-?\d+\.?\d*(?:[eE][+\-]?\d+)?/g);
    if (!tokens) return [];
    var segs = [], i = 0, cur = {x: 0, y: 0};
    while (i < tokens.length) {
      var cmd = tokens[i++];
      if (cmd === 'M') {
        cur = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
      } else if (cmd === 'L') {
        var e = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        segs.push({k: 'L', p0: cur, p3: e});
        cur = e;
      } else if (cmd === 'Q') {
        var c = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        var e2 = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        segs.push({k: 'Q', p0: cur, p1: c, p3: e2});
        cur = e2;
      } else if (cmd === 'C') {
        var c1 = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        var c2 = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        var e3 = {x: parseFloat(tokens[i++]), y: parseFloat(tokens[i++])};
        segs.push({k: 'C', p0: cur, p1: c1, p2: c2, p3: e3});
        cur = e3;
      }
    }
    return segs;
  }
  function _sampleSeg(seg, n) {
    var out = [];
    for (var k = 0; k <= n; k++) {
      var t = k / n, mt = 1 - t, x, y;
      if (seg.k === 'L') {
        x = seg.p0.x + (seg.p3.x - seg.p0.x) * t;
        y = seg.p0.y + (seg.p3.y - seg.p0.y) * t;
      } else if (seg.k === 'Q') {
        x = mt*mt*seg.p0.x + 2*mt*t*seg.p1.x + t*t*seg.p3.x;
        y = mt*mt*seg.p0.y + 2*mt*t*seg.p1.y + t*t*seg.p3.y;
      } else {
        var mt2 = mt*mt, mt3 = mt2*mt, t2 = t*t, t3 = t2*t;
        x = mt3*seg.p0.x + 3*mt2*t*seg.p1.x + 3*mt*t2*seg.p2.x + t3*seg.p3.x;
        y = mt3*seg.p0.y + 3*mt2*t*seg.p1.y + 3*mt*t2*seg.p2.y + t3*seg.p3.y;
      }
      out.push({x: x, y: y});
    }
    return out;
  }
  function _virtPathTable(vid) {
    var attrs = _virtAttrs[vid] && _virtAttrs[vid].attrs;
    var d = attrs && attrs.d;
    if (!d) return null;
    var cached = _pathCache[vid];
    if (cached && cached.d === d) return cached;
    var segs = _parsePathSegs(d);
    var samples = [];
    for (var i = 0; i < segs.length; i++) {
      var sub = _sampleSeg(segs[i], 100);
      // Skip the leading sample of subsequent segments to avoid double-counting joins.
      if (i > 0) sub = sub.slice(1);
      for (var j = 0; j < sub.length; j++) samples.push(sub[j]);
    }
    var cum = [0];
    for (var k = 1; k < samples.length; k++) {
      var dx = samples[k].x - samples[k-1].x;
      var dy = samples[k].y - samples[k-1].y;
      cum.push(cum[k-1] + Math.sqrt(dx*dx + dy*dy));
    }
    cached = {d: d, samples: samples, cum: cum, total: cum[cum.length - 1] || 0};
    _pathCache[vid] = cached;
    return cached;
  }
  function _virtPathLength(vid) {
    var t = _virtPathTable(vid);
    return t ? t.total : 0;
  }
  function _virtPathPointAt(vid, distance) {
    var t = _virtPathTable(vid);
    if (!t || t.samples.length === 0) return {x: 0, y: 0};
    if (!(distance > 0)) return {x: t.samples[0].x, y: t.samples[0].y};
    if (distance >= t.total) {
      var last = t.samples[t.samples.length - 1];
      return {x: last.x, y: last.y};
    }
    var lo = 0, hi = t.cum.length - 1;
    while (lo < hi) {
      var mid = (lo + hi) >> 1;
      if (t.cum[mid] < distance) lo = mid + 1; else hi = mid;
    }
    var i1 = lo, i0 = lo - 1;
    if (i0 < 0) return {x: t.samples[0].x, y: t.samples[0].y};
    var l0 = t.cum[i0], l1 = t.cum[i1];
    var span = l1 - l0;
    var f = span > 1e-12 ? (distance - l0) / span : 0;
    return {
      x: t.samples[i0].x + (t.samples[i1].x - t.samples[i0].x) * f,
      y: t.samples[i0].y + (t.samples[i1].y - t.samples[i0].y) * f
    };
  }

  // SVGAnimatedString — baseVal/animVal wrapper around a single attribute
  function _makeSVGAnimatedString(getFn, setFn) {
    var as = {};
    Object.defineProperty(as, 'baseVal', {
      get: function() { return getFn() || ''; },
      set: function(v) { setFn(String(v)); }
    });
    Object.defineProperty(as, 'animVal', { get: function() { return getFn() || ''; } });
    as.toString = function() { return getFn() || ''; };
    return as;
  }

  // Web Animations API — used by _makeVirtEl (id=null) and _makeEl (id=elId)
  function _makeAnimStub(elId, keyframes, options, elRef) {
    var dur = typeof options === 'number' ? options : (options && options.duration) || 0;
    var delay = (options && options.delay) || 0;
    var fill = (options && options.fill) || 'none';
    var kfs = Array.isArray(keyframes) ? keyframes : (keyframes ? [keyframes] : []);
    var _playState = 'running';
    var _currentTime = 0;
    var _startTime = null;
    var _onfinish = null, _oncancel = null;
    var _finishedResolve;
    var _finishedP = typeof Promise !== 'undefined'
      ? new Promise(function(r) { _finishedResolve = r; })
      : {then: function(f){return this;}, catch: function(){return this;}};

    function _lerp(a, b, t) { return a + (b - a) * t; }
    function _applyFrame(progress) {
      if (!elId || !kfs.length) return;
      var n = kfs.length;
      var rawIdx = progress * (n - 1);
      var idx = Math.min(Math.floor(rawIdx), n - 2);
      var localT = n > 1 ? rawIdx - idx : 0;
      localT = Math.max(0, Math.min(1, localT));
      var kf0 = kfs[idx] || {}, kf1 = kfs[Math.min(idx + 1, n - 1)] || {};
      Object.keys(kf1).forEach(function(prop) {
        if (prop === 'offset' || prop === 'easing') return;
        var v0 = kf0[prop] !== undefined ? kf0[prop] : kf1[prop];
        var v1 = kf1[prop];
        var n0 = parseFloat(v0), n1 = parseFloat(v1);
        var val = (!isNaN(n0) && !isNaN(n1)) ? String(_lerp(n0, n1, localT)) : (localT >= 0.5 ? String(v1) : String(v0));
        try {
          if (prop === 'transform' || prop === 'opacity' || prop === 'visibility' || prop.indexOf('-') >= 0) {
            sendMessage('setStyle', JSON.stringify({id: elId, name: prop, value: val}));
          } else {
            sendMessage('setAttribute', JSON.stringify({id: elId, name: prop, value: val}));
          }
        } catch(e) {}
      });
    }
    function _complete() {
      _playState = 'finished';
      if (fill === 'forwards' || fill === 'both') _applyFrame(1);
      try { if (_onfinish) _onfinish({type: 'finish', target: anim}); } catch(e) {}
      try { if (_finishedResolve) _finishedResolve(anim); } catch(e) {}
    }
    var _rafHandle = null;
    function _scheduleRaf() {
      requestAnimationFrame(function _tick(ts) {
        if (_playState !== 'running') return;
        if (_startTime === null) _startTime = ts - _currentTime;
        var elapsed = ts - _startTime - delay;
        if (elapsed < 0) { _rafHandle = requestAnimationFrame(_tick); return; }
        _currentTime = elapsed;
        var progress = dur > 0 ? Math.min(elapsed / dur, 1) : 1;
        _applyFrame(progress);
        if (progress >= 1) { _complete(); } else { _rafHandle = requestAnimationFrame(_tick); }
      });
    }
    var anim = {
      get playState() { return _playState; },
      get currentTime() { return _currentTime; },
      set currentTime(v) { _currentTime = v; },
      finished: _finishedP,
      get ready() {
        return typeof Promise !== 'undefined' ? Promise.resolve(anim) : {then: function(f){f&&f(anim);return this;}, catch: function(){return this;}};
      },
      play: function() { if (_playState !== 'running') { _playState = 'running'; _scheduleRaf(); } },
      pause: function() { _playState = 'paused'; },
      cancel: function() { _playState = 'idle'; try{if(_oncancel)_oncancel({type:'cancel',target:anim});}catch(e){} },
      finish: function() { _complete(); },
      reverse: function() {},
      get onfinish() { return _onfinish; },
      set onfinish(fn) { _onfinish = fn; },
      get oncancel() { return _oncancel; },
      set oncancel(fn) { _oncancel = fn; },
      onremove: null, effect: null, timeline: null,
      addEventListener: function(type, fn) { if(type==='finish')_onfinish=fn; else if(type==='cancel')_oncancel=fn; },
      removeEventListener: function() {}
    };
    _scheduleRaf();
    return anim;
  }

  // Virtual element (created by createElement / createElementNS)
  function _makeVirtEl(tag) {
    var tagLower = tag.toLowerCase();
    var vid = '__virt_' + (++_seq);
    _virtAttrs[vid] = {tag: tagLower, attrs: {}};
    var el = {id: vid};
    Object.defineProperty(el, 'tagName', {
      get: function() { return tagLower; }
    });
    el.setAttribute = function(n, v) {
      _virtAttrs[vid].attrs[n] = String(v);
    };
    el.setAttributeNS = function(ns, n, v) {
      _virtAttrs[vid].attrs[n] = String(v);
      if (ns && ns.indexOf('xlink') >= 0) _virtAttrs[vid].attrs['xlink:' + n] = String(v);
    };
    el.getAttributeNames = function() { return Object.keys(_virtAttrs[vid].attrs); };
    el.getAttribute = function(n) {
      var v = _virtAttrs[vid].attrs[n];
      return v !== undefined ? v : null;
    };
    el.removeAttribute = function(n) { delete _virtAttrs[vid].attrs[n]; };
    el.hasAttribute = function(n) {
      return Object.prototype.hasOwnProperty.call(_virtAttrs[vid].attrs, n);
    };
    el.hasAttributeNS = function(ns, n) { return el.hasAttribute(n); };
    el.getAttributeNS = function(ns, n) { return el.getAttribute(n); };
    Object.defineProperty(el, 'href', { get: function() {
      return _makeSVGAnimatedString(
        function() { return _virtAttrs[vid].attrs['href'] || _virtAttrs[vid].attrs['xlink:href'] || ''; },
        function(v) { _virtAttrs[vid].attrs['href'] = v; }
      );
    }, configurable: true });
    Object.defineProperty(el, 'className', { get: function() {
      return _makeSVGAnimatedString(
        function() { return _virtAttrs[vid].attrs['class'] || ''; },
        function(v) { _virtAttrs[vid].attrs['class'] = v; }
      );
    }, configurable: true });
    el.addEventListener = function(type, fn) {};
    el.removeEventListener = function() {};
    el.dispatchEvent = function(evt) { return true; };
    el.querySelector = function(sel) { return null; };
    el.querySelectorAll = function(sel) { return []; };
    el.getBoundingClientRect = function() {
      return {x:0,y:0,width:0,height:0,top:0,left:0,right:0,bottom:0};
    };
    el.insertBefore = function(child, ref) { _handleInsert(el, child); return child; };
    el.appendChild = function(child) { _handleInsert(el, child); return child; };
    el.animate = function(keyframes, options) { return _makeAnimStub(null, keyframes, options, null); };
    el.removeChild = function(child) { return child; };
    el.replaceChild = function(newChild, oldChild) { return newChild; };
    el.replaceWith = function(node) {};
    el.getBBox = function() { return {x:0, y:0, width:0, height:0}; };
    // Compute arc length / point-at-length for virtual <path> elements
    // built by the SVGator player (Pt). The player emits a single
    // M-then-(L|Q|C) path per query; we parse that, subdivide the curve
    // into 100 samples, and use a cumulative-arc-length table.
    //
    // This MUST return real values (not {x:0,y:0}) — otherwise the
    // player's Ft() consumes the bogus point as truthy and computes
    // key.o = (0,0), producing translate(data.t.x, data.t.y) — i.e. the
    // SVGator "data.t-only" bug we used to mask with a Dart-side override.
    el.getTotalLength = function() { return _virtPathLength(vid); };
    el.getPointAtLength = function(d) { return _virtPathPointAt(vid, d); };
    el.matches = function(selector) { return false; };
    el.closest = function(selector) { return null; };
    el.contains = function(other) { return false; };
    Object.defineProperty(el, 'nextElementSibling', { get: function() { return null; } });
    Object.defineProperty(el, 'previousElementSibling', { get: function() { return null; } });
    Object.defineProperty(el, 'parentNode', { get: function() { return null; } });
    Object.defineProperty(el, 'children', { get: function() { return []; } });
    Object.defineProperty(el, 'nodeType', { get: function() { return 1; } });
    Object.defineProperty(el, 'nodeName', { get: function() { return tagLower.toUpperCase(); } });
    Object.defineProperty(el, 'ownerSVGElement', { get: function() { return null; } });
    Object.defineProperty(el, 'ownerDocument', { get: function() { return globalThis.document; } });
    Object.defineProperty(el, 'firstElementChild', { get: function() { return null; } });
    Object.defineProperty(el, 'lastElementChild',  { get: function() { return null; } });
    Object.defineProperty(el, 'childElementCount', { get: function() { return 0; } });
    // In-memory style for dynamically created elements
    var _virtStyle = {};
    Object.defineProperty(el, 'style', { get: function() {
      return new Proxy(_virtStyle, {
        get: function(t, p) {
          if (typeof p !== 'string') return undefined;
          if (p === 'cssText') return Object.keys(t).map(function(k){return k+':'+t[k];}).join(';');
          if (p === 'setProperty') return function(n, v) { t[n] = String(v); };
          if (p === 'getPropertyValue') return function(n) { return t[n] || ''; };
          if (p === 'removeProperty') return function(n) { delete t[n]; return ''; };
          return t[p] || '';
        },
        set: function(t, p, v) {
          if (typeof p !== 'string') return true;
          if (p === 'cssText') {
            String(v).split(';').forEach(function(r) {
              var i = r.indexOf(':');
              if (i > 0) t[r.slice(0,i).trim()] = r.slice(i+1).trim();
            });
          } else { t[p] = String(v); }
          return true;
        }
      });
    }});
    Object.defineProperty(el, 'classList', { get: function() {
      return {
        add: function(c) {
          var cur = (_virtAttrs[vid].attrs['class'] || '').split(/\s+/).filter(Boolean);
          if (cur.indexOf(c) < 0) cur.push(c);
          _virtAttrs[vid].attrs['class'] = cur.join(' ');
        },
        remove: function(c) {
          _virtAttrs[vid].attrs['class'] = (_virtAttrs[vid].attrs['class'] || '')
            .split(/\s+/).filter(function(x){return x !== c;}).join(' ');
        },
        toggle: function(c, force) {
          var cur = (_virtAttrs[vid].attrs['class'] || '').split(/\s+/).filter(Boolean);
          var i = cur.indexOf(c);
          if (force === true || (force === undefined && i < 0)) { if (i<0) cur.push(c); }
          else { if (i>=0) cur.splice(i,1); }
          _virtAttrs[vid].attrs['class'] = cur.join(' ');
          return cur.indexOf(c) >= 0;
        },
        contains: function(c) {
          return (_virtAttrs[vid].attrs['class'] || '').split(/\s+/).indexOf(c) >= 0;
        }
      };
    }});
    Object.defineProperty(el, 'textContent', {
      get: function() { return _virtAttrs[vid].attrs['__text'] || ''; },
      set: function(v) { _virtAttrs[vid].attrs['__text'] = String(v); }
    });
    Object.defineProperty(el, 'innerHTML', {
      get: function() { return ''; },
      set: function(v) {},
      configurable: true
    });
    Object.defineProperty(el, 'outerHTML', { get: function() { return ''; }, configurable: true });
    Object.defineProperty(el, 'dataset', { get: function() {
      return new Proxy({}, {
        get: function(t, k) { return _virtAttrs[vid].attrs['data-'+k] || undefined; },
        set: function(t, k, v) { _virtAttrs[vid].attrs['data-'+k] = String(v); return true; }
      });
    }});
    var _virtTL = _makeSVGTransformList(
      function(n) { return (_virtAttrs[vid] && _virtAttrs[vid].attrs[n]) || null; },
      function(n, v) { if (_virtAttrs[vid]) _virtAttrs[vid].attrs[n] = v; }
    );
    el.transform = { baseVal: _virtTL, animVal: _virtTL };
    el.getCTM = function() { return _makeSVGMatrix(); };
    el.getScreenCTM = function() { return _makeSVGMatrix(); };
    el.createSVGMatrix = function() { return _makeSVGMatrix(); };
    el.createSVGPoint = function() { return {x:0, y:0}; };
    el.createSVGTransform = function() { return _makeSVGTransform(); };
    el.createSVGTransformFromMatrix = function(m) { var t = _makeSVGTransform(); t.setMatrix(m); return t; };
    el.insertAdjacentHTML = function(pos, html) {};
    el.insertAdjacentElement = function(pos, node) { return node; };
    el.focus = function() {}; el.blur = function() {};
    el.scrollIntoView = function() {};
    el.getAttributeNode = function(n) {
      var v = el.getAttribute(n); return v !== null ? {name: n, value: v, specified: true} : null;
    };
    el.setAttributeNode = function(node) { if (node) el.setAttribute(node.name, node.value); };
    el.removeAttributeNode = function(node) { if (node) el.removeAttribute(node.name); };
    Object.defineProperty(el, 'namespaceURI', { get: function() { return 'http://www.w3.org/2000/svg'; } });
    Object.defineProperty(el, 'isConnected', { get: function() { return false; } });
    el.getRootNode = function() { return globalThis.document; };
    el.normalize = function() {};
    el.isEqualNode = function(o) { return false; };
    el.isSameNode = function(o) { return el === o; };
    Object.defineProperty(el, 'offsetWidth',  { get: function() { return 0; } });
    Object.defineProperty(el, 'offsetHeight', { get: function() { return 0; } });
    Object.defineProperty(el, 'offsetTop',    { get: function() { return 0; } });
    Object.defineProperty(el, 'offsetLeft',   { get: function() { return 0; } });
    Object.defineProperty(el, 'clientWidth',  { get: function() { return 0; } });
    Object.defineProperty(el, 'clientHeight', { get: function() { return 0; } });
    Object.defineProperty(el, 'scrollWidth',  { get: function() { return 0; } });
    Object.defineProperty(el, 'scrollHeight', { get: function() { return 0; } });
    el.scrollTop = 0; el.scrollLeft = 0;
    return el;
  }

  // Cache ensures the same JS object is returned for the same Dart node ID,
  // so JS-side properties (e.g. element.svgatorPlayer) survive across calls.
  var _elCache = {};

  // Real element (backed by Dart node with id)
  function _makeEl(id) {
    if (_elCache[id]) return _elCache[id];
    var el = {};
    _elCache[id] = el;
    Object.defineProperty(el, 'id', {
      get: function() { return id; },
      set: function(v) {
        try { sendMessage('setAttribute', JSON.stringify({id: id, name: 'id', value: String(v)})); } catch(e) {}
      },
      configurable: true
    });
    Object.defineProperty(el, 'tagName', { get: function() {
      try { return JSON.parse(sendMessage('getTagName', JSON.stringify({id: id}))); } catch(e) { return ''; }
    }});
    Object.defineProperty(el, 'style', { get: function() {
      return new Proxy({}, {
        get: function(t, p) {
          if (typeof p !== 'string') return undefined;
          if (p === 'cssText') return '';
          if (p === 'setProperty') return function(n, v) {
            sendMessage('setStyle', JSON.stringify({id: id, name: n, value: String(v)}));
          };
          if (p === 'getPropertyValue') return function(n) {
            try { return JSON.parse(sendMessage('getStyle', JSON.stringify({id: id, name: n}))) || ''; } catch(e) { return ''; }
          };
          if (p === 'removeProperty') return function(n) {
            sendMessage('setStyle', JSON.stringify({id: id, name: n, value: ''})); return '';
          };
          try { return JSON.parse(sendMessage('getStyle', JSON.stringify({id: id, name: p}))) || ''; } catch(e) { return ''; }
        },
        set: function(t, p, v) {
          if (typeof p !== 'string') return true;
          if (p === 'cssText') {
            String(v).split(';').forEach(function(rule) {
              var colon = rule.indexOf(':');
              if (colon > 0) {
                var n = rule.slice(0, colon).trim();
                var val = rule.slice(colon + 1).trim();
                if (n) sendMessage('setStyle', JSON.stringify({id: id, name: n, value: val}));
              }
            });
          } else {
            sendMessage('setStyle', JSON.stringify({id: id, name: p, value: String(v)}));
          }
          return true;
        }
      });
    }});
    el.getAttribute = function(n) {
      try { return JSON.parse(sendMessage('getAttribute', JSON.stringify({id: id, name: n}))); } catch(e) { return null; }
    };
    el.setAttribute = function(n, v) {
      sendMessage('setAttribute', JSON.stringify({id: id, name: n, value: String(v)}));
    };
    el.setAttributeNS = function(ns, n, v) {
      sendMessage('setAttribute', JSON.stringify({id: id, name: n, value: String(v)}));
      if (ns && ns.indexOf('xlink') >= 0) {
        sendMessage('setAttribute', JSON.stringify({id: id, name: 'xlink:' + n, value: String(v)}));
      }
    };
    el.getAttributeNames = function() {
      try { return JSON.parse(sendMessage('getAttributeNames', JSON.stringify({id: id}))); } catch(e) { return []; }
    };
    el.removeAttribute = function(n) {
      sendMessage('setAttribute', JSON.stringify({id: id, name: n, value: ''}));
    };
    el.hasAttribute = function(n) {
      try { return JSON.parse(sendMessage('getAttribute', JSON.stringify({id: id, name: n}))) !== null; }
      catch(e) { return false; }
    };
    el.hasAttributeNS = function(ns, n) { return el.hasAttribute(n); };
    el.getAttributeNS = function(ns, n) { return el.getAttribute(n); };
    Object.defineProperty(el, 'href', { get: function() {
      return _makeSVGAnimatedString(
        function() { return el.getAttribute('href') || el.getAttribute('xlink:href') || ''; },
        function(v) { el.setAttribute('href', v); }
      );
    }, configurable: true });
    Object.defineProperty(el, 'className', { get: function() {
      return _makeSVGAnimatedString(
        function() { return el.getAttribute('class') || ''; },
        function(v) { el.setAttribute('class', v); }
      );
    }, configurable: true });
    el.addEventListener = function(type, fn) {
      var key = 'el_' + (++_seq);
      _listeners[key] = fn;
      sendMessage('addEventListener', JSON.stringify({id: id, type: type, key: key}));
    };
    el.querySelector = function(sel) {
      try {
        var elId = JSON.parse(sendMessage('querySelector', JSON.stringify({id: id, selector: sel})));
        return elId ? _makeEl(elId) : null;
      } catch(e) { return null; }
    };
    el.querySelectorAll = function(sel) {
      try {
        var ids = JSON.parse(sendMessage('querySelectorAll', JSON.stringify({id: id, selector: sel})));
        return _makeNodeList((ids || []).map(function(i) { return _makeEl(i); }));
      } catch(e) { return []; }
    };
    el.insertBefore = function(child, ref) { _handleInsert(el, child); return child; };
    el.appendChild = function(child) { _handleInsert(el, child); return child; };
    Object.defineProperty(el, 'textContent', {
      get: function() {
        try { return JSON.parse(sendMessage('getAttribute', JSON.stringify({id: id, name: '__text'}))) || ''; } catch(e) { return ''; }
      },
      set: function(v) {
        sendMessage('setAttribute', JSON.stringify({id: id, name: '__text', value: String(v)}));
      }
    });
    Object.defineProperty(el, 'classList', { get: function() {
      return {
        add: function(cls) {
          var cur = el.getAttribute('class') || '';
          var parts = cur.split(/\s+/).filter(Boolean);
          if (parts.indexOf(cls) < 0) parts.push(cls);
          el.setAttribute('class', parts.join(' '));
        },
        remove: function(cls) {
          var cur = el.getAttribute('class') || '';
          el.setAttribute('class', cur.split(/\s+/).filter(function(c){ return c !== cls; }).join(' '));
        },
        toggle: function(cls, force) {
          var cur = el.getAttribute('class') || '';
          var parts = cur.split(/\s+/).filter(Boolean);
          var idx = parts.indexOf(cls);
          if (force === true || (force === undefined && idx < 0)) {
            if (idx < 0) parts.push(cls);
          } else {
            if (idx >= 0) parts.splice(idx, 1);
          }
          el.setAttribute('class', parts.join(' '));
          return parts.indexOf(cls) >= 0;
        },
        contains: function(cls) {
          var cur = el.getAttribute('class') || '';
          return cur.split(/\s+/).indexOf(cls) >= 0;
        },
        replace: function(oldCls, newCls) {
          var cur = el.getAttribute('class') || '';
          el.setAttribute('class', cur.split(/\s+/).map(function(c){ return c === oldCls ? newCls : c; }).join(' '));
        }
      };
    }});
    el.getElementById = function(childId) {
      try {
        var foundId = JSON.parse(sendMessage('getElementById', JSON.stringify({id: childId})));
        return foundId ? _makeEl(foundId) : null;
      } catch(e) { return null; }
    };
    el.getBoundingClientRect = function() {
      try {
        return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id})));
      } catch(e) {
        return {x:0, y:0, width:0, height:0, top:0, left:0, right:0, bottom:0};
      }
    };
    el.getComputedStyle = function(pseudo) {
      return globalThis.getComputedStyle(el, pseudo);
    };
    Object.defineProperty(el, 'innerHTML', {
      get: function() { return ''; },
      set: function(v) {
        var s = String(v);
        if (s.indexOf('<style') >= 0 || s.indexOf('{') >= 0) {
          try { sendMessage('injectCSS', JSON.stringify({html: s})); } catch(e) {}
        }
      },
      configurable: true
    });
    Object.defineProperty(el, 'outerHTML', {
      get: function() { return ''; },
      configurable: true
    });
    Object.defineProperty(el, 'dataset', { get: function() {
      return new Proxy({}, {
        get: function(t, k) {
          try { return JSON.parse(sendMessage('getAttribute', JSON.stringify({id: id, name: 'data-'+k}))); } catch(e) { return undefined; }
        },
        set: function(t, k, v) {
          try { sendMessage('setAttribute', JSON.stringify({id: id, name: 'data-'+k, value: String(v)})); } catch(e) {}
          return true;
        }
      });
    }});
    Object.defineProperty(el, 'nodeType', {
      get: function() { return 1; }, // ELEMENT_NODE
      configurable: true
    });
    Object.defineProperty(el, 'nodeName', {
      get: function() { return el.tagName.toUpperCase(); },
      configurable: true
    });
    Object.defineProperty(el, 'parentNode', { get: function() {
      try {
        var pid = JSON.parse(sendMessage('getParentId', JSON.stringify({id: id})));
        return pid ? _makeEl(pid) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'parentElement', { get: function() { return el.parentNode; } });
    Object.defineProperty(el, 'children', { get: function() {
      try {
        var ids = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: id})));
        return _makeNodeList((ids || []).map(function(i) { return _makeEl(i); }));
      } catch(e) { return []; }
    }});
    Object.defineProperty(el, 'childNodes', { get: function() { return el.children; } });
    el.dispatchEvent = function(evt) { return true; };
    el.removeEventListener = function() {};
    el.animate = function(keyframes, options) { return _makeAnimStub(id, keyframes, options, el); };
    el.removeChild = function(child) {
      try { sendMessage('removeChild', JSON.stringify({parentId: id, childId: child.id})); } catch(e) {}
      return child;
    };
    el.replaceChild = function(newChild, oldChild) {
      try { sendMessage('replaceChild', JSON.stringify({parentId: id, oldId: oldChild.id})); } catch(e) {}
      return oldChild;
    };
    el.replaceWith = function(node) {
      try {
        var p = el.parentNode;
        if (p) { p.insertBefore(node, el); el.remove(); }
      } catch(e) {}
    };
    el.remove = function() {
      try {
        var p = el.parentNode;
        if (p && p.id) sendMessage('removeChild', JSON.stringify({parentId: p.id, childId: id}));
      } catch(e) {}
    };
    el.getBBox = function() {
      try { return JSON.parse(sendMessage('getBBox', JSON.stringify({id: id}))); }
      catch(e) { return {x:0, y:0, width:0, height:0}; }
    };
    el.getTotalLength = function() {
      try { return JSON.parse(sendMessage('getTotalLength', JSON.stringify({id: id}))); }
      catch(e) { return 0; }
    };
    el.getPointAtLength = function(distance) {
      try { return JSON.parse(sendMessage('getPointAtLength', JSON.stringify({id: id, distance: distance}))); }
      catch(e) { return {x:0, y:0}; }
    };
    el.matches = function(selector) {
      try { return JSON.parse(sendMessage('matches', JSON.stringify({id: id, selector: selector}))); }
      catch(e) { return false; }
    };
    el.closest = function(selector) {
      try {
        var foundId = JSON.parse(sendMessage('closest', JSON.stringify({id: id, selector: selector})));
        return foundId ? _makeEl(foundId) : null;
      } catch(e) { return null; }
    };
    el.contains = function(other) {
      if (!other) return false;
      try { return JSON.parse(sendMessage('contains', JSON.stringify({parentId: id, childId: other.id}))); }
      catch(e) { return false; }
    };
    Object.defineProperty(el, 'nextElementSibling', { get: function() {
      try {
        var pid = JSON.parse(sendMessage('getParentId', JSON.stringify({id: id})));
        if (!pid) return null;
        var siblings = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: pid})));
        var idx = (siblings || []).indexOf(id);
        return idx >= 0 && idx + 1 < siblings.length ? _makeEl(siblings[idx + 1]) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'previousElementSibling', { get: function() {
      try {
        var pid = JSON.parse(sendMessage('getParentId', JSON.stringify({id: id})));
        if (!pid) return null;
        var siblings = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: pid})));
        var idx = (siblings || []).indexOf(id);
        return idx > 0 ? _makeEl(siblings[idx - 1]) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'firstElementChild', { get: function() {
      try {
        var ids = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: id})));
        return ids && ids.length > 0 ? _makeEl(ids[0]) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'lastElementChild', { get: function() {
      try {
        var ids = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: id})));
        return ids && ids.length > 0 ? _makeEl(ids[ids.length - 1]) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'childElementCount', { get: function() {
      try {
        var ids = JSON.parse(sendMessage('getChildrenIds', JSON.stringify({id: id})));
        return ids ? ids.length : 0;
      } catch(e) { return 0; }
    }});
    Object.defineProperty(el, 'ownerSVGElement', { get: function() {
      try {
        var rootId = JSON.parse(sendMessage('getRootId', JSON.stringify({})));
        return rootId ? _makeEl(rootId) : null;
      } catch(e) { return null; }
    }});
    Object.defineProperty(el, 'ownerDocument', { get: function() { return globalThis.document; } });
    el.prepend = function(child) { _handleInsert(el, child); return child; };
    el.append  = function(child) { _handleInsert(el, child); return child; };
    el.before  = function(child) { var p = el.parentNode; if (p) _handleInsert(p, child); return child; };
    el.after   = function(child) { var p = el.parentNode; if (p) _handleInsert(p, child); return child; };
    el.remove  = function() {};
    el.cloneNode = function(deep) { return _makeVirtEl(el.tagName || 'g'); };
    Object.defineProperty(el, 'transform', { get: function() {
      var tl = _makeSVGTransformList(
        function(n) {
          try { return JSON.parse(sendMessage('getAttribute', JSON.stringify({id: id, name: n}))); } catch(e) { return null; }
        },
        function(n, v) {
          try { sendMessage('setAttribute', JSON.stringify({id: id, name: n, value: String(v)})); } catch(e) {}
        }
      );
      return { baseVal: tl, animVal: tl };
    }, configurable: true});
    el.getCTM = function() {
      try {
        var list = _parseSVGTransformList(el.getAttribute('transform'));
        if (!list.length) return _makeSVGMatrix();
        var r = list[0].matrix;
        for (var i=1; i<list.length; i++) r = r.multiply(list[i].matrix);
        return r;
      } catch(e) { return _makeSVGMatrix(); }
    };
    el.getScreenCTM = function() { return el.getCTM(); };
    el.createSVGMatrix = function() { return _makeSVGMatrix(); };
    el.createSVGPoint = function() { return {x:0, y:0}; };
    el.createSVGTransform = function() { return _makeSVGTransform(); };
    el.createSVGTransformFromMatrix = function(m) { var t = _makeSVGTransform(); t.setMatrix(m); return t; };
    el.insertAdjacentHTML = function(pos, html) {
      try { sendMessage('injectCSS', JSON.stringify({html: html})); } catch(e) {}
    };
    el.insertAdjacentElement = function(pos, node) { _handleInsert(el, node); return node; };
    el.focus = function() {}; el.blur = function() {};
    el.scrollIntoView = function() {};
    // SVGAnimatedLength for all common numeric geometry attributes
    (function() {
      var _lenAttrs = ['x','y','cx','cy','r','rx','ry','width','height',
                       'x1','y1','x2','y2','dx','dy','fx','fy'];
      _lenAttrs.forEach(function(attr) {
        Object.defineProperty(el, attr, { get: function() {
          var aLen = {};
          Object.defineProperty(aLen, 'value', {
            get: function() { return parseFloat(el.getAttribute(attr)) || 0; },
            set: function(v) { el.setAttribute(attr, v); }
          });
          aLen.valueInSpecifiedUnits = parseFloat(el.getAttribute(attr)) || 0;
          aLen.unitType = 1;
          aLen.convertToSpecifiedUnits = function() {};
          aLen.newValueSpecifiedUnits = function(t, v) { el.setAttribute(attr, v); };
          return { baseVal: aLen, animVal: aLen };
        }, configurable: true });
      });
    })();
    // viewBox.baseVal — {x, y, width, height} parsed from viewBox attribute
    Object.defineProperty(el, 'viewBox', { get: function() {
      var vb = el.getAttribute('viewBox') || '';
      var parts = vb.trim().split(/[\s,]+/).map(Number);
      var bv = {
        x: parts[0]||0, y: parts[1]||0,
        width: parts[2]||0, height: parts[3]||0
      };
      return { baseVal: bv, animVal: bv };
    }, configurable: true });
    el.getAttributeNode = function(n) {
      var v = el.getAttribute(n); return v !== null ? {name: n, value: v, specified: true} : null;
    };
    el.setAttributeNode = function(node) { if (node) el.setAttribute(node.name, node.value); };
    el.removeAttributeNode = function(node) { if (node) el.removeAttribute(node.name); };
    Object.defineProperty(el, 'namespaceURI', { get: function() { return 'http://www.w3.org/2000/svg'; }, configurable: true });
    Object.defineProperty(el, 'isConnected', { get: function() { return true; }, configurable: true });
    el.getRootNode = function() { return globalThis.document; };
    el.normalize = function() {};
    el.isEqualNode = function(o) { return el === o; };
    el.isSameNode = function(o) { return el === o; };
    Object.defineProperty(el, 'offsetWidth',  { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).width || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'offsetHeight', { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).height || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'offsetTop',    { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).top || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'offsetLeft',   { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).left || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'clientWidth',  { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).width || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'clientHeight', { get: function() {
      try { return JSON.parse(sendMessage('getBoundingClientRect', JSON.stringify({id: id}))).height || 0; } catch(e) { return 0; }
    }, configurable: true });
    Object.defineProperty(el, 'scrollWidth',  { get: function() { return el.clientWidth; }, configurable: true });
    Object.defineProperty(el, 'scrollHeight', { get: function() { return el.clientHeight; }, configurable: true });
    el.scrollTop = 0; el.scrollLeft = 0;
    Object.defineProperty(el, 'outerHTML', { get: function() {
      try {
        var tag = el.tagName || 'g';
        var names = el.getAttributeNames();
        var attrs = names.map(function(n) { return n + '="' + (el.getAttribute(n)||'').replace(/"/g,'&quot;') + '"'; }).join(' ');
        return '<' + tag + (attrs ? ' ' + attrs : '') + '/>';
      } catch(e) { return ''; }
    }, configurable: true });
    Object.defineProperty(el, 'title', {
      get: function() { return el.getAttribute('title') || ''; },
      set: function(v) { el.setAttribute('title', v); },
      configurable: true
    });
    Object.defineProperty(el, 'hidden', {
      get: function() { return el.getAttribute('visibility') === 'hidden' || el.getAttribute('display') === 'none'; },
      set: function(v) { el.setAttribute('visibility', v ? 'hidden' : 'visible'); },
      configurable: true
    });
    el.tabIndex = -1;
    el.setPointerCapture = function() {};
    el.releasePointerCapture = function() {};
    el.hasPointerCapture = function() { return false; };
    el.getAnimations = function() { return []; };
    el.computedStyleMap = function() {
      return { get: function(p) { return {value: el.getAttribute(p) || ''}; } };
    };
    return el;
  }

  // Called by Dart to invoke a registered listener by key.
  // evtData is Date.now() for timers/rAF, or an event object for DOM events.
  globalThis._fireListener = function(key, evtData) {
    var fn = _listeners[key];
    if (fn) { try { fn(evtData !== undefined ? evtData : {}); } catch(e) { console.error('listener error [' + key + ']:', String(e)); } }
  };

  // NodeList wrapper — adds .item(n) and .forEach to plain arrays
  function _makeNodeList(arr) {
    arr.item = function(n) { return arr[n] !== undefined ? arr[n] : null; };
    if (!arr.forEach) arr.forEach = function(fn) { for (var i=0; i<arr.length; i++) fn(arr[i], i, arr); };
    return arr;
  }

  // Synthetic fallback parent for getElementsByTagName when DOM has no results
  var _synthParent = {
    insertBefore: function(child, ref) { _handleInsert(_synthParent, child); return child; },
    appendChild:  function(child) { _handleInsert(_synthParent, child); return child; }
  };

  // document
  globalThis.document = {
    getElementById: function(id) {
      try {
        var elId = JSON.parse(sendMessage('getElementById', JSON.stringify({id: id})));
        return elId ? _makeEl(elId) : null;
      } catch(e) { return null; }
    },
    querySelector: function(sel) {
      try {
        var elId = JSON.parse(sendMessage('querySelector', JSON.stringify({id: null, selector: sel})));
        return elId ? _makeEl(elId) : null;
      } catch(e) { return null; }
    },
    querySelectorAll: function(sel) {
      try {
        var ids = JSON.parse(sendMessage('querySelectorAll', JSON.stringify({id: null, selector: sel})));
        return _makeNodeList((ids || []).map(function(i) { return _makeEl(i); }));
      } catch(e) { return []; }
    },
    getElementsByTagName: function(tag) {
      try {
        var ids = JSON.parse(sendMessage('querySelectorAll', JSON.stringify({id: null, selector: tag})));
        var elems = _makeNodeList((ids || []).map(function(i) { return _makeEl(i); }));
        if (elems.length > 0) return elems;
      } catch(e) {}
      // Synthetic fallback: insertBefore on its parentNode still triggers _handleInsert
      return [{tagName: tag, parentNode: _synthParent, getAttribute: function(){return null;}, setAttribute: function(){}}];
    },
    addEventListener: function(type, fn) {
      var key = 'doc_' + (++_seq);
      _listeners[key] = fn;
      sendMessage('addWindowLoadListener', JSON.stringify({key: key}));
    },
    insertBefore: function(child, ref) { _handleInsert(document, child); return child; },
    appendChild:  function(child) { _handleInsert(document, child); return child; },
    createElementNS: function(ns, tag) { return _makeVirtEl(tag); },
    createElement:   function(tag)      { return _makeVirtEl(tag); },
    createTextNode:  function(text)     {
      var n = _makeVirtEl('#text');
      n.nodeType = 3; n.textContent = text || ''; n.data = n.textContent;
      return n;
    },
    createDocumentFragment: function() {
      var f = _makeVirtEl('#fragment');
      f.nodeType = 11; f.childNodes = [];
      f.appendChild = function(c) { f.childNodes.push(c); return c; };
      return f;
    },
    createComment: function(text) { var n = _makeVirtEl('#comment'); n.nodeType = 8; return n; },
    get documentElement() {
      try {
        var rootId = JSON.parse(sendMessage('getRootId', JSON.stringify({})));
        return rootId ? _makeEl(rootId) : null;
      } catch(e) { return null; }
    },
    get head() { return document.documentElement; },
    get body() { return document.documentElement; },
    get readyState() { return 'complete'; },
    get defaultView() { return globalThis.window; },
    get fonts() {
      var _r = typeof Promise !== 'undefined' ? Promise.resolve() :
        {then: function(f){f&&f();return this;}, catch: function(){return this;}};
      return {
        ready: _r, status: 'loaded',
        check: function() { return true; },
        load: function() { return _r; },
        forEach: function() {}, size: 0, has: function() { return false; },
        addEventListener: function() {}, removeEventListener: function() {}
      };
    },
    getElementsByClassName: function(cls) {
      try {
        var ids = JSON.parse(sendMessage('querySelectorAll', JSON.stringify({id: null, selector: '.' + cls.trim().split(/\s+/).join('.')})));
        return _makeNodeList((ids || []).map(function(i) { return _makeEl(i); }));
      } catch(e) { return []; }
    },
    getElementsByTagNameNS: function(ns, tag) { return document.getElementsByTagName(tag); },
    createAttribute: function(name) { return {name: name, value: '', specified: true}; },
    adoptNode: function(node) { return node; },
    importNode: function(node, deep) { return node; },
    get styleSheets() {
      var _rules = [];
      return [{
        cssRules: _rules,
        insertRule: function(rule, idx) {
          _rules.splice(idx !== undefined ? idx : _rules.length, 0, {cssText: rule});
          try {
            var m = rule.match(/^([^{]+)\{([^}]*)\}/);
            if (m) {
              var sel = m[1].trim(), decl = m[2];
              var ids = JSON.parse(sendMessage('querySelectorAll', JSON.stringify({id: null, selector: sel})));
              (ids || []).forEach(function(id) {
                decl.split(';').forEach(function(d) {
                  var kv = d.trim().split(':');
                  if (kv.length >= 2) sendMessage('setStyle', JSON.stringify({id: id, name: kv[0].trim(), value: kv.slice(1).join(':').trim()}));
                });
              });
            }
          } catch(e) {}
          return idx !== undefined ? idx : _rules.length - 1;
        },
        deleteRule: function(idx) { _rules.splice(idx, 1); }
      }];
    },
    get timeline() {
      return { currentTime: typeof performance !== 'undefined' ? performance.now() : Date.now(), duration: Infinity };
    },
    get implementation() {
      return {
        createHTMLDocument: function(title) { return document; },
        hasFeature: function() { return true; }
      };
    },
    write: function() {}, writeln: function() {}, open: function() {}, close: function() {}
  };

  // window
  globalThis.window = globalThis.window || {};
  globalThis.window.document = globalThis.document;
  globalThis.window.addEventListener = function(type, fn) {
    if (type === 'load' || type === 'DOMContentLoaded') {
      var key = 'win_' + (++_seq);
      _listeners[key] = fn;
      sendMessage('addWindowLoadListener', JSON.stringify({key: key}));
    }
    // Other event types (resize, scroll, etc.) are no-ops
  };
  globalThis.window.removeEventListener = function(type, fn) {};
  globalThis.window.dispatchEvent = function(evt) { return true; };
  globalThis.window.innerWidth = 800;
  globalThis.window.innerHeight = 600;
  globalThis.window.devicePixelRatio = 1;
  globalThis.window.scrollX = 0; globalThis.window.scrollY = 0;
  globalThis.window.pageXOffset = 0; globalThis.window.pageYOffset = 0;
  globalThis.window.screenX = 0; globalThis.window.screenY = 0;
  globalThis.window.location = { href: '', protocol: 'https:', host: 'localhost' };
  globalThis.window.matchMedia = function(query) {
    return {
      matches: false, media: query,
      addListener: function() {}, removeListener: function() {},
      addEventListener: function() {}, removeEventListener: function() {},
      dispatchEvent: function() { return true; }
    };
  };
  globalThis.window.history = { pushState: function(){}, replaceState: function(){}, back: function(){} };
  globalThis.window.navigator = { userAgent: 'Flutter', language: 'en', languages: ['en'] };
  globalThis.window.requestAnimationFrame = null; // set after rAF defined

  // Timers
  globalThis.setTimeout = function(fn, ms) {
    var id = ++_seq;
    var key = 'timer_' + id;
    _listeners[key] = fn;
    sendMessage('setTimeout', JSON.stringify({key: key, ms: ms || 0}));
    return id;
  };
  globalThis.clearTimeout = function(id) {
    var key = 'timer_' + id;
    sendMessage('clearTimeout', JSON.stringify({key: key}));
    delete _listeners[key];
  };
  globalThis.setInterval = function(fn, ms) {
    var id = ++_seq;
    var key = 'interval_' + id;
    _listeners[key] = fn;
    sendMessage('setInterval', JSON.stringify({key: key, ms: ms || 100}));
    return id;
  };
  globalThis.clearInterval = function(id) {
    var key = 'interval_' + id;
    sendMessage('clearInterval', JSON.stringify({key: key}));
    delete _listeners[key];
  };

  // requestAnimationFrame — driven by Flutter vsync via SchedulerBinding
  globalThis.requestAnimationFrame = function(fn) {
    var id = ++_seq;
    var key = 'raf_' + id;
    _listeners[key] = fn;
    try { sendMessage('requestRAF', JSON.stringify({key: key})); } catch(e) {}
    return id;
  };
  globalThis.cancelAnimationFrame = function(id) {
    var key = 'raf_' + id;
    delete _listeners[key];
    try { sendMessage('cancelRAF', JSON.stringify({key: key})); } catch(e) {}
  };
  globalThis.window.requestAnimationFrame = globalThis.requestAnimationFrame;
  globalThis.window.cancelAnimationFrame = globalThis.cancelAnimationFrame;

  // performance
  (function() {
    var _t0 = Date.now();
    var _marks = {}, _measures = [];
    globalThis.performance = {
      now: function() { return Date.now() - _t0; },
      mark: function(name) { _marks[name] = performance.now(); },
      measure: function(name, start, end) {
        var s = _marks[start] || 0, e = end ? (_marks[end] || performance.now()) : performance.now();
        _measures.push({name: name, startTime: s, duration: e - s, entryType: 'measure'});
      },
      getEntriesByName: function(name) { return _measures.filter(function(m){return m.name===name;}); },
      getEntriesByType: function(type) { return type==='measure' ? _measures.slice() : []; },
      getEntries: function() { return _measures.slice(); },
      clearMarks: function(name) { if(name) delete _marks[name]; else _marks={}; },
      clearMeasures: function(name) {
        _measures = name ? _measures.filter(function(m){return m.name!==name;}) : [];
      },
      timeOrigin: _t0
    };
    globalThis.window.performance = globalThis.performance;
  })();

  // console
  globalThis.console = {
    log:   function() { sendMessage('console.log',   JSON.stringify(Array.from(arguments).map(String))); },
    warn:  function() { sendMessage('console.warn',  JSON.stringify(Array.from(arguments).map(String))); },
    error: function() { sendMessage('console.error', JSON.stringify(Array.from(arguments).map(String))); },
    info:  function() { sendMessage('console.log',   JSON.stringify(Array.from(arguments).map(String))); },
    debug: function() { sendMessage('console.log',   JSON.stringify(Array.from(arguments).map(String))); },
    group: function() { sendMessage('console.log', JSON.stringify(['[group] ' + Array.from(arguments).map(String).join(' ')])); },
    groupCollapsed: function() { sendMessage('console.log', JSON.stringify(['[group] ' + Array.from(arguments).map(String).join(' ')])); },
    groupEnd: function() {},
    time: function(label) { sendMessage('console.log', JSON.stringify(['[time] ' + (label||'default')])); },
    timeEnd: function(label) { sendMessage('console.log', JSON.stringify(['[timeEnd] ' + (label||'default')])); },
    timeLog: function(label) {},
    trace: function() { sendMessage('console.log', JSON.stringify(['[trace] ' + Array.from(arguments).map(String).join(' ')])); },
    assert: function(cond) { if(!cond) sendMessage('console.error', JSON.stringify(['Assertion failed: ' + Array.from(arguments).slice(1).map(String).join(' ')])); },
    count: function() {},
    countReset: function() {},
    clear: function() {},
    table: function() {},
    dir: function() {}
  };

  // getComputedStyle — reads styles via the same bridge as el.style
  globalThis.getComputedStyle = function(el, pseudo) {
    if (!el) return {};
    var elId = el.id;
    return new Proxy({}, {
      get: function(t, p) {
        if (typeof p !== 'string') return undefined;
        if (p === 'getPropertyValue') return function(n) {
          try { return JSON.parse(sendMessage('getStyle', JSON.stringify({id: elId, name: n}))) || ''; } catch(e) { return ''; }
        };
        if (p === 'setProperty') return function(n, v) {
          try { sendMessage('setStyle', JSON.stringify({id: elId, name: n, value: String(v)})); } catch(e) {}
        };
        if (p === 'removeProperty') return function() { return ''; };
        if (p === 'length') return 0;
        try { return JSON.parse(sendMessage('getStyle', JSON.stringify({id: elId, name: p}))) || ''; } catch(e) { return ''; }
      }
    });
  };
  globalThis.window.getComputedStyle = globalThis.getComputedStyle;

  // Minimal DOM stubs
  globalThis.Event       = function(type, init) { this.type = type; this.preventDefault = function(){}; this.stopPropagation = function(){}; };
  globalThis.MouseEvent  = function(type, init) { this.type = type; if(init){this.clientX=init.clientX||0;this.clientY=init.clientY||0;} this.preventDefault=function(){}; };
  globalThis.CustomEvent = function(type, init) { this.type = type; this.detail = init && init.detail; this.preventDefault=function(){}; };
  globalThis.Node        = function() {};
  globalThis.Node.ELEMENT_NODE                = 1;
  globalThis.Node.ATTRIBUTE_NODE              = 2;
  globalThis.Node.TEXT_NODE                   = 3;
  globalThis.Node.CDATA_SECTION_NODE          = 4;
  globalThis.Node.COMMENT_NODE                = 8;
  globalThis.Node.DOCUMENT_NODE               = 9;
  globalThis.Node.DOCUMENT_FRAGMENT_NODE      = 11;
  globalThis.Element     = function() {};
  globalThis.HTMLElement = function() {};
  globalThis.SVGElement  = function() {};
  globalThis.SVGSVGElement = function() {};
  globalThis.SVGAnimationElement = function() {};
  // DOMMatrix — used by SVGator v6+ and modern animation engines
  globalThis.DOMMatrix = function(init) {
    var m = _makeSVGMatrix();
    if (typeof init === 'string' && init) {
      var list = _parseSVGTransformList(init);
      if (list.length) {
        var r = list[0].matrix;
        for (var i=1; i<list.length; i++) r = r.multiply(list[i].matrix);
        m = _makeSVGMatrix(r.a, r.b, r.c, r.d, r.e, r.f);
      }
    } else if (Array.isArray(init)) {
      if (init.length === 6) m = _makeSVGMatrix(init[0],init[1],init[2],init[3],init[4],init[5]);
    } else if (init && typeof init === 'object') {
      m = _makeSVGMatrix(init.a,init.b,init.c,init.d,init.e,init.f);
    }
    this.a = m.a; this.b = m.b; this.c = m.c; this.d = m.d; this.e = m.e; this.f = m.f;
    this.is2D = true; this.isIdentity = (m.a===1&&m.b===0&&m.c===0&&m.d===1&&m.e===0&&m.f===0);
    this.multiply = function(o) { return new DOMMatrix([m.a*o.a+m.c*o.b, m.b*o.a+m.d*o.b, m.a*o.c+m.c*o.d, m.b*o.c+m.d*o.d, m.a*o.e+m.c*o.f+m.e, m.b*o.e+m.d*o.f+m.f]); };
    this.inverse = function() { var r = m.inverse(); return new DOMMatrix([r.a,r.b,r.c,r.d,r.e,r.f]); };
    this.translate = function(tx, ty) { var r = m.translate(tx, ty); return new DOMMatrix([r.a,r.b,r.c,r.d,r.e,r.f]); };
    this.scale = function(s, sy, sz, ox, oy, oz) { var r = m.scaleNonUniform(s, sy!==undefined?sy:s); return new DOMMatrix([r.a,r.b,r.c,r.d,r.e,r.f]); };
    this.rotate = function(angle) { var r = m.rotate(angle); return new DOMMatrix([r.a,r.b,r.c,r.d,r.e,r.f]); };
    this.transformPoint = function(p) { return {x: m.a*p.x+m.c*p.y+m.e, y: m.b*p.x+m.d*p.y+m.f}; };
    this.toString = function() { return 'matrix('+m.a+','+m.b+','+m.c+','+m.d+','+m.e+','+m.f+')'; };
  };
  globalThis.DOMMatrix.fromMatrix = function(init) { return new DOMMatrix(init); };
  globalThis.DOMMatrix.fromFloat32Array = function(arr) { return new DOMMatrix(Array.from(arr)); };
  globalThis.DOMMatrix.fromFloat64Array = function(arr) { return new DOMMatrix(Array.from(arr)); };

  // DOMPoint
  globalThis.DOMPoint = function(x, y, z, w) {
    this.x = x || 0; this.y = y || 0; this.z = z || 0; this.w = w !== undefined ? w : 1;
    this.matrixTransform = function(m) {
      return new DOMPoint(m.a*this.x + m.c*this.y + m.e, m.b*this.x + m.d*this.y + m.f);
    };
  };
  globalThis.DOMPoint.fromPoint = function(p) { return new DOMPoint(p.x||0, p.y||0, p.z||0, p.w!==undefined?p.w:1); };

  // SVGTransform type constants
  globalThis.SVGTransform = {
    SVG_TRANSFORM_UNKNOWN:   0,
    SVG_TRANSFORM_MATRIX:    1,
    SVG_TRANSFORM_TRANSLATE: 2,
    SVG_TRANSFORM_SCALE:     3,
    SVG_TRANSFORM_ROTATE:    4,
    SVG_TRANSFORM_SKEWX:     5,
    SVG_TRANSFORM_SKEWY:     6
  };
  globalThis.MutationObserver = function(cb) {
    this.observe = function() {};
    this.disconnect = function() {};
    this.takeRecords = function() { return []; };
  };
  globalThis.ResizeObserver = function(cb) {
    this.observe = function() {};
    this.disconnect = function() {};
  };
  globalThis.IntersectionObserver = function(cb, opts) {
    this.observe = function() {};
    this.unobserve = function() {};
    this.disconnect = function() {};
    this.takeRecords = function() { return []; };
  };
  globalThis.CSS = {
    supports: function(prop, val) { return false; },
    escape: function(s) { return String(s).replace(/[^a-zA-Z0-9_-]/g, '\\$&'); }
  };
  globalThis.matchMedia = globalThis.window.matchMedia;

  // SVGLength type constants
  globalThis.SVGLength = {
    SVG_LENGTHTYPE_UNKNOWN:    0,
    SVG_LENGTHTYPE_NUMBER:     1,
    SVG_LENGTHTYPE_PERCENTAGE: 2,
    SVG_LENGTHTYPE_EMS:        3,
    SVG_LENGTHTYPE_EXS:        4,
    SVG_LENGTHTYPE_PX:         5,
    SVG_LENGTHTYPE_CM:         6,
    SVG_LENGTHTYPE_MM:         7,
    SVG_LENGTHTYPE_IN:         8,
    SVG_LENGTHTYPE_PT:         9,
    SVG_LENGTHTYPE_PC:         10
  };
  globalThis.SVGAngle = {
    SVG_ANGLETYPE_UNKNOWN:    0,
    SVG_ANGLETYPE_UNSPECIFIED: 1,
    SVG_ANGLETYPE_DEG:        2,
    SVG_ANGLETYPE_RAD:        3,
    SVG_ANGLETYPE_GRAD:       4
  };

  // queueMicrotask
  if (typeof queueMicrotask !== 'function') {
    globalThis.queueMicrotask = typeof Promise !== 'undefined'
      ? function(fn) { Promise.resolve().then(fn).catch(function(e) { setTimeout(function(){ throw e; }, 0); }); }
      : function(fn) { setTimeout(fn, 0); };
  }
  globalThis.window.queueMicrotask = globalThis.queueMicrotask;

  // window error handlers
  globalThis.window.onerror = null;
  globalThis.window.onunhandledrejection = null;
  globalThis.window.onload = null;
  globalThis.window.onDOMContentLoaded = null;

  // window open/close/print
  globalThis.window.open  = function() { return null; };
  globalThis.window.close = function() {};
  globalThis.window.print = function() {};
  globalThis.window.stop  = function() {};
  globalThis.window.focus = function() {};
  globalThis.window.blur  = function() {};
  globalThis.window.scroll   = function() {};
  globalThis.window.scrollTo = function() {};
  globalThis.window.scrollBy = function() {};
  globalThis.window.getSelection = function() { return null; };
  globalThis.window.screen = { width: 1280, height: 800, availWidth: 1280, availHeight: 800,
    colorDepth: 24, pixelDepth: 24, orientation: {type: 'landscape-primary', angle: 0} };

  // structuredClone — deep-copy via JSON round-trip
  if (typeof structuredClone !== 'function') {
    globalThis.structuredClone = function(obj) {
      try { return JSON.parse(JSON.stringify(obj)); } catch(e) { return obj; }
    };
  }

  // crypto.getRandomValues
  if (typeof crypto === 'undefined' || !crypto.getRandomValues) {
    var _seed = Date.now();
    globalThis.crypto = {
      getRandomValues: function(arr) {
        for (var i = 0; i < arr.length; i++) {
          _seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF;
          arr[i] = _seed & 0xFF;
        }
        return arr;
      },
      randomUUID: function() {
        var b = new Uint8Array(16);
        crypto.getRandomValues(b);
        b[6] = (b[6] & 0x0f) | 0x40;
        b[8] = (b[8] & 0x3f) | 0x80;
        var h = Array.from(b).map(function(x){return x.toString(16).padStart(2,'0');}).join('');
        return h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20);
      }
    };
    globalThis.window.crypto = globalThis.crypto;
  }

  // atob / btoa — needed by SVGator player; placed early so external scripts can use it
  if (typeof atob !== 'function') {
    var _b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    globalThis.atob = function(s) {
      s = String(s).replace(/[\s=]+$/, '');
      if (s.length % 4 === 1) throw new Error('Invalid base64');
      var result = '', buf = 0, bits = 0;
      for (var i = 0; i < s.length; i++) {
        var idx = _b64chars.indexOf(s[i]);
        if (idx === -1) throw new Error('Invalid base64 char: ' + s[i]);
        buf = (buf << 6) | idx;
        bits += 6;
        if (bits >= 8) { bits -= 8; result += String.fromCharCode((buf >> bits) & 0xFF); }
      }
      return result;
    };
    globalThis.btoa = function(s) {
      s = String(s);
      var result = '', i = 0;
      while (i < s.length) {
        var a = s.charCodeAt(i++), b = s.charCodeAt(i++) || 0, c = s.charCodeAt(i++) || 0;
        var idx1 = a >> 2, idx2 = ((a & 3) << 4) | (b >> 4),
            idx3 = ((b & 15) << 2) | (c >> 6), idx4 = c & 63;
        result += _b64chars[idx1] + _b64chars[idx2] +
                  (i > s.length + 1 ? '=' : _b64chars[idx3]) +
                  (i > s.length ? '=' : _b64chars[idx4]);
      }
      return result;
    };
    globalThis.window.atob = globalThis.atob;
    globalThis.window.btoa = globalThis.btoa;
  }

  // TextEncoder / TextDecoder — UTF-8 stubs
  if (typeof TextEncoder === 'undefined') {
    globalThis.TextEncoder = function() {};
    globalThis.TextEncoder.prototype.encode = function(str) {
      var bytes = [], s = String(str);
      for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c < 0x80) { bytes.push(c); }
        else if (c < 0x800) { bytes.push(0xC0|(c>>6)); bytes.push(0x80|(c&0x3F)); }
        else { bytes.push(0xE0|(c>>12)); bytes.push(0x80|((c>>6)&0x3F)); bytes.push(0x80|(c&0x3F)); }
      }
      return new Uint8Array(bytes);
    };
    globalThis.TextDecoder = function(enc) { this.encoding = enc || 'utf-8'; };
    globalThis.TextDecoder.prototype.decode = function(arr) {
      try {
        var bytes = Array.from ? Array.from(arr) : Array.prototype.slice.call(arr);
        var s = '';
        for (var i = 0; i < bytes.length; i++) {
          var b = bytes[i];
          if (b < 0x80) { s += String.fromCharCode(b); }
          else if ((b & 0xE0) === 0xC0) { s += String.fromCharCode(((b&0x1F)<<6)|(bytes[++i]&0x3F)); }
          else { s += String.fromCharCode(((b&0x0F)<<12)|((bytes[++i]&0x3F)<<6)|(bytes[++i]&0x3F)); }
        }
        return s;
      } catch(e) { return ''; }
    };
  }

  // URL constructor — must be defined BEFORE Blob (which calls URL.createObjectURL)
  if (typeof URL === 'undefined') {
    globalThis.URL = function(url, base) {
      var s = String(url);
      var qi = s.indexOf('?'), hi = s.indexOf('#');
      this.href = s;
      this.pathname = qi >= 0 ? s.slice(0, qi) : (hi >= 0 ? s.slice(0, hi) : s);
      this.search = qi >= 0 ? s.slice(qi, hi >= 0 ? hi : s.length) : '';
      this.hash = hi >= 0 ? s.slice(hi) : '';
      this.hostname = ''; this.host = ''; this.origin = ''; this.protocol = 'https:';
      this.port = ''; this.username = ''; this.password = '';
      this.searchParams = {
        get: function() { return null; }, set: function() {}, has: function() { return false; },
        append: function() {}, delete: function() {}, toString: function() { return ''; },
        forEach: function() {}
      };
      this.toString = function() { return this.href; };
    };
  }
  // Ensure URL.createObjectURL/revokeObjectURL always exist (even on a native URL)
  if (globalThis.URL && !globalThis.URL.createObjectURL) {
    globalThis.URL.createObjectURL = function() { return 'blob:localhost'; };
    globalThis.URL.revokeObjectURL = function() {};
  }

  // Blob / File stubs
  if (typeof Blob === 'undefined') {
    globalThis.Blob = function(parts, opts) {
      var content = (parts || []).map(String).join('');
      this.size = content.length;
      this.type = (opts && opts.type) || '';
      this._content = content;
      this.text = function() { return Promise.resolve ? Promise.resolve(content) : {then: function(f){f(content);return this;}}; };
      this.arrayBuffer = function() { return Promise.resolve ? Promise.resolve(new ArrayBuffer(0)) : {then: function(f){f(new ArrayBuffer(0));return this;}}; };
      this.slice = function(s, e, t) { return new Blob([content.slice(s,e)], {type: t||this.type}); };
    };
  }

  // AbortController / AbortSignal
  if (typeof AbortController === 'undefined') {
    globalThis.AbortSignal = function() { this.aborted = false; this.reason = undefined; this._listeners = []; };
    globalThis.AbortSignal.prototype.addEventListener = function(t, fn) { if (t==='abort') this._listeners.push(fn); };
    globalThis.AbortSignal.prototype.removeEventListener = function(t, fn) {};
    globalThis.AbortSignal.abort = function(r) { var s = new AbortSignal(); s.aborted = true; s.reason = r; return s; };
    globalThis.AbortController = function() {
      var self = this;
      this.signal = new AbortSignal();
      this.abort = function(r) {
        self.signal.aborted = true; self.signal.reason = r;
        self.signal._listeners.forEach(function(fn){ try{fn();}catch(e){} });
      };
    };
  }

  // WeakRef stub
  if (typeof WeakRef === 'undefined') {
    globalThis.WeakRef = function(target) { this._t = target; };
    globalThis.WeakRef.prototype.deref = function() { return this._t; };
    globalThis.FinalizationRegistry = function(cb) {};
    globalThis.FinalizationRegistry.prototype.register = function() {};
    globalThis.FinalizationRegistry.prototype.unregister = function() {};
  }

  // document.write/writeln — inject CSS if content looks like a style block
  globalThis.document.write = function(html) {
    if (String(html).indexOf('<style') >= 0 || String(html).indexOf('{') >= 0) {
      try { sendMessage('injectCSS', JSON.stringify({html: String(html)})); } catch(e) {}
    }
  };
  globalThis.document.writeln = globalThis.document.write;
  globalThis.document.open  = function() {};
  globalThis.document.close = function() {};

  // fetch — stub; real HTTP goes through Dart loadExternalScript handler
  if (typeof Promise !== 'undefined') {
    globalThis.fetch = function(url, opts) {
      return Promise.reject(new Error('fetch not available in SVG bridge'));
    };
    globalThis.window.fetch = globalThis.fetch;
  }

  // localStorage / sessionStorage — in-memory stubs
  (function() {
    function _makeStorage() {
      var d = {};
      return {
        getItem: function(k) { return d.hasOwnProperty(String(k)) ? d[k] : null; },
        setItem: function(k, v) { d[String(k)] = String(v); },
        removeItem: function(k) { delete d[String(k)]; },
        clear: function() { d = {}; },
        key: function(i) { var ks = Object.keys(d); return i < ks.length ? ks[i] : null; },
        get length() { return Object.keys(d).length; }
      };
    }
    globalThis.localStorage = _makeStorage();
    globalThis.sessionStorage = _makeStorage();
  })();

  // document.createRange — basic Range stub
  globalThis.document.createRange = function() {
    return {
      setStart: function(){}, setEnd: function(){}, setStartBefore: function(){}, setEndAfter: function(){},
      selectNode: function(){}, selectNodeContents: function(){},
      collapse: function(){}, cloneRange: function(){ return document.createRange(); },
      deleteContents: function(){}, extractContents: function(){ return document.createDocumentFragment(); },
      insertNode: function(){}, surroundContents: function(){},
      commonAncestorContainer: document.documentElement,
      collapsed: true, startOffset: 0, endOffset: 0,
      getBoundingClientRect: function(){ return {top:0,left:0,right:0,bottom:0,width:0,height:0}; },
      getClientRects: function(){ return []; },
      toString: function(){ return ''; }
    };
  };

  // document.elementFromPoint
  globalThis.document.elementFromPoint = function(x, y) { return document.documentElement; };
  globalThis.document.elementsFromPoint = function(x, y) { return [document.documentElement]; };
  globalThis.document.caretRangeFromPoint = function(x, y) { return document.createRange(); };

  // window.visualViewport
  globalThis.window.visualViewport = {
    width: 800, height: 600, offsetLeft: 0, offsetTop: 0,
    pageLeft: 0, pageTop: 0, scale: 1,
    addEventListener: function(){}, removeEventListener: function(){}
  };

  // Symbol.iterator polyfill for for-of on NodeList/HTMLCollection results
  if (typeof Symbol !== 'undefined' && Symbol.iterator && !Array.prototype[Symbol.iterator]) {
    Array.prototype[Symbol.iterator] = function() {
      var i = 0, arr = this;
      return { next: function() { return i < arr.length ? {value: arr[i++], done: false} : {done: true}; } };
    };
  }

  // SVGNumber / SVGNumberList stubs
  globalThis.SVGNumber = function() { this.value = 0; };
  globalThis.SVGStringList = function() { this.length = 0; this.appendItem=function(){}; this.getItem=function(){return '';}; };

  // requestIdleCallback — delegates to a short timeout
  globalThis.requestIdleCallback = function(fn, opts) {
    return globalThis.setTimeout(function() {
      fn({timeRemaining: function() { return 50; }, didTimeout: false});
    }, (opts && opts.timeout) ? Math.min(opts.timeout, 50) : 1);
  };
  globalThis.cancelIdleCallback = globalThis.clearTimeout;
  globalThis.window.requestIdleCallback = globalThis.requestIdleCallback;
  globalThis.window.cancelIdleCallback = globalThis.cancelIdleCallback;

  // Ensure Array.from is available (QuickJS compat)
  if (typeof Array.from !== 'function') {
    Array.from = function(iterable) {
      return Array.prototype.slice.call(iterable);
    };
  }

  // Object.assign polyfill
  if (typeof Object.assign !== 'function') {
    Object.assign = function(target) {
      for (var i = 1; i < arguments.length; i++) {
        var src = arguments[i];
        if (src) for (var k in src) if (Object.prototype.hasOwnProperty.call(src, k)) target[k] = src[k];
      }
      return target;
    };
  }

  // Number static methods polyfill (QuickJS compat)
  Number.isFinite  = Number.isFinite  || function(v) { return typeof v === 'number' && isFinite(v); };
  Number.isNaN     = Number.isNaN     || function(v) { return typeof v === 'number' && isNaN(v); };
  Number.isInteger = Number.isInteger || function(v) { return typeof v === 'number' && isFinite(v) && Math.floor(v) === v; };
  Number.parseInt  = Number.parseInt  || parseInt;
  Number.parseFloat= Number.parseFloat|| parseFloat;
  Number.EPSILON   = Number.EPSILON   !== undefined ? Number.EPSILON : 2.220446049250313e-16;

  // Object.entries / Object.values / Object.fromEntries polyfills
  if (typeof Object.entries !== 'function') {
    Object.entries = function(obj) {
      return Object.keys(obj).map(function(k) { return [k, obj[k]]; });
    };
  }
  if (typeof Object.values !== 'function') {
    Object.values = function(obj) {
      return Object.keys(obj).map(function(k) { return obj[k]; });
    };
  }
  if (typeof Object.fromEntries !== 'function') {
    Object.fromEntries = function(entries) {
      var obj = {};
      var arr = Array.isArray(entries) ? entries : Array.from(entries);
      for (var i = 0; i < arr.length; i++) { obj[arr[i][0]] = arr[i][1]; }
      return obj;
    };
  }

  // Array polyfills
  if (typeof Array.isArray !== 'function') {
    Array.isArray = function(v) { return Object.prototype.toString.call(v) === '[object Array]'; };
  }
  if (!Array.prototype.flat) {
    Array.prototype.flat = function(depth) {
      var d = depth === undefined ? 1 : depth;
      return d > 0 ? this.reduce(function(a, v) { return a.concat(Array.isArray(v) ? v.flat(d-1) : [v]); }, []) : this.slice();
    };
  }
  if (!Array.prototype.flatMap) {
    Array.prototype.flatMap = function(fn) { return this.map(fn).flat(1); };
  }
  if (!Array.prototype.findIndex) {
    Array.prototype.findIndex = function(fn) {
      for (var i = 0; i < this.length; i++) { if (fn(this[i], i, this)) return i; }
      return -1;
    };
  }
  if (!Array.prototype.fill) {
    Array.prototype.fill = function(v, s, e) {
      var start = s || 0, end = e !== undefined ? e : this.length;
      for (var i = start; i < end; i++) { this[i] = v; }
      return this;
    };
  }

  // String polyfills
  if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(s, p) { return this.indexOf(s, p||0) === (p||0); };
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(s) { return this.slice(-s.length) === s; };
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(s, p) { return this.indexOf(s, p||0) !== -1; };
  }
  if (!String.prototype.repeat) {
    String.prototype.repeat = function(n) {
      var r = '';
      for (var i = 0; i < n; i++) { r += this; }
      return r;
    };
  }
  if (!String.prototype.padStart) {
    String.prototype.padStart = function(len, fill) {
      var s = String(this), pad = fill !== undefined ? String(fill) : ' ';
      while (s.length < len) { s = pad + s; }
      return s.slice(-(len));
    };
  }
  if (!String.prototype.padEnd) {
    String.prototype.padEnd = function(len, fill) {
      var s = String(this), pad = fill !== undefined ? String(fill) : ' ';
      while (s.length < len) { s = s + pad; }
      return s.slice(0, len);
    };
  }
  if (!String.prototype.trimStart) {
    String.prototype.trimStart = function() { return this.replace(/^\s+/, ''); };
  }
  if (!String.prototype.trimEnd) {
    String.prototype.trimEnd = function() { return this.replace(/\s+$/, ''); };
  }
  if (!String.prototype.replaceAll) {
    String.prototype.replaceAll = function(s, r) { return this.split(s).join(r); };
  }

})();
''';

  void _injectPolyfill() {
    _eval(_polyfill, label: 'polyfill');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Executes one JS script block in the runtime context.
  void executeScript(String code) {
    _eval(code, label: 'script');
  }

  /// Call once after all inline scripts have been executed.
  /// Completes [externalScriptsLoaded] immediately if no external scripts
  /// were injected, or after the last fetch finishes.
  void onInlinesDone() {
    _inlinesDone = true;
    _maybeCompleteExternal();
  }

  /// Fires all window/document 'load' listeners (call after all scripts run).
  void fireLoadEvents() {
    for (final key in _loadListenerKeys) {
      _fireListener(key);
    }
  }

  /// Dispatch an inline attribute handler (e.g. onclick="...") for [elementId].
  void dispatchInlineHandler(String elementId, String handlerCode) {
    _runtime.evaluate(
      '''(function() {
  var el = document.getElementById(${jsonEncode(elementId)});
  try {
    var fn = new Function('event', ${jsonEncode(handlerCode)});
    fn.call(el, {type: 'event', target: el, currentTarget: el, preventDefault: function(){}, stopPropagation: function(){}});
  } catch(e) { console.error('inline handler:', String(e)); }
})();''',
    );
  }

  /// Evaluate arbitrary JS in the bridge's runtime — used by the debug
  /// viewer to drive `svg.svgatorPlayer.seekTo(t)` from outside.
  /// Returns the string result, or `null` if evaluation threw.
  String? evaluateForDebug(String code) {
    try {
      final result = _runtime.evaluate(code);
      if (result.isError) {
        developer.log('debug-eval error: ${result.stringResult}',
            name: 'SVG/JS');
        return null;
      }
      return result.stringResult;
    } catch (e) {
      developer.log('debug-eval threw: $e', name: 'SVG/JS');
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _rafKeys.clear();
    if (!_externalCompleter.isCompleted) {
      _externalCompleter.complete();
    }
    _runtime.dispose();
  }

  void _scheduleRafFrame() {
    if (_rafFrameScheduled || _disposed) return;
    _rafFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onRafFrame);
  }

  void _onRafFrame(Duration timestamp) {
    _rafFrameScheduled = false;
    if (_disposed || _rafKeys.isEmpty) return;
    final keys = List<String>.from(_rafKeys);
    _rafKeys.clear();
    for (final key in keys) {
      _fireListener(key);
    }
    // If JS callbacks re-registered new rAF callbacks, schedule another frame.
    if (_rafKeys.isNotEmpty) _scheduleRafFrame();
  }

  void _applyCssToDocument(String cssText) {
    if (cssText.isEmpty) return;
    final rules = CssParser.parseSelectorRules(cssText);
    var changed = false;
    for (final rule in rules) {
      final nodes = _querySelectorAll(_document.root, rule.selector);
      for (final node in nodes) {
        for (final entry in rule.declarations.entries) {
          _setAttr(node, entry.key, entry.value);
          changed = true;
        }
      }
    }
    if (changed) _repaint();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _fireListener(String key) {
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) return;
    // Pass performance.now() so rAF callbacks receive a monotonic relative timestamp,
    // matching browser behaviour (SVGator stores startTime via performance.now() at init).
    _eval(
      'if(typeof _fireListener==="function")_fireListener("$key",performance.now());',
      label: 'fire:$key',
    );
  }

  void _eval(String code, {required String label}) {
    try {
      final result = _runtime.evaluate(code);
      if (result.isError) {
        developer.log('SVG/JS [$label] JS error: ${result.stringResult}', name: 'SVG/JS');
        // ignore: avoid_print
        print('[SVG/JS] JS error [$label]: ${result.stringResult}');
      }
    } catch (e) {
      developer.log('SVG/JS [$label]: $e', name: 'SVG/JS');
      // ignore: avoid_print
      print('[SVG/JS] eval error [$label]: $e');
    }
  }

  void _setAttr(SvgNode node, String name, String value) {
    final type = _inferType(name);
    node.setAttribute(name, value, type: type, rawValue: value);
    if (name == 'class') {
      node.className = value.isEmpty ? null : value;
    }
    node.cachedPicture?.dispose();
    node.cachedPicture = null;
  }

  // ── Selector helpers ──────────────────────────────────────────────────────

  SvgNode? _querySelector(SvgNode root, String selector) {
    return _querySelectorAll(root, selector).firstOrNull;
  }

  List<SvgNode> _querySelectorAll(SvgNode root, String selector) {
    final sel = selector.trim();
    if (sel.isEmpty) return [];

    // Comma-separated list: 'path, rect, .cls'
    if (sel.contains(',')) {
      final seen = <String?>{};
      return sel
          .split(',')
          .expand((s) => _querySelectorAll(root, s.trim()))
          .where((n) => seen.add(n.id))
          .toList();
    }

    // [attr], [attr="val"], [attr*="val"], [attr^="val"], [attr$="val"]
    if (sel.startsWith('[') && sel.endsWith(']')) {
      return _queryByAttr(root, sel.substring(1, sel.length - 1));
    }

    // tag#id
    final hashIdx = sel.indexOf('#');
    if (hashIdx > 0) {
      final tag = sel.substring(0, hashIdx).trim();
      final id = sel.substring(hashIdx + 1).trim();
      final node = root.findById(id);
      if (node != null && (tag.isEmpty || node.tagName == tag)) return [node];
      return [];
    }

    // tag.class
    final dotIdx = sel.indexOf('.');
    if (dotIdx > 0) {
      final tag = sel.substring(0, dotIdx).trim();
      final cls = sel.substring(dotIdx + 1).trim();
      return root.findByClass(cls).where((n) => n.tagName == tag).toList();
    }

    if (sel.startsWith('#')) {
      final n = root.findById(sel.substring(1));
      return n != null ? [n] : [];
    }
    if (sel.startsWith('.')) return root.findByClass(sel.substring(1));
    return root.findByTag(sel);
  }

  // Handles inner content of [...] selectors
  List<SvgNode> _queryByAttr(SvgNode root, String inner) {
    String attr;
    String? value;
    String op = '=';

    for (final o in ['*=', '^=', r'$=', '~=', '=']) {
      final idx = inner.indexOf(o);
      if (idx > 0) {
        attr = inner.substring(0, idx).trim();
        op = o;
        value = inner
            .substring(idx + o.length)
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '');
        return _walkNodes(root).where((n) {
          final v = n.getAttributeValue(attr)?.toString() ?? '';
          switch (op) {
            case '=':  return v == value;
            case '*=': return v.contains(value!);
            case '^=': return v.startsWith(value!);
            case r'$=': return v.endsWith(value!);
            case '~=': return v.split(' ').contains(value);
            default:   return false;
          }
        }).toList();
      }
    }
    // [attr] — has attribute
    attr = inner.trim();
    return _walkNodes(root)
        .where((n) => n.getAttributeValue(attr) != null)
        .toList();
  }

  static Iterable<SvgNode> _walkNodes(SvgNode root) sync* {
    yield root;
    for (final child in root.children) {
      yield* _walkNodes(child);
    }
  }

  // ── Attribute type inference ───────────────────────────────────────────────

  static SvgAttributeType _inferType(String name) {
    switch (name) {
      case 'fill':
      case 'stroke':
      case 'stop-color':
      case 'color':
      case 'flood-color':
      case 'lighting-color':
        return SvgAttributeType.color;
      case 'opacity':
      case 'fill-opacity':
      case 'stroke-opacity':
      case 'stop-opacity':
      case 'flood-opacity':
        return SvgAttributeType.number;
      case 'transform':
        return SvgAttributeType.transform;
      case 'd':
        return SvgAttributeType.path;
      case 'stroke-dasharray':
        return SvgAttributeType.list;
      default:
        const lengthAttrs = {
          'x', 'y', 'cx', 'cy', 'r', 'rx', 'ry',
          'width', 'height', 'x1', 'y1', 'x2', 'y2',
          'stroke-width', 'font-size',
        };
        return lengthAttrs.contains(name)
            ? SvgAttributeType.length
            : SvgAttributeType.string;
    }
  }

  static String _camelToKebab(String s) =>
      s.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '-${m.group(0)!.toLowerCase()}');

  static double? _parseAttrDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[a-zA-Z%\s]'), ''));
  }

  // ── Geometry helpers ────────────────────────────────────────────────────

  ui.Rect _computeBBox(SvgNode node) {
    final a = node.getAttributeValue;
    double? n(String k) => _parseAttrDouble(a(k)?.toString());
    switch (node.tagName) {
      case 'rect':
        final x = n('x') ?? 0; final y = n('y') ?? 0;
        final w = n('width') ?? 0; final h = n('height') ?? 0;
        return ui.Rect.fromLTWH(x, y, w, h);
      case 'circle':
        final cx = n('cx') ?? 0; final cy = n('cy') ?? 0; final r = n('r') ?? 0;
        return ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r);
      case 'ellipse':
        final cx = n('cx') ?? 0; final cy = n('cy') ?? 0;
        final rx = n('rx') ?? 0; final ry = n('ry') ?? 0;
        return ui.Rect.fromCenter(center: ui.Offset(cx, cy), width: rx * 2, height: ry * 2);
      case 'line':
        final x1 = n('x1') ?? 0; final y1 = n('y1') ?? 0;
        final x2 = n('x2') ?? 0; final y2 = n('y2') ?? 0;
        return ui.Rect.fromPoints(ui.Offset(x1, y1), ui.Offset(x2, y2));
      case 'polyline':
      case 'polygon':
        final pts = _parsePointsList(a('points')?.toString() ?? '');
        if (pts.isEmpty) return ui.Rect.zero;
        var minX = pts[0].dx, maxX = pts[0].dx, minY = pts[0].dy, maxY = pts[0].dy;
        for (final p in pts) {
          if (p.dx < minX) minX = p.dx; if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy; if (p.dy > maxY) maxY = p.dy;
        }
        return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
      case 'path':
        final d = a('d')?.toString() ?? '';
        if (d.isNotEmpty) {
          final path = _buildFlutterPath(d);
          if (path != null) return path.getBounds();
        }
        return ui.Rect.zero;
      default:
        final w = n('width'); final h = n('height');
        if (w != null && h != null) return ui.Rect.fromLTWH(0, 0, w, h);
        final vb = a('viewBox')?.toString() ?? '';
        final parts = vb.trim().split(RegExp(r'[\s,]+'));
        if (parts.length >= 4) {
          return ui.Rect.fromLTWH(
            double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0,
            double.tryParse(parts[2]) ?? 0, double.tryParse(parts[3]) ?? 0,
          );
        }
        return ui.Rect.zero;
    }
  }

  double _computeTotalLength(SvgNode node) {
    final path = _nodeToFlutterPath(node);
    if (path == null) return 0;
    double total = 0;
    for (final m in path.computeMetrics()) { total += m.length; }
    return total;
  }

  ui.Offset _computePointAtLength(SvgNode node, double distance) {
    final path = _nodeToFlutterPath(node);
    if (path == null) return ui.Offset.zero;
    double remaining = distance;
    for (final m in path.computeMetrics()) {
      if (remaining <= m.length) {
        final tangent = m.getTangentForOffset(remaining);
        return tangent?.position ?? ui.Offset.zero;
      }
      remaining -= m.length;
    }
    // Past end: return last point
    for (final m in path.computeMetrics()) {
      final tangent = m.getTangentForOffset(m.length);
      if (tangent != null) return tangent.position;
    }
    return ui.Offset.zero;
  }

  ui.Path? _nodeToFlutterPath(SvgNode node) {
    final a = node.getAttributeValue;
    double? n(String k) => _parseAttrDouble(a(k)?.toString());
    switch (node.tagName) {
      case 'path':
        return _buildFlutterPath(a('d')?.toString() ?? '');
      case 'line':
        return ui.Path()
          ..moveTo(n('x1') ?? 0, n('y1') ?? 0)
          ..lineTo(n('x2') ?? 0, n('y2') ?? 0);
      case 'polyline':
      case 'polygon':
        final pts = _parsePointsList(a('points')?.toString() ?? '');
        if (pts.length < 2) return null;
        final p = ui.Path()..moveTo(pts[0].dx, pts[0].dy);
        for (var i = 1; i < pts.length; i++) { p.lineTo(pts[i].dx, pts[i].dy); }
        if (node.tagName == 'polygon') p.close();
        return p;
      case 'rect':
        final x = n('x') ?? 0; final y = n('y') ?? 0;
        final w = n('width') ?? 0; final h = n('height') ?? 0;
        return ui.Path()..addRect(ui.Rect.fromLTWH(x, y, w, h));
      case 'circle':
        final cx = n('cx') ?? 0; final cy = n('cy') ?? 0; final r = n('r') ?? 0;
        return ui.Path()..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = n('cx') ?? 0; final cy = n('cy') ?? 0;
        final rx = n('rx') ?? 0; final ry = n('ry') ?? 0;
        return ui.Path()..addOval(ui.Rect.fromCenter(center: ui.Offset(cx, cy), width: rx*2, height: ry*2));
      default:
        return null;
    }
  }

  ui.Path? _buildFlutterPath(String d) {
    if (d.isEmpty) return null;
    List<PathCommand> commands;
    try { commands = PathParser().parse(d); } catch (_) { return null; }
    if (commands.isEmpty) return null;
    final path = ui.Path();
    double cx = 0, cy = 0, sx = 0, sy = 0;
    PathCommand? prev;
    for (final cmd in commands) {
      final abs = cmd.toAbsolute(cx, cy);
      switch (abs) {
        case MoveToCommand(:final x, :final y):
          path.moveTo(x, y); cx = x; cy = y; sx = x; sy = y;
        case LineToCommand(:final x, :final y):
          path.lineTo(x, y); cx = x; cy = y;
        case HorizontalLineToCommand(:final x):
          path.lineTo(x, cy); cx = x;
        case VerticalLineToCommand(:final y):
          path.lineTo(cx, y); cy = y;
        case CubicBezierCommand(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          path.cubicTo(x1, y1, x2, y2, x, y); cx = x; cy = y;
        case SmoothCubicBezierCommand():
          final c = abs.toCubicBezier(currentX: cx, currentY: cy, previousCommand: prev);
          path.cubicTo(c.x1, c.y1, c.x2, c.y2, c.x, c.y); cx = c.x; cy = c.y;
        case QuadraticBezierCommand(:final x1, :final y1, :final x, :final y):
          path.quadraticBezierTo(x1, y1, x, y); cx = x; cy = y;
        case SmoothQuadraticBezierCommand():
          final q = abs.toQuadraticBezier(currentX: cx, currentY: cy, previousCommand: prev);
          path.quadraticBezierTo(q.x1, q.y1, q.x, q.y); cx = q.x; cy = q.y;
        case ArcCommand():
          final arc = abs;
          final rx = arc.rx.abs(); final ry = arc.ry.abs();
          if (rx == 0 || ry == 0) { path.lineTo(arc.x, arc.y); }
          else {
            path.arcToPoint(
              ui.Offset(arc.x, arc.y),
              radius: ui.Radius.elliptical(rx, ry),
              rotation: arc.rotation * (3.141592653589793 / 180),
              largeArc: arc.largeArc,
              clockwise: arc.sweep,
            );
          }
          cx = arc.x; cy = arc.y;
        case ClosePathCommand():
          path.close(); cx = sx; cy = sy;
        default: break;
      }
      prev = abs;
    }
    return path;
  }

  static List<ui.Offset> _parsePointsList(String points) {
    final nums = points.trim().split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s)).whereType<double>().toList();
    final result = <ui.Offset>[];
    for (var i = 0; i + 1 < nums.length; i += 2) {
      result.add(ui.Offset(nums[i], nums[i + 1]));
    }
    return result;
  }
}
