/// SMIL/CSS Animation support for flutter_svg
///
/// This library provides support for animated SVG files using SMIL animations.
///
/// Example:
/// ```dart
/// import 'package:flutter_svg/src/animation.dart';
///
/// AnimatedSvgPicture.string(
///   '''<svg viewBox="0 0 100 100">
///     <rect x="0" y="0" width="20" height="20" fill="blue">
///       <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
///     </rect>
///   </svg>''',
///   width: 200,
///   height: 200,
/// )
/// ```
library;

export 'animation/animated_svg_painter.dart';
export 'animation/animated_svg_picture.dart';
export 'animation/animated_svg_controller.dart';
export 'animation/animation_detector.dart';
export 'animation/smil/smil_animation.dart';
export 'animation/smil/smil_timeline.dart';
export 'animation/smil/timing_condition.dart';
export 'animation/smil/timing_parser.dart';
export 'animation/svg_dom.dart';
export 'animation/svg_parser.dart';
