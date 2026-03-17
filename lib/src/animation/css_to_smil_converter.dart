import 'dart:math' as math;

import 'css_animations.dart';
import 'css_variables_calc.dart';
import 'smil/smil_animation.dart';
import 'svg_dom.dart';

part 'css_to_smil_converter_core.dart';
part 'css_to_smil_converter_timing.dart';
part 'css_to_smil_converter_transforms.dart';
part 'css_to_smil_converter_transforms_decompose.dart';
part 'css_to_smil_converter_transforms_decompose_timing.dart';
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

      // Для transform: проверяем не является ли значение compound transform.
      // SVGator генерирует: translate(Xpx,Ypx) scale(sx,sy) — несколько функций.
      // Такой compound нужно разложить на отдельные SmilAnimation per-function.
      if (propertyName == 'transform' &&
          attributeType == SvgAttributeType.transform) {
        final decomposed = _decomposeCompoundTransform(
          keyframes: keyframes,
          animation: animation,
          targetNode: targetNode,
          values: values,
        );
        smilAnimations.addAll(decomposed);
        continue;
      }

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
