import 'dart:math' as math;

import 'css_animations.dart';
import 'css_variables_calc.dart';
import 'smil/smil_animation.dart';
import 'svg_dom.dart';

part 'css_to_smil_converter_core.dart';
part 'css_to_smil_converter_timing.dart';
part 'css_to_smil_converter_transforms.dart';
part 'css_to_smil_converter_transforms_values.dart';

/// Конвертер CSS анимаций в SMIL структуру
class CssToSmilConverter {
  /// Конвертирует CSS keyframes и animation в список SMIL анимаций
  static List<SmilAnimation> convert(
    CssKeyframes keyframes,
    CssAnimation animation,
    SvgNode targetNode,
    SvgDocument document,
  ) {
    final smilAnimations = <SmilAnimation>[];

    // Для каждого свойства в keyframes создаём отдельную SMIL анимацию
    final animatedProperties = _extractAnimatedProperties(keyframes);

    for (final property in animatedProperties.entries) {
      final propertyName = property.key;
      final values = property.value;

      // Определяем тип атрибута
      final attributeType = _inferAttributeType(propertyName, targetNode);

      // CSS transform animations use REPLACE semantics - each keyframe value
      // is the complete transform. DO NOT decompose into per-function animations
      // with additive=sum, as that would cause double-application.
      // The transform interpolator handles compound transforms via decomposition
      // internally, and _createSmilAnimation uses additive=replace which matches
      // CSS semantics. So we let transforms go through the normal path below.

      // Создаём SMIL анимацию
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
