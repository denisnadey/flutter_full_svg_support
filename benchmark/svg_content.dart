// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Test SVG content constants for benchmarks.
///
/// These SVGs are designed to be realistic but controlled/deterministic.
class SvgTestContent {
  SvgTestContent._();

  /// Simple SVG with basic shapes (rect, circle, path).
  static const String simple = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect x="10" y="10" width="50" height="50" fill="#ff0000"/>
  <circle cx="100" cy="50" r="30" fill="#00ff00"/>
  <ellipse cx="150" cy="100" rx="30" ry="20" fill="#0000ff"/>
  <path d="M 10 150 L 50 120 L 90 150 L 50 180 Z" fill="#ff00ff"/>
  <line x1="100" y1="150" x2="180" y2="150" stroke="#000" stroke-width="2"/>
  <polyline points="100,180 120,160 140,180 160,160 180,180" stroke="#666" fill="none"/>
  <polygon points="100,100 110,130 90,130" fill="#ffa500"/>
</svg>
''';

  /// Complex SVG with gradients and transforms.
  static const String gradients = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff0000"/>
      <stop offset="50%" style="stop-color:#00ff00"/>
      <stop offset="100%" style="stop-color:#0000ff"/>
    </linearGradient>
    <radialGradient id="grad2" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#ffffff"/>
      <stop offset="100%" style="stop-color:#000000"/>
    </radialGradient>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="url(#grad1)"/>
  <circle cx="150" cy="50" r="40" fill="url(#grad2)"/>
  <g transform="translate(50,100) rotate(45)">
    <rect x="-25" y="-25" width="50" height="50" fill="url(#grad1)"/>
  </g>
</svg>
''';

  /// SVG with filter chain (blur + color matrix + composite).
  static const String filterChain = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <filter id="complexFilter" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="3" result="blur"/>
      <feColorMatrix in="blur" type="matrix" result="colorMatrix"
        values="1.2 0 0 0 0
                0 1.2 0 0 0
                0 0 1.2 0 0
                0 0 0 1 0"/>
      <feOffset in="SourceGraphic" dx="2" dy="2" result="offset"/>
      <feComposite in="colorMatrix" in2="offset" operator="over"/>
    </filter>
    <filter id="dropShadow">
      <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="shadowBlur"/>
      <feOffset in="shadowBlur" dx="3" dy="3" result="shadowOffset"/>
      <feFlood flood-color="#000000" flood-opacity="0.5" result="shadowColor"/>
      <feComposite in="shadowColor" in2="shadowOffset" operator="in" result="shadow"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="20" y="20" width="60" height="60" fill="#ff6600" filter="url(#complexFilter)"/>
  <circle cx="140" cy="50" r="30" fill="#0066ff" filter="url(#dropShadow)"/>
  <path d="M 30 120 Q 100 80 170 120 T 170 180" stroke="#009900" fill="none" stroke-width="4" filter="url(#complexFilter)"/>
</svg>
''';

  /// SVG with multiple SMIL animations.
  static const String animation = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect id="rect1" x="10" y="10" width="40" height="40" fill="#ff0000">
    <animate attributeName="x" from="10" to="150" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="fill" values="#ff0000;#00ff00;#0000ff;#ff0000" dur="3s" repeatCount="indefinite"/>
  </rect>
  <circle id="circle1" cx="100" cy="100" r="20" fill="#0000ff">
    <animate attributeName="r" values="20;40;20" dur="1.5s" repeatCount="indefinite"/>
    <animate attributeName="fill-opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/>
  </circle>
  <g id="group1">
    <animateTransform attributeName="transform" type="rotate" 
      from="0 100 150" to="360 100 150" dur="4s" repeatCount="indefinite"/>
    <rect x="80" y="130" width="40" height="40" fill="#00ff00"/>
  </g>
  <path id="path1" d="M 150 50 L 180 80 L 150 110 L 120 80 Z" fill="#ff00ff">
    <animate attributeName="d" 
      values="M 150 50 L 180 80 L 150 110 L 120 80 Z;
              M 150 40 L 190 80 L 150 120 L 110 80 Z;
              M 150 50 L 180 80 L 150 110 L 120 80 Z" 
      dur="2s" repeatCount="indefinite"/>
  </path>
</svg>
''';

  /// SVG with multiple text elements and various styles.
  static const String textHeavy = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">
  <text x="10" y="30" font-family="Arial" font-size="24" fill="#000">Simple Text</text>
  <text x="10" y="60" font-family="Georgia" font-size="18" font-style="italic" fill="#333">
    Italic text with serif font
  </text>
  <text x="10" y="90" font-family="Verdana" font-size="16" font-weight="bold" fill="#666">
    Bold text element
  </text>
  <text x="10" y="120" font-size="14" fill="#000">
    <tspan fill="#ff0000">Red</tspan>
    <tspan fill="#00ff00"> Green</tspan>
    <tspan fill="#0000ff"> Blue</tspan>
  </text>
  <text x="10" y="150" font-size="12" fill="#444" letter-spacing="2">
    L e t t e r   s p a c i n g
  </text>
  <text x="10" y="180" font-size="14" text-decoration="underline" fill="#000">
    Underlined text
  </text>
  <text x="10" y="210" font-size="14" text-decoration="line-through" fill="#888">
    Strikethrough text
  </text>
  <text x="200" y="50" font-size="20" writing-mode="tb" fill="#000">
    Vertical
  </text>
  <text x="10" y="240">
    <tspan x="10" dy="0" font-size="16">Line 1</tspan>
    <tspan x="10" dy="20" font-size="14">Line 2</tspan>
    <tspan x="10" dy="20" font-size="12">Line 3</tspan>
  </text>
</svg>
''';

  /// SVG with many dashed strokes (tests dash pattern computation).
  static const String dashPatterns = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200">
  <line x1="10" y1="10" x2="290" y2="10" stroke="#000" stroke-width="2" stroke-dasharray="5,5"/>
  <line x1="10" y1="25" x2="290" y2="25" stroke="#000" stroke-width="2" stroke-dasharray="10,5"/>
  <line x1="10" y1="40" x2="290" y2="40" stroke="#000" stroke-width="2" stroke-dasharray="15,5,5,5"/>
  <line x1="10" y1="55" x2="290" y2="55" stroke="#000" stroke-width="2" stroke-dasharray="20,10,5,10"/>
  <line x1="10" y1="70" x2="290" y2="70" stroke="#000" stroke-width="3" stroke-dasharray="1,2"/>
  <rect x="10" y="85" width="80" height="40" stroke="#ff0000" fill="none" stroke-width="2" stroke-dasharray="8,4"/>
  <circle cx="150" cy="105" r="25" stroke="#00ff00" fill="none" stroke-width="2" stroke-dasharray="5,3,1,3"/>
  <ellipse cx="250" cy="105" rx="30" ry="20" stroke="#0000ff" fill="none" stroke-width="2" stroke-dasharray="10,5"/>
  <path d="M 10 150 Q 75 100 140 150 T 290 150" stroke="#ff00ff" fill="none" stroke-width="2" stroke-dasharray="15,10"/>
  <polyline points="10,170 50,185 90,170 130,185 170,170 210,185 250,170 290,185" 
    stroke="#666" fill="none" stroke-width="2" stroke-dasharray="3,3"/>
  <polygon points="150,190 165,200 150,210 135,200" stroke="#000" fill="none" stroke-width="1" stroke-dasharray="2,2"/>
</svg>
''';

  /// Complex SVG with nested groups and transforms.
  static const String nested = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <g id="outer" transform="translate(100,100)">
    <g id="middle" transform="rotate(45)">
      <g id="inner" transform="scale(0.8)">
        <rect x="-30" y="-30" width="60" height="60" fill="#ff0000"/>
        <circle cx="0" cy="0" r="20" fill="#00ff00"/>
      </g>
      <rect x="-40" y="-40" width="80" height="80" stroke="#000" fill="none"/>
    </g>
    <circle cx="0" cy="0" r="50" stroke="#0000ff" fill="none" stroke-width="2"/>
  </g>
  <g transform="translate(50,50) skewX(15)">
    <rect x="0" y="0" width="30" height="30" fill="#ff00ff" opacity="0.5"/>
  </g>
</svg>
''';

  /// SVG with clip paths and masks.
  static const String clipping = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <clipPath id="circleClip">
      <circle cx="100" cy="100" r="50"/>
    </clipPath>
    <clipPath id="rectClip">
      <rect x="20" y="20" width="160" height="160" rx="20"/>
    </clipPath>
    <mask id="gradientMask">
      <linearGradient id="maskGrad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" style="stop-color:white"/>
        <stop offset="100%" style="stop-color:black"/>
      </linearGradient>
      <rect x="0" y="0" width="200" height="200" fill="url(#maskGrad)"/>
    </mask>
  </defs>
  <g clip-path="url(#circleClip)">
    <rect x="0" y="0" width="200" height="200" fill="#ff6600"/>
    <line x1="0" y1="0" x2="200" y2="200" stroke="#fff" stroke-width="4"/>
    <line x1="200" y1="0" x2="0" y2="200" stroke="#fff" stroke-width="4"/>
  </g>
  <rect x="10" y="10" width="180" height="180" fill="#0066ff" mask="url(#gradientMask)" opacity="0.7"/>
</svg>
''';

  /// Large SVG with many elements (stress test).
  static String get largeScale {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">',
    );

    // Generate 100 rectangles
    for (var i = 0; i < 100; i++) {
      final x = (i % 10) * 100;
      final y = (i ~/ 10) * 100;
      final color =
          '#${(i * 25 % 256).toRadixString(16).padLeft(2, '0')}'
          '${((i * 37) % 256).toRadixString(16).padLeft(2, '0')}'
          '${((i * 53) % 256).toRadixString(16).padLeft(2, '0')}';
      buffer.writeln(
        '  <rect x="$x" y="$y" width="90" height="90" fill="$color" rx="5"/>',
      );
    }

    // Generate 50 circles
    for (var i = 0; i < 50; i++) {
      final cx = (i % 10) * 100 + 50;
      final cy = (i ~/ 10) * 200 + 50;
      buffer.writeln(
        '  <circle cx="$cx" cy="$cy" r="30" fill="none" stroke="#000" stroke-width="2"/>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}
