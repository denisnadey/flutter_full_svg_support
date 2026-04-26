import 'dart:math' as math;

import 'css_animations.dart';
import 'css_variables_calc.dart';
import 'smil/smil_animation.dart';
import 'svg_dom.dart';

part 'css_to_smil_converter_core.dart';
part 'css_to_smil_converter_timing.dart';
part 'css_to_smil_converter_transforms.dart';
part 'css_to_smil_converter_transforms_values.dart';

/// Converter of CSS animations to SMIL structure
class CssToSmilConverter {
  /// Converts CSS keyframes and animation into a list of SMIL animations
  static List<SmilAnimation> convert(
    CssKeyframes keyframes,
    CssAnimation animation,
    SvgNode targetNode,
    SvgDocument document,
  ) {
    final smilAnimations = <SmilAnimation>[];

    // For each property in the keyframes, create a separate SMIL animation
    final animatedProperties = _extractAnimatedProperties(keyframes);

    for (final property in animatedProperties.entries) {
      final propertyName = property.key;
      final values = property.value;

      // Determine the attribute type
      final attributeType = _inferAttributeType(propertyName, targetNode);

      // CSS transform animations use REPLACE semantics - each keyframe value
      // is the complete transform. DO NOT decompose into per-function animations
      // with additive=sum, as that would cause double-application.
      // The transform interpolator handles compound transforms via decomposition
      // internally, and _createSmilAnimation uses additive=replace which matches
      // CSS semantics. So we let transforms go through the normal path below.

      // Create a SMIL animation
      final smilAnim = _createSmilAnimation(
        keyframes: keyframes,
        animation: animation,
        targetNode: targetNode,
        attributeName: propertyName,
        attributeType: attributeType,
        values: values,
      );

      if (smilAnim != null) {
        smilAnimations.add(smilAnim);
      }
    }

    return smilAnimations;
  }
}
