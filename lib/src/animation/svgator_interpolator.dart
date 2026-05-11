/// SVGator animation data interpolator.
///
/// Replaces the JS-side SVGator player's bezier-path interpolation with a
/// Dart-side equivalent so we don't depend on QuickJS-vs-V8 math parity.
///
/// **Background.** SVGator exports SVGs with an inline `<script>` that
/// pushes per-element animation data into `window.__SVGATOR_PLAYER__[hash]`
/// and triggers a network fetch of `cdn.svgator.com/.../<hash>.js`. That
/// external player ticks via `requestAnimationFrame`, computes each
/// element's `transform`, `opacity`, `fill`, etc. at the current time, and
/// writes the result via `setAttribute`. In our flutter_js runtime
/// (QuickJS) the player produces wrong values for `cusp`-typed keyframes
/// with control points — observed via trace diff against real Chrome.
///
/// **What this file does.** Re-implements the same interpolation in Dart:
///
/// * Parses the harvested animation data into typed structures.
/// * Implements cubic-bezier path interpolation for `corner` and `cusp`
///   keyframes (P0 / P1 = `key0.end` / P2 = `key1.start` / P3).
/// * Implements cubic-bezier easing per keyframe (the CSS-style
///   `cubic-bezier(x1, y1, x2, y2)` curve stored as `e: [...]`).
/// * Exposes [SvgatorTransformTrack.transformAt] /
///   [SvgatorOpacityTrack.valueAt] for the bridge to call on every tick
///   or `setAttribute` interception.
///
/// We deliberately keep the original SVGator player running for things we
/// don't reimplement (e.g. filter/inner-shadow chain edits); we just
/// substitute *our* computed values whenever the player tries to write a
/// `transform` or `opacity` for an element we know about.
library;

import 'dart:math' as math;

// ── Keyframe data ───────────────────────────────────────────────────────────

/// One position keyframe used by the `transform.keys.o` (origin / motion)
/// track. SVGator stores positions, not deltas — the actual translation
/// applied to the element is `data.t + this.position`.
class SvgatorOriginKeyframe {
  const SvgatorOriginKeyframe({
    required this.timeMs,
    required this.x,
    required this.y,
    required this.type,
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.easing,
  });

  /// Absolute time (in ms) at which this keyframe is reached.
  final int timeMs;

  /// Position at this keyframe.
  final double x;
  final double y;

  /// `"corner"` (straight-line segment to neighbour) or `"cusp"` (bezier
  /// segment using `start` / `end` as control points).
  final String type;

  /// Optional incoming control point (used for the segment ending here).
  final double? startX;
  final double? startY;

  /// Optional outgoing control point (used for the segment starting here).
  final double? endX;
  final double? endY;

  /// Optional easing curve applied to the segment starting at this
  /// keyframe. Stored as 4 numbers `[x1, y1, x2, y2]` matching CSS
  /// `cubic-bezier(...)`.
  final CubicBezierEasing? easing;
}

/// One scalar keyframe used for rotation (`keys.r`, degrees).
class SvgatorScalarKeyframe {
  const SvgatorScalarKeyframe({
    required this.timeMs,
    required this.value,
    this.easing,
  });
  final int timeMs;
  final double value;
  final CubicBezierEasing? easing;
}

/// One scale keyframe used for `keys.s` (x/y scale factors).
class SvgatorScaleKeyframe {
  const SvgatorScaleKeyframe({
    required this.timeMs,
    required this.x,
    required this.y,
    this.easing,
  });
  final int timeMs;
  final double x;
  final double y;
  final CubicBezierEasing? easing;
}

// ── Tracks ────────────────────────────────────────────────────────────────

/// Cubic-bezier easing curve `(x1, y1, x2, y2)` matching CSS semantics:
/// the curve starts at `(0, 0)`, ends at `(1, 1)`, with the two named
/// control points. Given a linear progress `t ∈ [0, 1]` we find the
/// horizontal point on the curve and return its vertical (eased value).
class CubicBezierEasing {
  const CubicBezierEasing(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;

  /// Identity curve (linear).
  static const linear = CubicBezierEasing(0, 0, 1, 1);

  double transform(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    // Standard CSS cubic-bezier evaluation.
    // X(s) = 3(1-s)^2 s x1 + 3(1-s) s^2 x2 + s^3
    // Y(s) = 3(1-s)^2 s y1 + 3(1-s) s^2 y2 + s^3
    // We solve X(s) = t for s using Newton's method, then return Y(s).
    double s = t;
    for (int i = 0; i < 8; i++) {
      final xS = _cubic(s, x1, x2);
      final dxS = _cubicDeriv(s, x1, x2);
      if (dxS.abs() < 1e-9) break;
      final delta = (xS - t) / dxS;
      s -= delta;
      if (delta.abs() < 1e-7) break;
    }
    // Fallback to bisection if Newton didn't converge well.
    if (s < 0 || s > 1) {
      double lo = 0, hi = 1;
      for (int i = 0; i < 30; i++) {
        s = (lo + hi) / 2;
        final xS = _cubic(s, x1, x2);
        if ((xS - t).abs() < 1e-6) break;
        if (xS < t) {
          lo = s;
        } else {
          hi = s;
        }
      }
    }
    return _cubic(s, y1, y2);
  }

  // Cubic Bezier with P0=0, P3=1, two intermediate weights p1 and p2:
  //   B(s) = 3(1-s)^2 s p1 + 3(1-s) s^2 p2 + s^3
  static double _cubic(double s, double p1, double p2) {
    final ms = 1 - s;
    return 3 * ms * ms * s * p1 + 3 * ms * s * s * p2 + s * s * s;
  }

  static double _cubicDeriv(double s, double p1, double p2) {
    final ms = 1 - s;
    return 3 * ms * ms * p1 + 6 * ms * s * (p2 - p1) + 3 * s * s * (1 - p2);
  }
}

/// Origin / position track (motion).
class SvgatorOriginTrack {
  SvgatorOriginTrack(this.keys);
  final List<SvgatorOriginKeyframe> keys;

  /// Returns the (x, y) position at [timeMs] using cubic-bezier path
  /// interpolation. Out-of-range times are clamped to the first / last
  /// keyframe.
  ({double x, double y}) at(double timeMs) {
    if (keys.isEmpty) return (x: 0.0, y: 0.0);
    if (keys.length == 1 || timeMs <= keys.first.timeMs) {
      return (x: keys.first.x, y: keys.first.y);
    }
    if (timeMs >= keys.last.timeMs) {
      return (x: keys.last.x, y: keys.last.y);
    }
    // Find segment.
    int i = 0;
    while (i < keys.length - 1 && keys[i + 1].timeMs <= timeMs) {
      i++;
    }
    final k0 = keys[i];
    final k1 = keys[i + 1];
    final span = (k1.timeMs - k0.timeMs).toDouble();
    final localT =
        span > 0 ? ((timeMs - k0.timeMs).toDouble() / span) : 0.0;
    final eased = (k0.easing ?? CubicBezierEasing.linear).transform(localT);
    // Control points: P1 = k0.end (or k0 if absent), P2 = k1.start (or k1).
    final p1x = k0.endX ?? k0.x;
    final p1y = k0.endY ?? k0.y;
    final p2x = k1.startX ?? k1.x;
    final p2y = k1.startY ?? k1.y;
    return _cubicBezierPoint(
      k0.x, k0.y, p1x, p1y, p2x, p2y, k1.x, k1.y, eased,
    );
  }
}

/// Scalar track (e.g. rotation in degrees, opacity).
class SvgatorScalarTrack {
  SvgatorScalarTrack(this.keys);
  final List<SvgatorScalarKeyframe> keys;

  double at(double timeMs, {double fallback = 0}) {
    if (keys.isEmpty) return fallback;
    if (keys.length == 1 || timeMs <= keys.first.timeMs) {
      return keys.first.value;
    }
    if (timeMs >= keys.last.timeMs) return keys.last.value;
    int i = 0;
    while (i < keys.length - 1 && keys[i + 1].timeMs <= timeMs) {
      i++;
    }
    final k0 = keys[i];
    final k1 = keys[i + 1];
    final span = (k1.timeMs - k0.timeMs).toDouble();
    final localT =
        span > 0 ? ((timeMs - k0.timeMs).toDouble() / span) : 0.0;
    final eased = (k0.easing ?? CubicBezierEasing.linear).transform(localT);
    return k0.value + (k1.value - k0.value) * eased;
  }
}

/// Scale track (`keys.s`): two scalar factors interpolated independently.
class SvgatorScaleTrack {
  SvgatorScaleTrack(this.keys);
  final List<SvgatorScaleKeyframe> keys;

  ({double x, double y}) at(double timeMs) {
    if (keys.isEmpty) return (x: 1.0, y: 1.0);
    if (keys.length == 1 || timeMs <= keys.first.timeMs) {
      return (x: keys.first.x, y: keys.first.y);
    }
    if (timeMs >= keys.last.timeMs) {
      return (x: keys.last.x, y: keys.last.y);
    }
    int i = 0;
    while (i < keys.length - 1 && keys[i + 1].timeMs <= timeMs) {
      i++;
    }
    final k0 = keys[i];
    final k1 = keys[i + 1];
    final span = (k1.timeMs - k0.timeMs).toDouble();
    final localT =
        span > 0 ? ((timeMs - k0.timeMs).toDouble() / span) : 0.0;
    final eased = (k0.easing ?? CubicBezierEasing.linear).transform(localT);
    return (
      x: k0.x + (k1.x - k0.x) * eased,
      y: k0.y + (k1.y - k0.y) * eased,
    );
  }
}

// ── Element animation aggregate ────────────────────────────────────────────

/// One element's transform-track aggregate. The output `transformAt`
/// returns a SVG transform string ready to drop into `setAttribute`.
class SvgatorTransformTrack {
  SvgatorTransformTrack({
    required this.dataTx,
    required this.dataTy,
    this.dataSx,
    this.dataSy,
    this.dataOx,
    this.dataOy,
    this.origin,
    this.rotation,
    this.scale,
  });

  /// Static translation offset (`data.t`).
  final double dataTx;
  final double dataTy;

  /// Static scale baseline (`data.s`), used when `keys.s` is present.
  /// Final scale = `(dataS * keys.s)`.
  final double? dataSx;
  final double? dataSy;

  /// Static rotation pivot (`data.o`), used when the element has rotation
  /// or scale that should pivot around a specific point in element-local
  /// space. When null the SVG natural origin (0, 0) is used.
  final double? dataOx;
  final double? dataOy;

  final SvgatorOriginTrack? origin;
  final SvgatorScalarTrack? rotation;
  final SvgatorScaleTrack? scale;

  /// Returns a transform string for [timeMs]. Builds a SVG transform list
  /// equivalent to the operations the SVGator player applies:
  ///
  /// 1. Pre-translate by `(data.t + origin(t))`.
  /// 2. Rotate by `rotation(t)` around `data.o` (if rotation track).
  /// 3. Scale by `(data.s * scale(t))` around `data.o` (if scale track).
  ///
  /// The exact operation order matches what we observe SVGator's player
  /// produce in a real browser for the SVGs we've cross-checked
  /// (Glowing Gummies, Coffee Match Cut). The transform list is rendered
  /// using SVG's right-to-left composition convention, i.e. the rightmost
  /// `translate` is applied first.
  String transformAt(double timeMs) {
    final hasOrigin = origin != null;
    final hasRotation = rotation != null;
    final hasScale = scale != null;

    double tx = dataTx;
    double ty = dataTy;
    if (hasOrigin) {
      final o = origin!.at(timeMs);
      tx += o.x;
      ty += o.y;
    }

    final ops = <String>['translate($tx, $ty)'];

    if (hasRotation) {
      final deg = rotation!.at(timeMs);
      if (deg != 0) {
        if (dataOx != null && dataOy != null) {
          ops.add('rotate($deg, ${dataOx!}, ${dataOy!})');
        } else {
          ops.add('rotate($deg)');
        }
      }
    }

    if (hasScale) {
      final s = scale!.at(timeMs);
      final sx = (dataSx ?? 1.0) * s.x;
      final sy = (dataSy ?? 1.0) * s.y;
      if (sx != 1.0 || sy != 1.0) {
        if (dataOx != null && dataOy != null) {
          // scale around pivot: T(o) S T(-o)
          ops.add('translate(${dataOx!}, ${dataOy!})');
          ops.add('scale($sx, $sy)');
          ops.add('translate(${-dataOx!}, ${-dataOy!})');
        } else {
          ops.add('scale($sx, $sy)');
        }
      }
    }

    return ops.join(' ');
  }

  /// Whether this track actually has any animated keyframes (origin /
  /// rotation / scale). If false the caller can leave the static SVG
  /// transform alone.
  bool get isAnimated =>
      (origin != null && origin!.keys.isNotEmpty) ||
      (rotation != null && rotation!.keys.isNotEmpty) ||
      (scale != null && scale!.keys.isNotEmpty);
}

/// One element's opacity track.
class SvgatorOpacityTrack {
  SvgatorOpacityTrack(this._track);
  final SvgatorScalarTrack _track;
  double at(double timeMs) => _track.at(timeMs, fallback: 1);
  bool get isAnimated => _track.keys.isNotEmpty;
}

/// Aggregate per-element animation data.
class SvgatorElementAnimation {
  SvgatorElementAnimation({
    required this.elementId,
    this.transform,
    this.opacity,
  });
  final String elementId;
  final SvgatorTransformTrack? transform;
  final SvgatorOpacityTrack? opacity;
}

// ── Parsing from harvested JSON ────────────────────────────────────────────

/// Parses one element's animation block from the SVGator bootstrap JSON.
/// [json] is the value of `animations[i].elements[elementId]`.
SvgatorElementAnimation? parseSvgatorElement(
  String elementId,
  Map<String, dynamic> json,
) {
  final transform = _parseTransform(json['transform']);
  final opacity = _parseOpacity(json['opacity']);
  if (transform == null && opacity == null) return null;
  return SvgatorElementAnimation(
    elementId: elementId,
    transform: transform,
    opacity: opacity,
  );
}

SvgatorTransformTrack? _parseTransform(dynamic raw) {
  if (raw is! Map) return null;
  final data = raw['data'] is Map ? raw['data'] as Map : const {};
  final keys = raw['keys'] is Map ? raw['keys'] as Map : const {};
  final dataT = data['t'] is Map ? data['t'] as Map : null;
  if (dataT == null) return null;
  final tx = (dataT['x'] as num?)?.toDouble();
  final ty = (dataT['y'] as num?)?.toDouble();
  if (tx == null || ty == null) return null;

  final dataS = data['s'] is Map ? data['s'] as Map : null;
  final dataO = data['o'] is Map ? data['o'] as Map : null;

  return SvgatorTransformTrack(
    dataTx: tx,
    dataTy: ty,
    dataSx: (dataS?['x'] as num?)?.toDouble(),
    dataSy: (dataS?['y'] as num?)?.toDouble(),
    dataOx: (dataO?['x'] as num?)?.toDouble(),
    dataOy: (dataO?['y'] as num?)?.toDouble(),
    origin: _parseOriginTrack(keys['o']),
    rotation: _parseScalarTrack(keys['r']),
    scale: _parseScaleTrack(keys['s']),
  );
}

SvgatorOriginTrack? _parseOriginTrack(dynamic raw) {
  if (raw is! List) return null;
  final out = <SvgatorOriginKeyframe>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final t = (entry['t'] as num?)?.toInt();
    final v = entry['v'] is Map ? entry['v'] as Map : null;
    if (t == null || v == null) continue;
    final x = (v['x'] as num?)?.toDouble();
    final y = (v['y'] as num?)?.toDouble();
    if (x == null || y == null) continue;
    final start = v['start'] is Map ? v['start'] as Map : null;
    final end = v['end'] is Map ? v['end'] as Map : null;
    out.add(SvgatorOriginKeyframe(
      timeMs: t,
      x: x,
      y: y,
      type: (v['type'] as String?) ?? 'corner',
      startX: (start?['x'] as num?)?.toDouble(),
      startY: (start?['y'] as num?)?.toDouble(),
      endX: (end?['x'] as num?)?.toDouble(),
      endY: (end?['y'] as num?)?.toDouble(),
      easing: _parseEasing(entry['e']),
    ));
  }
  return out.isEmpty ? null : SvgatorOriginTrack(out);
}

SvgatorScalarTrack? _parseScalarTrack(dynamic raw) {
  if (raw is! List) return null;
  final out = <SvgatorScalarKeyframe>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final t = (entry['t'] as num?)?.toInt();
    final v = (entry['v'] as num?)?.toDouble();
    if (t == null || v == null) continue;
    out.add(SvgatorScalarKeyframe(
      timeMs: t,
      value: v,
      easing: _parseEasing(entry['e']),
    ));
  }
  return out.isEmpty ? null : SvgatorScalarTrack(out);
}

SvgatorScaleTrack? _parseScaleTrack(dynamic raw) {
  if (raw is! List) return null;
  final out = <SvgatorScaleKeyframe>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final t = (entry['t'] as num?)?.toInt();
    final v = entry['v'] is Map ? entry['v'] as Map : null;
    if (t == null || v == null) continue;
    final x = (v['x'] as num?)?.toDouble() ?? 1.0;
    final y = (v['y'] as num?)?.toDouble() ?? 1.0;
    out.add(SvgatorScaleKeyframe(
      timeMs: t,
      x: x,
      y: y,
      easing: _parseEasing(entry['e']),
    ));
  }
  return out.isEmpty ? null : SvgatorScaleTrack(out);
}

SvgatorOpacityTrack? _parseOpacity(dynamic raw) {
  final track = _parseScalarTrack(raw);
  return track == null ? null : SvgatorOpacityTrack(track);
}

CubicBezierEasing? _parseEasing(dynamic raw) {
  if (raw is! List || raw.length < 4) return null;
  final x1 = (raw[0] as num?)?.toDouble();
  final y1 = (raw[1] as num?)?.toDouble();
  final x2 = (raw[2] as num?)?.toDouble();
  final y2 = (raw[3] as num?)?.toDouble();
  if (x1 == null || y1 == null || x2 == null || y2 == null) return null;
  return CubicBezierEasing(x1, y1, x2, y2);
}

// ── Bezier path math ───────────────────────────────────────────────────────

/// Evaluates a cubic Bezier curve at [t]. Used by [SvgatorOriginTrack.at].
({double x, double y}) _cubicBezierPoint(
  double p0x,
  double p0y,
  double p1x,
  double p1y,
  double p2x,
  double p2y,
  double p3x,
  double p3y,
  double t,
) {
  final mt = 1 - t;
  final mt2 = mt * mt;
  final mt3 = mt2 * mt;
  final t2 = t * t;
  final t3 = t2 * t;
  return (
    x: mt3 * p0x + 3 * mt2 * t * p1x + 3 * mt * t2 * p2x + t3 * p3x,
    y: mt3 * p0y + 3 * mt2 * t * p1y + 3 * mt * t2 * p2y + t3 * p3y,
  );
}

// Suppress dart:math unused warning — kept for future float utilities.
// ignore: unused_element
double _suppress() => math.pi;
