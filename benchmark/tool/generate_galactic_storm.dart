// Generator for the "Galactic Storm" mega stress-test SVG.
//
// Produces a single SVG that exercises every advanced feature
// full_svg_flutter supports:
//
//   - 500 distant twinkling stars (SMIL opacity, staggered begin times)
//   - 100 bright stars with rotating cross-rays + radial gradients + glow filter
//   - 50 floating particles following motion paths (animateMotion + mpath)
//   - 30 nebula clouds with feGaussianBlur, animated rx/ry/rotation
//   - 10 morphing crystals (path d-attribute morph + rotation)
//   - 1 central black-hole core (animated stop-color + animated stop-offset
//     + path morphing on the accretion disk)
//   - 1 text along curved <textPath> with letter-spacing + fill animations
//   - 5 CSS @keyframes-driven shapes (pulse / spin / drift)
//   - Animated linear-gradient background (animating stop-color)
//
// Run from the repo root with the project Flutter SDK:
//   ./.fvm/flutter_sdk/bin/dart run benchmarks/tool/generate_galactic_storm.dart
//
// Output: benchmarks/assets/stress/galactic_storm.svg
//         benchmarks/benchmark_app/assets/stress/galactic_storm.svg (copy)

import 'dart:io';
import 'dart:math';

const int W = 1920;
const int H = 1080;
const int seed = 42;

void main() {
  final r = Random(seed);
  final sb = StringBuffer();

  sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  sb.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'viewBox="0 0 $W $H" preserveAspectRatio="xMidYMid slice">',
  );
  sb.writeln(
    '<title>Galactic Storm — full_svg_flutter mega stress-test</title>',
  );
  sb.writeln(
    '<desc>700+ animated elements: SMIL, CSS keyframes, path morphing, '
    'animateMotion, animated gradients, filters, textPath.</desc>',
  );

  _writeStyles(sb);
  _writeDefs(sb, r);
  _writeBackground(sb);
  _writeDistantStars(sb, r, count: 500);
  _writeNebulae(sb, r, count: 30);
  _writeBrightStars(sb, r, count: 100);
  _writeMotionParticles(sb, r, count: 50);
  _writeComets(sb, r, count: 10);
  _writeMorphingCrystals(sb, r, count: 10);
  _writeCore(sb);
  _writeArcText(sb);
  _writeFlyingTwistingText(sb);
  _writeCssAnimatedShapes(sb);
  _writeFooterText(sb);

  sb.writeln('</svg>');

  final out = File('benchmarks/assets/stress/galactic_storm.svg');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(sb.toString());

  // Mirror into benchmark_app assets so the Flutter asset bundle picks it up.
  final mirror = File('benchmarks/benchmark_app/assets/stress/galactic_storm.svg');
  mirror.parent.createSync(recursive: true);
  mirror.writeAsStringSync(sb.toString());

  final kb = (sb.length / 1024).toStringAsFixed(1);
  stdout.writeln('Generated: ${out.path} ($kb KB, ${sb.length} bytes)');
  stdout.writeln('Mirrored:  ${mirror.path}');
}

// ---------------------------------------------------------------------------

void _writeStyles(StringBuffer sb) {
  sb.writeln('<style><![CDATA[');
  sb.writeln('  @keyframes pulse { 0%,100% { opacity: 0.4; transform: scale(1); }');
  sb.writeln('                     50%      { opacity: 1;   transform: scale(1.5); } }');
  sb.writeln('  @keyframes spin  { from { transform: rotate(0deg); }');
  sb.writeln('                     to   { transform: rotate(360deg); } }');
  sb.writeln('  @keyframes drift { 0%,100% { transform: translate(0,0); }');
  sb.writeln('                     50%      { transform: translate(40px,-60px); } }');
  sb.writeln('  .pulse { animation: pulse 3s ease-in-out infinite; transform-origin: center; transform-box: fill-box; }');
  sb.writeln('  .spin  { animation: spin 18s linear infinite; transform-origin: center; transform-box: fill-box; }');
  sb.writeln('  .drift { animation: drift 9s ease-in-out infinite; }');
  sb.writeln(']]></style>');
}

// ---------------------------------------------------------------------------

void _writeDefs(StringBuffer sb, Random r) {
  sb.writeln('<defs>');

  // Animated cosmic background.
  sb.writeln('<linearGradient id="cosmosBg" x1="0" y1="0" x2="1" y2="1">');
  sb.writeln('  <stop offset="0%" stop-color="#0a0e2e">');
  sb.writeln('    <animate attributeName="stop-color" '
      'values="#0a0e2e;#1e0a3e;#3e0a2e;#0a3e2e;#0a0e2e" '
      'dur="20s" repeatCount="indefinite"/>');
  sb.writeln('  </stop>');
  sb.writeln('  <stop offset="100%" stop-color="#000000">');
  sb.writeln('    <animate attributeName="stop-color" '
      'values="#000000;#001428;#28001e;#001e14;#000000" '
      'dur="20s" repeatCount="indefinite"/>');
  sb.writeln('  </stop>');
  sb.writeln('</linearGradient>');

  // Star color gradients.
  const starColors = ['#ffffff', '#ffd9b3', '#b3d9ff', '#ffb3e6', '#b3ffd9'];
  for (var i = 0; i < starColors.length; i++) {
    sb.writeln('<radialGradient id="star$i" cx="50%" cy="50%" r="50%">');
    sb.writeln('  <stop offset="0%"   stop-color="${starColors[i]}" stop-opacity="1"/>');
    sb.writeln('  <stop offset="50%"  stop-color="${starColors[i]}" stop-opacity="0.5"/>');
    sb.writeln('  <stop offset="100%" stop-color="${starColors[i]}" stop-opacity="0"/>');
    sb.writeln('</radialGradient>');
  }

  // Nebula gradients (3 hue families).
  for (var i = 0; i < 3; i++) {
    final hue1 = 240 + i * 40;
    final hue2 = 280 + i * 40;
    sb.writeln('<radialGradient id="nebula$i" cx="50%" cy="50%" r="50%">');
    sb.writeln('  <stop offset="0%"   stop-color="hsl($hue1, 80%, 60%)" stop-opacity="0.85"/>');
    sb.writeln('  <stop offset="60%"  stop-color="hsl($hue2, 90%, 40%)" stop-opacity="0.4"/>');
    sb.writeln('  <stop offset="100%" stop-color="hsl($hue2, 90%, 30%)" stop-opacity="0"/>');
    sb.writeln('</radialGradient>');
  }

  // Core gradient — animates both stop-color AND stop-offset.
  sb.writeln('<radialGradient id="coreGrad" cx="50%" cy="50%" r="50%">');
  sb.writeln('  <stop offset="0%" stop-color="#ffffff">');
  sb.writeln('    <animate attributeName="stop-color" '
      'values="#ffffff;#00ffff;#ff00ff;#ffff00;#ffffff" '
      'dur="10s" repeatCount="indefinite"/>');
  sb.writeln('  </stop>');
  sb.writeln('  <stop offset="40%" stop-color="#00ffff">');
  sb.writeln('    <animate attributeName="stop-color" '
      'values="#00ffff;#ff00ff;#ffff00;#ffffff;#00ffff" '
      'dur="10s" repeatCount="indefinite"/>');
  sb.writeln('    <animate attributeName="offset" '
      'values="20%;60%;20%" dur="6s" repeatCount="indefinite"/>');
  sb.writeln('  </stop>');
  sb.writeln('  <stop offset="100%" stop-color="#7a00ff" stop-opacity="0"/>');
  sb.writeln('</radialGradient>');

  // Filters.
  sb.writeln('<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">');
  sb.writeln('  <feGaussianBlur stdDeviation="3" result="blur"/>');
  sb.writeln('  <feMerge>');
  sb.writeln('    <feMergeNode in="blur"/>');
  sb.writeln('    <feMergeNode in="SourceGraphic"/>');
  sb.writeln('  </feMerge>');
  sb.writeln('</filter>');

  sb.writeln('<filter id="bigGlow" x="-100%" y="-100%" width="300%" height="300%">');
  sb.writeln('  <feGaussianBlur stdDeviation="20"/>');
  sb.writeln('</filter>');

  sb.writeln('<filter id="dropShadow" x="-20%" y="-20%" width="140%" height="140%">');
  sb.writeln('  <feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="#00ffff" flood-opacity="0.8"/>');
  sb.writeln('</filter>');

  // Text path arc.
  sb.writeln('<path id="arcText" d="M 200 540 A 760 760 0 0 1 1720 540" fill="none"/>');

  // Morphing path for the flying-twisting text — the curve itself animates.
  sb.writeln('<path id="flyingPath" d="M 80 720 Q 480 480 960 720 T 1840 720" fill="none">');
  sb.writeln('  <animate attributeName="d" '
      'values="'
      'M 80 720 Q 480 480 960 720 T 1840 720;'
      'M 80 820 Q 480 280 960 880 T 1840 620;'
      'M 80 620 Q 480 880 960 280 T 1840 820;'
      'M 80 720 Q 480 480 960 720 T 1840 720'
      '" dur="9s" repeatCount="indefinite" '
      'calcMode="spline" '
      'keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1"/>');
  sb.writeln('</path>');

  // 10 random Bezier paths used as motion paths for particles & comets.
  for (var i = 0; i < 10; i++) {
    final sx = r.nextInt(W);
    final sy = r.nextInt(H);
    final ex = r.nextInt(W);
    final ey = r.nextInt(H);
    final cx = ((sx + ex) / 2 + (r.nextInt(800) - 400)).toInt();
    final cy = ((sy + ey) / 2 + (r.nextInt(800) - 400)).toInt();
    sb.writeln('<path id="cometPath$i" d="M $sx $sy Q $cx $cy $ex $ey" fill="none"/>');
  }

  sb.writeln('</defs>');
}

// ---------------------------------------------------------------------------

void _writeBackground(StringBuffer sb) {
  sb.writeln('<rect width="$W" height="$H" fill="url(#cosmosBg)"/>');
}

// ---------------------------------------------------------------------------

void _writeDistantStars(StringBuffer sb, Random r, {required int count}) {
  // Each star twinkles AND drifts in a unique organic pattern via translate.
  // Uses calcMode="spline" with cubic-bezier easing for smooth motion.
  sb.writeln('<g id="distantStars">');
  for (var i = 0; i < count; i++) {
    final cx = r.nextInt(W);
    final cy = r.nextInt(H);
    final sz = (0.5 + r.nextDouble() * 1.5).toStringAsFixed(2);
    final dur = (2 + r.nextDouble() * 4).toStringAsFixed(2);
    final delay = (r.nextDouble() * 4).toStringAsFixed(2);

    // Two random drift waypoints — keeps stars looping back to origin.
    final dx1 = r.nextInt(70) - 35;
    final dy1 = r.nextInt(70) - 35;
    final dx2 = r.nextInt(70) - 35;
    final dy2 = r.nextInt(70) - 35;
    final driftDur = 14 + r.nextInt(20);
    final driftDelay = (r.nextDouble() * 6).toStringAsFixed(1);

    sb.writeln(
      '<circle cx="$cx" cy="$cy" r="$sz" fill="white">'
      '<animate attributeName="opacity" values="0.15;1;0.15" '
      'dur="${dur}s" begin="${delay}s" repeatCount="indefinite"/>'
      '<animateTransform attributeName="transform" type="translate" '
      'values="0 0; $dx1 $dy1; $dx2 $dy2; 0 0" '
      'keyTimes="0;0.33;0.66;1" '
      'calcMode="spline" '
      'keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1" '
      'dur="${driftDur}s" begin="${driftDelay}s" repeatCount="indefinite"/>'
      '</circle>',
    );
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeNebulae(StringBuffer sb, Random r, {required int count}) {
  sb.writeln('<g id="nebulae" filter="url(#bigGlow)">');
  for (var i = 0; i < count; i++) {
    final cx = r.nextInt(W);
    final cy = r.nextInt(H);
    final rx = 100 + r.nextInt(300);
    final ry = 100 + r.nextInt(300);
    final ng = i % 3;
    final dur = (8 + r.nextDouble() * 10).toStringAsFixed(1);
    final dur2 = (10 + r.nextDouble() * 10).toStringAsFixed(1);
    final spinDur = (40 + r.nextInt(40));
    final ang = r.nextInt(360);
    sb.writeln('<g transform="translate($cx $cy) rotate($ang)">');
    sb.writeln('<ellipse rx="$rx" ry="$ry" fill="url(#nebula$ng)" opacity="0.45">');
    sb.writeln('  <animate attributeName="rx" values="$rx;${(rx * 1.3).toInt()};$rx" dur="${dur}s" repeatCount="indefinite"/>');
    sb.writeln('  <animate attributeName="ry" values="$ry;${(ry * 0.7).toInt()};$ry" dur="${dur2}s" repeatCount="indefinite"/>');
    sb.writeln('  <animateTransform attributeName="transform" type="rotate" '
        'from="0" to="360" dur="${spinDur}s" repeatCount="indefinite"/>');
    sb.writeln('</ellipse>');
    sb.writeln('</g>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeBrightStars(StringBuffer sb, Random r, {required int count}) {
  // Each bright star orbits along its own random Bezier loop via animateMotion.
  // The outer <g> places the star; the inner <g> carries the orbital motion.
  sb.writeln('<g id="brightStars" filter="url(#glow)">');
  for (var i = 0; i < count; i++) {
    final cx = r.nextInt(W);
    final cy = r.nextInt(H);
    final sz = 3 + r.nextInt(8);
    final si = i % 5;
    final dur = (1.5 + r.nextDouble() * 3).toStringAsFixed(2);
    final delay = (r.nextDouble() * 2).toStringAsFixed(2);
    final spinDur = 10 + r.nextInt(20);

    // Random closed-loop orbital path relative to (0,0).
    final p1x = r.nextInt(120) - 60;
    final p1y = r.nextInt(120) - 60;
    final p2x = r.nextInt(120) - 60;
    final p2y = r.nextInt(120) - 60;
    final orbitPath = 'M 0 0 C $p1x $p1y, $p2x $p2y, 0 0';
    final orbitDur = 14 + r.nextInt(22);
    final orbitDelay = (r.nextDouble() * 6).toStringAsFixed(1);

    sb.writeln('<g transform="translate($cx $cy)">');
    // Inner group carries the orbital motion path.
    sb.writeln('<g>');
    sb.writeln('  <animateMotion path="$orbitPath" dur="${orbitDur}s" '
        'begin="${orbitDelay}s" repeatCount="indefinite" '
        'calcMode="spline" keySplines="0.42 0 0.58 1"/>');
    // Cross rays — rotate
    sb.writeln('<g stroke="url(#star$si)" stroke-width="0.6" opacity="0.7">');
    sb.writeln('  <line x1="${-sz * 4}" y1="0" x2="${sz * 4}" y2="0"/>');
    sb.writeln('  <line x1="0" y1="${-sz * 4}" x2="0" y2="${sz * 4}"/>');
    sb.writeln('  <animateTransform attributeName="transform" type="rotate" '
        'from="0" to="360" dur="${spinDur}s" repeatCount="indefinite"/>');
    sb.writeln('</g>');
    // Pulsing core
    sb.writeln('<circle r="$sz" fill="url(#star$si)">');
    sb.writeln('  <animate attributeName="r" values="$sz;${sz * 1.6};$sz" dur="${dur}s" begin="${delay}s" repeatCount="indefinite"/>');
    sb.writeln('  <animate attributeName="opacity" values="0.5;1;0.5" dur="${dur}s" begin="${delay}s" repeatCount="indefinite"/>');
    sb.writeln('</circle>');
    sb.writeln('</g>');
    sb.writeln('</g>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeMotionParticles(StringBuffer sb, Random r, {required int count}) {
  sb.writeln('<g id="particles">');
  for (var i = 0; i < count; i++) {
    final pathIdx = i % 10;
    final dur = (8 + r.nextDouble() * 10).toStringAsFixed(1);
    final delay = (r.nextDouble() * 5).toStringAsFixed(1);
    final si = i % 5;
    final sz = (1 + r.nextDouble() * 3).toStringAsFixed(1);
    sb.writeln('<circle r="$sz" fill="url(#star$si)" filter="url(#glow)">');
    sb.writeln('  <animateMotion dur="${dur}s" begin="${delay}s" repeatCount="indefinite">');
    sb.writeln('    <mpath xlink:href="#cometPath$pathIdx"/>');
    sb.writeln('  </animateMotion>');
    sb.writeln('  <animate attributeName="opacity" '
        'values="0;1;1;0" keyTimes="0;0.1;0.9;1" '
        'dur="${dur}s" begin="${delay}s" repeatCount="indefinite"/>');
    sb.writeln('</circle>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeComets(StringBuffer sb, Random r, {required int count}) {
  sb.writeln('<g id="comets" filter="url(#glow)">');
  for (var i = 0; i < count; i++) {
    final dur = (5 + r.nextDouble() * 7).toStringAsFixed(1);
    final delay = (r.nextDouble() * 3).toStringAsFixed(1);
    sb.writeln('<g>');
    sb.writeln('<circle r="4" fill="white">');
    sb.writeln('  <animateMotion dur="${dur}s" begin="${delay}s" repeatCount="indefinite">');
    sb.writeln('    <mpath xlink:href="#cometPath$i"/>');
    sb.writeln('  </animateMotion>');
    sb.writeln('  <animate attributeName="r" values="4;6;4" dur="${dur}s" begin="${delay}s" repeatCount="indefinite"/>');
    sb.writeln('</circle>');
    sb.writeln('</g>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeMorphingCrystals(StringBuffer sb, Random r, {required int count}) {
  sb.writeln('<g id="crystals" filter="url(#glow)">');
  for (var i = 0; i < count; i++) {
    final cx = 200 + r.nextInt(W - 400);
    final cy = 200 + r.nextInt(H - 400);
    final size = 30 + r.nextInt(50);
    final hue1 = r.nextInt(360);
    final hue2 = (hue1 + 120) % 360;
    final c1 = 'hsl($hue1, 80%, 60%)';
    final c2 = 'hsl($hue2, 80%, 60%)';
    final dur = (6 + r.nextDouble() * 6).toStringAsFixed(1);
    final spinDur = (dur.toString());

    String diamond(int s) => 'M $cx ${cy - s} L ${cx + s} $cy L $cx ${cy + s} L ${cx - s} $cy Z';
    String slanted(int s) =>
        'M ${cx - (s * 0.3).toInt()} ${cy - s} L ${cx + s} ${cy - (s * 0.3).toInt()} '
        'L ${cx + (s * 0.3).toInt()} ${cy + s} L ${cx - s} ${cy + (s * 0.3).toInt()} Z';
    String tight(int s) {
      final t = (s * 0.6).toInt();
      return 'M $cx ${cy - t} L ${cx + t} $cy L $cx ${cy + t} L ${cx - t} $cy Z';
    }

    // Random drifting orbit for the crystal.
    final fx = r.nextInt(160) - 80;
    final fy = r.nextInt(160) - 80;
    final flyDur = 16 + r.nextInt(20);
    final flyDelay = (r.nextDouble() * 6).toStringAsFixed(1);

    sb.writeln('<g>');
    sb.writeln('  <animateTransform attributeName="transform" type="translate" '
        'values="0 0; $fx $fy; ${-fx} ${-fy}; 0 0" '
        'keyTimes="0;0.33;0.66;1" '
        'calcMode="spline" '
        'keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1" '
        'dur="${flyDur}s" begin="${flyDelay}s" repeatCount="indefinite"/>');
    sb.writeln('<path d="${diamond(size)}" fill="$c1" stroke="$c2" stroke-width="2" opacity="0.75">');
    sb.writeln('  <animate attributeName="d" '
        'values="${diamond(size)};${slanted(size)};${tight(size)};${diamond(size)}" '
        'dur="${dur}s" repeatCount="indefinite" '
        'calcMode="spline" keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1"/>');
    sb.writeln('  <animateTransform attributeName="transform" type="rotate" '
        'from="0 $cx $cy" to="360 $cx $cy" dur="${spinDur}s" repeatCount="indefinite"/>');
    sb.writeln('  <animate attributeName="opacity" values="0.4;1;0.4" dur="${dur}s" repeatCount="indefinite"/>');
    sb.writeln('</path>');
    sb.writeln('</g>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeCore(StringBuffer sb) {
  final cx = W ~/ 2;
  final cy = H ~/ 2;
  sb.writeln('<g id="galacticCore" transform="translate($cx $cy)" filter="url(#glow)">');

  // Three concentric rotating rings.
  sb.writeln('<g>');
  sb.writeln('  <ellipse rx="240" ry="80" fill="none" stroke="url(#coreGrad)" stroke-width="3" opacity="0.7"/>');
  sb.writeln('  <ellipse rx="240" ry="80" fill="none" stroke="url(#coreGrad)" stroke-width="2" opacity="0.5" transform="rotate(60)"/>');
  sb.writeln('  <ellipse rx="240" ry="80" fill="none" stroke="url(#coreGrad)" stroke-width="1" opacity="0.3" transform="rotate(120)"/>');
  sb.writeln('  <animateTransform attributeName="transform" type="rotate" '
      'from="0" to="360" dur="22s" repeatCount="indefinite"/>');
  sb.writeln('</g>');

  // Pulsing core sphere.
  sb.writeln('<circle r="50" fill="url(#coreGrad)" filter="url(#dropShadow)">');
  sb.writeln('  <animate attributeName="r" values="50;75;50" dur="3s" repeatCount="indefinite"/>');
  sb.writeln('</circle>');

  // Morphing accretion disk.
  const a = 'M -120 0 C -60 -60, 60 -60, 120 0 C 60 60, -60 60, -120 0 Z';
  const b = 'M -150 0 C -75 -90, 75 -90, 150 0 C 75 30, -75 30, -150 0 Z';
  const c = 'M -100 -10 C -50 -45, 50 -75, 100 -10 C 50 75, -50 45, -100 -10 Z';
  sb.writeln('<path d="$a" fill="url(#coreGrad)" opacity="0.55">');
  sb.writeln('  <animate attributeName="d" values="$a;$b;$c;$a" dur="5s" repeatCount="indefinite"/>');
  sb.writeln('</path>');
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeArcText(StringBuffer sb) {
  // Group wraps the text so we can apply a skew "twist" without overriding
  // any transform inside the text element itself.
  sb.writeln('<g>');
  sb.writeln('  <animateTransform attributeName="transform" type="skewY" '
      'values="0;-4;0;4;0" dur="7s" repeatCount="indefinite" '
      'calcMode="spline" '
      'keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1"/>');
  sb.writeln('<text font-size="58" font-weight="bold" font-family="sans-serif" '
      'fill="white" filter="url(#glow)" letter-spacing="0">');
  sb.writeln('  <textPath href="#arcText" startOffset="50%" text-anchor="middle">');
  sb.writeln('    FULL SVG FLUTTER • COMPLETE • ANIMATED • POWERFUL');
  sb.writeln('  </textPath>');
  sb.writeln('  <animate attributeName="letter-spacing" '
      'values="0;14;0" dur="6s" repeatCount="indefinite" '
      'calcMode="spline" keySplines="0.42 0 0.58 1;0.42 0 0.58 1"/>');
  sb.writeln('  <animate attributeName="fill" values="white;cyan;magenta;yellow;white" dur="8s" repeatCount="indefinite"/>');
  sb.writeln('</text>');
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

/// Flying twisting text. Combines:
///   - a textPath whose d-attribute itself morphs (curve animates)
///   - skewX wave for the "twist" effect
///   - startOffset scrolling so the text glides along the curve
///   - colour cycling
void _writeFlyingTwistingText(StringBuffer sb) {
  sb.writeln('<g>');
  sb.writeln('  <animateTransform attributeName="transform" type="skewX" '
      'values="0;-14;14;-8;8;0" dur="6s" repeatCount="indefinite" '
      'calcMode="spline" '
      'keySplines="0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1;0.42 0 0.58 1"/>');
  sb.writeln('<text font-size="44" font-weight="900" font-family="sans-serif" '
      'fill="cyan" filter="url(#glow)">');
  sb.writeln('  <textPath href="#flyingPath" startOffset="0%">');
  sb.writeln('    ✦ POWERED BY FULL SVG FLUTTER ✦ POWERED BY FULL SVG FLUTTER ✦ POWERED BY FULL SVG FLUTTER ✦');
  sb.writeln('    <animate attributeName="startOffset" '
      'values="0%;100%" dur="14s" repeatCount="indefinite" '
      'calcMode="spline" keySplines="0.42 0 0.58 1"/>');
  sb.writeln('  </textPath>');
  sb.writeln('  <animate attributeName="fill" '
      'values="cyan;magenta;yellow;#7affff;cyan" '
      'dur="9s" repeatCount="indefinite"/>');
  sb.writeln('  <animate attributeName="font-size" values="44;58;44" dur="5s" repeatCount="indefinite" '
      'calcMode="spline" keySplines="0.42 0 0.58 1;0.42 0 0.58 1"/>');
  sb.writeln('</text>');
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeCssAnimatedShapes(StringBuffer sb) {
  sb.writeln('<g id="cssAnimated">');
  for (var i = 0; i < 5; i++) {
    final cx = 160 + i * 380;
    final cy = H - 140;
    const classes = ['pulse', 'spin', 'drift'];
    final cls = classes[i % classes.length];
    final hue = i * 72;
    sb.writeln('<g class="$cls" transform="translate($cx $cy)">');
    sb.writeln('  <polygon points="0,-34 32,20 -32,20" '
        'fill="hsl($hue, 80%, 60%)" filter="url(#glow)"/>');
    sb.writeln('</g>');
  }
  sb.writeln('</g>');
}

// ---------------------------------------------------------------------------

void _writeFooterText(StringBuffer sb) {
  sb.writeln('<text x="${W ~/ 2}" y="${H - 24}" font-size="20" '
      'font-family="sans-serif" fill="white" text-anchor="middle" opacity="0.7">');
  sb.writeln('  SMIL • CSS @keyframes • path morphing • animateMotion • filters • gradients • textPath');
  sb.writeln('  <animate attributeName="opacity" values="0.4;1;0.4" dur="3s" repeatCount="indefinite"/>');
  sb.writeln('</text>');
}
