import 'dart:ui' as ui;

import '../svg_dom.dart';
import '../svg_transform.dart';
import '../path_data.dart';
import '../path_parser.dart';
import '../path_normalizer.dart';

/// Утилиты для интерполяции различных типов значений
class Interpolators {
  Interpolators._();

  /// Интерполировать значение в зависимости от его типа
  static Object? interpolate(
    Object from,
    Object to,
    double t,
    SvgAttributeType type,
  ) {
    switch (type) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        return interpolateNumber(from, to, t);

      case SvgAttributeType.color:
        return interpolateColor(from, to, t);

      case SvgAttributeType.transform:
        return interpolateTransform(from, to, t);

      case SvgAttributeType.path:
        return interpolatePath(from, to, t);

      case SvgAttributeType.points:
      case SvgAttributeType.list:
        return interpolateList(from, to, t);

      case SvgAttributeType.string:
      case SvgAttributeType.url:
        // Дискретная интерполяция для строк
        return t < 0.5 ? from : to;
    }
  }

  /// Интерполировать числовое значение
  static double interpolateNumber(Object from, Object to, double t) {
    final fromNum = _toNumber(from);
    final toNum = _toNumber(to);

    if (fromNum == null || toNum == null) {
      return toNum ?? fromNum ?? 0.0;
    }

    return fromNum + (toNum - fromNum) * t;
  }

  /// Интерполировать цвет
  static ui.Color interpolateColor(Object from, Object to, double t) {
    final fromColor = _toColor(from);
    final toColor = _toColor(to);

    if (fromColor == null || toColor == null) {
      return toColor ?? fromColor ?? const ui.Color(0xFF000000);
    }

    // Интерполяция в RGB пространстве
    final r = _lerpInt(fromColor.red, toColor.red, t);
    final g = _lerpInt(fromColor.green, toColor.green, t);
    final b = _lerpInt(fromColor.blue, toColor.blue, t);
    final a = _lerpInt(fromColor.alpha, toColor.alpha, t);

    return ui.Color.fromARGB(a, r, g, b);
  }

  /// Интерполировать SVG path
  static String interpolatePath(Object from, Object to, double t) {
    final fromStr = from.toString();
    final toStr = to.toString();

    // Если одна из строк пуста, используем дискретную интерполяцию
    if (fromStr.isEmpty || toStr.isEmpty) {
      return t < 0.5 ? fromStr : toStr;
    }

    // Clamp t to [0, 1]
    final clampedT = t.clamp(0.0, 1.0);

    try {
      // Парсим пути
      final parser = PathParser();
      final fromCommands = parser.parse(fromStr);
      final toCommands = parser.parse(toStr);

      // Нормализуем пути
      final normalizer = PathNormalizer();
      final normalizedPair = normalizer.normalize(fromCommands, toCommands);

      // Интерполируем команды вручную для получения строкового представления
      final interpolatedCommands = <PathCommand>[];
      for (int i = 0; i < normalizedPair.from.length; i++) {
        final cmdFrom = normalizedPair.from[i];
        final cmdTo = normalizedPair.to[i];

        interpolatedCommands.add(_interpolateCommand(cmdFrom, cmdTo, clampedT));
      }

      // Конвертируем обратно в строку
      return _pathCommandsToString(interpolatedCommands);
    } catch (e) {
      // В случае ошибки парсинга используем дискретную интерполяцию
      return clampedT < 0.5 ? fromStr : toStr;
    }
  }

  /// Интерполировать одну команду пути
  static PathCommand _interpolateCommand(
    PathCommand from,
    PathCommand to,
    double t,
  ) {
    if (from is MoveToCommand && to is MoveToCommand) {
      return MoveToCommand(
        x: from.x + (to.x - from.x) * t,
        y: from.y + (to.y - from.y) * t,
      );
    } else if (from is CubicBezierCommand && to is CubicBezierCommand) {
      return CubicBezierCommand(
        x1: from.x1 + (to.x1 - from.x1) * t,
        y1: from.y1 + (to.y1 - from.y1) * t,
        x2: from.x2 + (to.x2 - from.x2) * t,
        y2: from.y2 + (to.y2 - from.y2) * t,
        x: from.x + (to.x - from.x) * t,
        y: from.y + (to.y - from.y) * t,
      );
    } else if (from is ClosePathCommand) {
      return const ClosePathCommand();
    }

    // Fallback - не должно случиться если пути нормализованы
    return from;
  }

  /// Конвертировать команды пути в SVG path строку
  static String _pathCommandsToString(List<PathCommand> commands) {
    final buffer = StringBuffer();

    for (final cmd in commands) {
      if (cmd is MoveToCommand) {
        buffer.write(
          'M${cmd.x.toStringAsFixed(2)},${cmd.y.toStringAsFixed(2)} ',
        );
      } else if (cmd is CubicBezierCommand) {
        buffer.write(
          'C${cmd.x1.toStringAsFixed(2)},${cmd.y1.toStringAsFixed(2)} '
          '${cmd.x2.toStringAsFixed(2)},${cmd.y2.toStringAsFixed(2)} '
          '${cmd.x.toStringAsFixed(2)},${cmd.y.toStringAsFixed(2)} ',
        );
      } else if (cmd is ClosePathCommand) {
        buffer.write('Z ');
      }
    }

    return buffer.toString().trim();
  }

  /// Интерполировать список значений (например, для points, stroke-dasharray)
  static List<double> interpolateList(Object from, Object to, double t) {
    final fromList = _toNumberList(from);
    final toList = _toNumberList(to);

    if (fromList == null || toList == null) {
      return toList ?? fromList ?? [];
    }

    // Если длины не совпадают, используем дискретную интерполяцию
    if (fromList.length != toList.length) {
      return t < 0.5 ? fromList : toList;
    }

    // Интерполируем каждый элемент
    final result = <double>[];
    for (int i = 0; i < fromList.length; i++) {
      result.add(fromList[i] + (toList[i] - fromList[i]) * t);
    }

    return result;
  }

  /// Интерполировать трансформацию
  static String interpolateTransform(Object from, Object to, double t) {
    // Парсим обе трансформации
    final fromTransforms = SvgTransform.parse(from.toString());
    final toTransforms = SvgTransform.parse(to.toString());

    // Если одна из трансформаций пуста, используем дискретную интерполяцию
    if (fromTransforms.isEmpty || toTransforms.isEmpty) {
      return t < 0.5 ? from.toString() : to.toString();
    }

    // Для одиночной трансформации одного типа - прямая интерполяция
    if (fromTransforms.length == 1 &&
        toTransforms.length == 1 &&
        fromTransforms[0].type == toTransforms[0].type) {
      return _interpolateSingleTransform(fromTransforms[0], toTransforms[0], t);
    }

    // Для сложных трансформаций используем декомпозицию
    final fromDecomp = TransformDecomposition.fromTransforms(fromTransforms);
    final toDecomp = TransformDecomposition.fromTransforms(toTransforms);

    // Интерполируем компоненты
    final interpolated = fromDecomp.lerp(toDecomp, t);

    // Преобразуем обратно в список трансформаций
    final resultTransforms = interpolated.toTransforms();

    // Формируем строку результата
    return resultTransforms
        .map((transform) {
          final name = transform.type.toString().split('.').last;
          final values = transform.values
              .map((v) => v.toStringAsFixed(2))
              .join(', ');
          return '$name($values)';
        })
        .join(' ');
  }

  /// Интерполировать одну трансформацию
  static String _interpolateSingleTransform(
    SvgTransform from,
    SvgTransform to,
    double t,
  ) {
    final type = from.type;
    final name = type.toString().split('.').last;

    // Интерполируем каждое значение
    final maxLength = from.values.length > to.values.length
        ? from.values.length
        : to.values.length;

    final interpolatedValues = <double>[];
    for (int i = 0; i < maxLength; i++) {
      final fromVal = i < from.values.length ? from.values[i] : 0.0;
      final toVal = i < to.values.length ? to.values[i] : 0.0;
      interpolatedValues.add(fromVal + (toVal - fromVal) * t);
    }

    final valueStr = interpolatedValues
        .map((v) => v.toStringAsFixed(2))
        .join(' ');
    return '$name($valueStr)';
  }

  /// Сложить два значения (для additive='sum')
  static Object? add(Object base, Object delta, SvgAttributeType type) {
    switch (type) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        final baseNum = _toNumber(base);
        final deltaNum = _toNumber(delta);
        if (baseNum != null && deltaNum != null) {
          return baseNum + deltaNum;
        }
        return base;

      case SvgAttributeType.list:
      case SvgAttributeType.points:
        final baseList = _toNumberList(base);
        final deltaList = _toNumberList(delta);
        if (baseList != null &&
            deltaList != null &&
            baseList.length == deltaList.length) {
          final result = <double>[];
          for (int i = 0; i < baseList.length; i++) {
            result.add(baseList[i] + deltaList[i]);
          }
          return result;
        }
        return base;

      default:
        // Для других типов сложение не поддерживается
        return base;
    }
  }

  // === Вспомогательные методы ===

  /// Преобразовать значение в число
  static double? _toNumber(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Убираем единицы измерения
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  /// Преобразовать значение в цвет
  static ui.Color? _toColor(Object? value) {
    if (value == null) return null;
    if (value is ui.Color) return value;
    if (value is String) {
      // Упрощённый парсинг - будет расширен позже
      return _parseColorString(value);
    }
    return null;
  }

  /// Преобразовать значение в список чисел
  static List<double>? _toNumberList(Object? value) {
    if (value == null) return null;
    if (value is List<double>) return value;
    if (value is List) {
      return value.map((e) => _toNumber(e) ?? 0.0).toList();
    }
    if (value is String) {
      // Парсим строку как список чисел, разделённых пробелами или запятыми
      final parts = value
          .trim()
          .split(RegExp(r'[\s,]+'))
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      return parts.isNotEmpty ? parts : null;
    }
    return null;
  }

  /// Линейная интерполяция целых чисел
  static int _lerpInt(int a, int b, double t) {
    return (a + (b - a) * t).round().clamp(0, 255);
  }

  /// Упрощённый парсер цветов
  static ui.Color? _parseColorString(String value) {
    final trimmed = value.trim().toLowerCase();

    // Прозрачный
    if (trimmed == 'none' || trimmed == 'transparent') {
      return const ui.Color(0x00000000);
    }

    // Hex цвет
    if (trimmed.startsWith('#')) {
      return _parseHexColor(trimmed);
    }

    // rgb() или rgba()
    if (trimmed.startsWith('rgb')) {
      return _parseRgbColor(trimmed);
    }

    // Именованные цвета
    return _namedColors[trimmed];
  }

  /// Парсить hex цвет
  static ui.Color? _parseHexColor(String hex) {
    var cleaned = hex.substring(1); // убираем #

    // #RGB -> #RRGGBB
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RRGGBB
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      return value != null ? ui.Color(value) : null;
    }

    // #RRGGBBAA
    if (cleaned.length == 8) {
      final value = int.tryParse(cleaned, radix: 16);
      return value != null ? ui.Color(value) : null;
    }

    return null;
  }

  /// Парсить rgb() или rgba() цвет
  static ui.Color? _parseRgbColor(String rgb) {
    // rgb(255, 0, 0) или rgba(255, 0, 0, 1.0)
    final match = RegExp(
      r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)',
    ).firstMatch(rgb);

    if (match != null) {
      final r = int.tryParse(match.group(1)!) ?? 0;
      final g = int.tryParse(match.group(2)!) ?? 0;
      final b = int.tryParse(match.group(3)!) ?? 0;
      final a = match.group(4) != null
          ? (double.tryParse(match.group(4)!) ?? 1.0)
          : 1.0;

      return ui.Color.fromARGB(
        (a * 255).round(),
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }

    return null;
  }

  // Базовые именованные цвета (расширенный список)
  static const Map<String, ui.Color> _namedColors = {
    // Основные
    'black': ui.Color(0xFF000000),
    'white': ui.Color(0xFFFFFFFF),
    'red': ui.Color(0xFFFF0000),
    'green': ui.Color(0xFF008000),
    'blue': ui.Color(0xFF0000FF),
    'yellow': ui.Color(0xFFFFFF00),
    'cyan': ui.Color(0xFF00FFFF),
    'magenta': ui.Color(0xFFFF00FF),
    'gray': ui.Color(0xFF808080),
    'grey': ui.Color(0xFF808080),
    'orange': ui.Color(0xFFFFA500),
    'purple': ui.Color(0xFF800080),
    'pink': ui.Color(0xFFFFC0CB),
    'brown': ui.Color(0xFFA52A2A),

    // Дополнительные популярные
    'lime': ui.Color(0xFF00FF00),
    'navy': ui.Color(0xFF000080),
    'olive': ui.Color(0xFF808000),
    'maroon': ui.Color(0xFF800000),
    'teal': ui.Color(0xFF008080),
    'aqua': ui.Color(0xFF00FFFF),
    'fuchsia': ui.Color(0xFFFF00FF),
    'silver': ui.Color(0xFFC0C0C0),

    // Оттенки серого
    'darkgray': ui.Color(0xFFA9A9A9),
    'darkgrey': ui.Color(0xFFA9A9A9),
    'lightgray': ui.Color(0xFFD3D3D3),
    'lightgrey': ui.Color(0xFFD3D3D3),
    'dimgray': ui.Color(0xFF696969),
    'dimgrey': ui.Color(0xFF696969),
  };
}
