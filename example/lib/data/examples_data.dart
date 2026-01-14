import 'package:flutter/material.dart';
import '../models/svg_example.dart';

/// Коллекция всех примеров SVG анимаций
class ExamplesData {
  static const List<SvgExample> all = [
    // ============ BASIC ANIMATIONS ============
    SvgExample(
      id: 'basic_move',
      title: 'Moving Rectangle',
      description: 'Simple horizontal movement animation',
      category: ExampleCategory.basic,
      icon: Icons.rectangle,
      tags: ['animate', 'x', 'movement'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect width="20" height="20" fill="blue">
    <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    SvgExample(
      id: 'basic_pulse',
      title: 'Pulsing Circle',
      description: 'Circle that changes radius',
      category: ExampleCategory.basic,
      icon: Icons.circle,
      tags: ['animate', 'r', 'pulse'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="10" fill="red">
    <animate attributeName="r" values="10;30;10" dur="1.5s" repeatCount="indefinite"/>
  </circle>
</svg>
''',
    ),

    SvgExample(
      id: 'basic_fade',
      title: 'Fading Square',
      description: 'Opacity animation',
      category: ExampleCategory.basic,
      icon: Icons.opacity,
      tags: ['animate', 'opacity', 'fade'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="35" y="35" width="30" height="30" fill="green">
    <animate attributeName="opacity" values="1;0.2;1" dur="2s" repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    // ============ TRANSFORM ANIMATIONS ============
    SvgExample(
      id: 'transform_rotate',
      title: 'Rotating Square',
      description: 'Continuous rotation around center',
      category: ExampleCategory.transform,
      icon: Icons.rotate_right,
      tags: ['animateTransform', 'rotate', 'transform'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="35" y="35" width="30" height="30" fill="purple">
    <animateTransform
      attributeName="transform"
      type="rotate"
      from="0 50 50"
      to="360 50 50"
      dur="3s"
      repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    SvgExample(
      id: 'transform_translate',
      title: 'Bouncing Ball',
      description: 'Translation animation with easing',
      category: ExampleCategory.transform,
      icon: Icons.sports_basketball,
      tags: ['animateTransform', 'translate', 'bounce'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="15" cy="50" r="10" fill="orange">
    <animateTransform
      attributeName="transform"
      type="translate"
      values="0,0; 70,0; 0,0"
      dur="2s"
      repeatCount="indefinite"/>
  </circle>
</svg>
''',
    ),

    SvgExample(
      id: 'transform_scale',
      title: 'Scaling Heart',
      description: 'Scale animation from center',
      category: ExampleCategory.transform,
      icon: Icons.favorite,
      tags: ['animateTransform', 'scale', 'heart'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M50,85 C50,85 20,60 20,40 A12,12 0 0,1 50,40 A12,12 0 0,1 80,40 C80,60 50,85 50,85 Z" 
        fill="red">
    <animateTransform
      attributeName="transform"
      type="scale"
      values="1;1.3;1"
      additive="sum"
      dur="1s"
      repeatCount="indefinite"/>
  </path>
</svg>
''',
    ),

    // ============ COLOR ANIMATIONS ============
    SvgExample(
      id: 'color_fill',
      title: 'Rainbow Circle',
      description: 'Fill color interpolation',
      category: ExampleCategory.color,
      icon: Icons.palette,
      tags: ['animate', 'fill', 'color'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="30" fill="red">
    <animate 
      attributeName="fill" 
      values="red;orange;yellow;green;blue;indigo;violet;red" 
      dur="4s" 
      repeatCount="indefinite"/>
  </circle>
</svg>
''',
    ),

    SvgExample(
      id: 'color_stroke',
      title: 'Colorful Border',
      description: 'Stroke color animation',
      category: ExampleCategory.color,
      icon: Icons.border_color,
      tags: ['animate', 'stroke', 'color'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="20" width="60" height="60" fill="none" stroke="blue" stroke-width="4">
    <animate 
      attributeName="stroke" 
      values="blue;cyan;blue" 
      dur="2s" 
      repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    // ============ PATH ANIMATIONS ============
    SvgExample(
      id: 'path_morph_simple',
      title: 'Square to Circle',
      description: 'Path morphing between shapes',
      category: ExampleCategory.path,
      icon: Icons.transform,
      tags: ['animate', 'd', 'morph', 'path'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path fill="teal">
    <animate
      attributeName="d"
      dur="2s"
      repeatCount="indefinite"
      values="
        M 30,30 L 70,30 L 70,70 L 30,70 Z;
        M 50,20 A 30,30 0 1,1 49.9,20 Z;
        M 30,30 L 70,30 L 70,70 L 30,70 Z
      "/>
  </path>
</svg>
''',
    ),

    SvgExample(
      id: 'path_morph_star',
      title: 'Star to Pentagon',
      description: 'Complex path morphing',
      category: ExampleCategory.path,
      icon: Icons.star,
      tags: ['animate', 'd', 'morph', 'star'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path fill="gold">
    <animate
      attributeName="d"
      dur="3s"
      repeatCount="indefinite"
      values="
        M50,15 L61,40 L88,40 L67,56 L76,82 L50,65 L24,82 L33,56 L12,40 L39,40 Z;
        M50,20 L73,35 L80,62 L50,80 L20,62 L27,35 Z;
        M50,15 L61,40 L88,40 L67,56 L76,82 L50,65 L24,82 L33,56 L12,40 L39,40 Z
      "/>
  </path>
</svg>
''',
    ),

    // ============ MOTION ANIMATIONS ============
    SvgExample(
      id: 'motion_circle',
      title: 'Circle Path',
      description: 'animateMotion along circular path',
      category: ExampleCategory.motion,
      icon: Icons.trip_origin,
      tags: ['animateMotion', 'path', 'circle'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 50,50 m -40,0 a 40,40 0 1,0 80,0 a 40,40 0 1,0 -80,0" 
        fill="none" stroke="#ddd" stroke-width="1"/>
  <circle r="5" fill="blue">
    <animateMotion dur="3s" repeatCount="indefinite">
      <mpath href="#circlePath"/>
    </animateMotion>
  </circle>
  <path id="circlePath" d="M 50,50 m -40,0 a 40,40 0 1,0 80,0 a 40,40 0 1,0 -80,0" 
        fill="none" stroke="none"/>
</svg>
''',
    ),

    SvgExample(
      id: 'motion_auto_rotate',
      title: 'Car on Track',
      description: 'animateMotion with auto rotation',
      category: ExampleCategory.motion,
      icon: Icons.directions_car,
      tags: ['animateMotion', 'rotate', 'auto'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M 10,50 Q 30,20 50,50 T 90,50" 
        fill="none" stroke="#ddd" stroke-width="2"/>
  <rect width="10" height="6" x="-5" y="-3" fill="red" rx="1">
    <animateMotion dur="4s" repeatCount="indefinite" rotate="auto">
      <mpath href="#track"/>
    </animateMotion>
  </rect>
  <path id="track" d="M 10,50 Q 30,20 50,50 T 90,50" fill="none"/>
</svg>
''',
    ),

    // ============ ADVANCED ANIMATIONS ============
    SvgExample(
      id: 'advanced_clock',
      title: 'Animated Clock',
      description: 'Multiple synchronized animations',
      category: ExampleCategory.advanced,
      icon: Icons.access_time,
      tags: ['multiple', 'rotate', 'clock'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="none" stroke="black" stroke-width="2"/>
  <!-- Hour hand -->
  <line x1="50" y1="50" x2="50" y2="30" stroke="black" stroke-width="3">
    <animateTransform
      attributeName="transform"
      type="rotate"
      from="0 50 50"
      to="360 50 50"
      dur="12s"
      repeatCount="indefinite"/>
  </line>
  <!-- Minute hand -->
  <line x1="50" y1="50" x2="50" y2="20" stroke="blue" stroke-width="2">
    <animateTransform
      attributeName="transform"
      type="rotate"
      from="0 50 50"
      to="360 50 50"
      dur="4s"
      repeatCount="indefinite"/>
  </line>
  <circle cx="50" cy="50" r="3" fill="red"/>
</svg>
''',
    ),

    SvgExample(
      id: 'advanced_loading',
      title: 'Loading Spinner',
      description: 'Rotation + opacity combination',
      category: ExampleCategory.advanced,
      icon: Icons.refresh,
      tags: ['rotate', 'opacity', 'loading'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <g>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="1">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(45 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.125s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(90 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.25s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(135 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.375s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(180 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.5s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(225 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.625s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(270 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.75s" repeatCount="indefinite"/>
    </rect>
    <rect x="47" y="10" width="6" height="25" rx="3" fill="blue" opacity="0.2" transform="rotate(315 50 50)">
      <animate attributeName="opacity" values="1;0.2" dur="1s" begin="0.875s" repeatCount="indefinite"/>
    </rect>
  </g>
</svg>
''',
    ),

    // ============ MORE TRANSFORM EXAMPLES ============
    SvgExample(
      id: 'transform_combined',
      title: 'Combined Transforms',
      description: 'Multiple simultaneous transformations',
      category: ExampleCategory.transform,
      icon: Icons.transform,
      tags: ['animateTransform', 'rotate', 'scale', 'combined'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="40" y="40" width="20" height="20" fill="purple">
    <animateTransform
      attributeName="transform"
      type="rotate"
      from="0 50 50"
      to="360 50 50"
      dur="3s"
      repeatCount="indefinite"/>
    <animateTransform
      attributeName="transform"
      type="scale"
      values="1;1.5;1"
      dur="3s"
      repeatCount="indefinite"
      additive="sum"/>
  </rect>
</svg>
''',
    ),

    SvgExample(
      id: 'transform_skewx',
      title: 'Skew X',
      description: 'Horizontal skew transformation',
      category: ExampleCategory.transform,
      icon: Icons.format_shapes,
      tags: ['animateTransform', 'skewX', 'transform'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="30" y="30" width="40" height="40" fill="teal">
    <animateTransform
      attributeName="transform"
      type="skewX"
      values="0;30;-30;0"
      dur="4s"
      repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    // ============ MORE BASIC EXAMPLES ============
    SvgExample(
      id: 'basic_width_height',
      title: 'Growing Rectangle',
      description: 'Animating width and height',
      category: ExampleCategory.basic,
      icon: Icons.crop_square,
      tags: ['animate', 'width', 'height'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="25" y="25" fill="green">
    <animate attributeName="width" values="10;50;10" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="height" values="10;50;10" dur="2s" repeatCount="indefinite"/>
  </rect>
</svg>
''',
    ),

    SvgExample(
      id: 'basic_stroke_width',
      title: 'Pulsing Border',
      description: 'Animating stroke width',
      category: ExampleCategory.basic,
      icon: Icons.border_outer,
      tags: ['animate', 'stroke-width', 'border'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="30" fill="none" stroke="purple">
    <animate attributeName="stroke-width" values="1;8;1" dur="1.5s" repeatCount="indefinite"/>
  </circle>
</svg>
''',
    ),

    // ============ MORE COLOR EXAMPLES ============
    SvgExample(
      id: 'color_gradient',
      title: 'Gradient Shift',
      description: 'Animating gradient colors',
      category: ExampleCategory.color,
      icon: Icons.gradient,
      tags: ['animate', 'fill', 'gradient'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:rgb(255,255,0);stop-opacity:1">
        <animate attributeName="stop-color" values="yellow;red;blue;yellow" dur="3s" repeatCount="indefinite"/>
      </stop>
      <stop offset="100%" style="stop-color:rgb(0,0,255);stop-opacity:1">
        <animate attributeName="stop-color" values="blue;green;red;blue" dur="3s" repeatCount="indefinite"/>
      </stop>
    </linearGradient>
  </defs>
  <rect x="20" y="20" width="60" height="60" fill="url(#grad1)"/>
</svg>
''',
    ),

    SvgExample(
      id: 'color_opacity',
      title: 'Fading Colors',
      description: 'Combined color and opacity animation',
      category: ExampleCategory.color,
      icon: Icons.opacity,
      tags: ['animate', 'fill', 'opacity'],
      svgContent: '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="25">
    <animate attributeName="fill" values="red;green;blue;red" dur="3s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="1;0.3;1" dur="3s" repeatCount="indefinite"/>
  </circle>
</svg>
''',
    ),
  ];

  static List<SvgExample> getByCategory(String category) {
    return all.where((example) => example.category == category).toList();
  }

  static List<String> get categories {
    return all.map((e) => e.category).toSet().toList();
  }
}
