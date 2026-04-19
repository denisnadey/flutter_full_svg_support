part of 'svg_parser.dart';

/// Парсит цвет
Object _parseColor(String value) {
  final trimmed = value.trim().toLowerCase();

  // paint servers, e.g. url(#gradientId)
  if (trimmed.startsWith('url(')) {
    return value.trim();
  }

  // Preserve keyword values that must be resolved later in context.
  if (trimmed == 'currentcolor' || trimmed == 'inherit') {
    return value.trim();
  }

  // Пока возвращаем строку, позже добавим полный парсинг
  // #RGB, #RRGGBB, rgb(), rgba(), named colors, etc.
  if (trimmed == 'none' || trimmed == 'transparent') {
    return ui.Color(0x00000000);
  }

  // Именованные цвета (базовые)
  if (_namedColors.containsKey(trimmed)) {
    return _namedColors[trimmed]!;
  }

  // #RGB/#RGBA/#RRGGBB/#RRGGBBAA
  if (trimmed.startsWith('#')) {
    return _parseHexColor(trimmed);
  }

  // rgb()/rgba()
  final rgbColor = _parseRgbColor(trimmed);
  if (rgbColor != null) {
    return rgbColor;
  }

  // hsl()/hsla()
  final hslColor = _parseHslColor(trimmed);
  if (hslColor != null) {
    return hslColor;
  }

  // Unsupported token: preserve as string so later context-aware resolution
  // can handle it (for example presentation attributes resolved during paint).
  return value.trim();
}

/// Парсит hex цвет
ui.Color _parseHexColor(String hex) {
  var cleaned = hex.substring(1); // убираем #

  // #RGB -> #RRGGBB
  if (cleaned.length == 3) {
    cleaned = cleaned.split('').map((c) => c + c).join();
  }

  // #RGBA -> #RRGGBBAA
  if (cleaned.length == 4) {
    cleaned = cleaned.split('').map((c) => c + c).join();
  }

  // #RRGGBB
  if (cleaned.length == 6) {
    final value = int.tryParse('FF$cleaned', radix: 16);
    return ui.Color(value ?? 0xFF000000);
  }

  // #RRGGBBAA
  if (cleaned.length == 8) {
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) {
      return const ui.Color(0xFF000000);
    }

    final r = (parsed >> 24) & 0xFF;
    final g = (parsed >> 16) & 0xFF;
    final b = (parsed >> 8) & 0xFF;
    final a = parsed & 0xFF;
    return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
  }

  return const ui.Color(0xFF000000);
}

ui.Color? _parseRgbColor(String value) {
  final match = RegExp(r'^rgba?\(\s*(.+)\s*\)$').firstMatch(value);
  if (match == null) {
    return null;
  }

  final args = _parseColorFunctionArgs(match.group(1)!);
  if (args.length < 3) {
    return null;
  }

  double alpha = 1.0;
  late final int r;
  late final int g;
  late final int b;

  if (args.contains('/')) {
    final slashIndex = args.indexOf('/');
    if (slashIndex != 3 || args.length != 5) {
      return null;
    }
    r = _parseRgbChannel(args[0]);
    g = _parseRgbChannel(args[1]);
    b = _parseRgbChannel(args[2]);
    alpha = _parseAlpha(args[4]);
  } else {
    if (args.length < 3) {
      return null;
    }
    r = _parseRgbChannel(args[0]);
    g = _parseRgbChannel(args[1]);
    b = _parseRgbChannel(args[2]);
    if (args.length >= 4) {
      alpha = _parseAlpha(args[3]);
    }
  }

  return _colorFromRgba(r, g, b, alpha);
}

ui.Color? _parseHslColor(String value) {
  final match = RegExp(r'^hsla?\(\s*(.+)\s*\)$').firstMatch(value);
  if (match == null) {
    return null;
  }

  final args = _parseColorFunctionArgs(match.group(1)!);
  if (args.length < 3) {
    return null;
  }

  double alpha = 1.0;
  late final double hue;
  late final double saturation;
  late final double lightness;

  if (args.contains('/')) {
    final slashIndex = args.indexOf('/');
    if (slashIndex != 3 || args.length != 5) {
      return null;
    }
    hue = _parseHueDegrees(args[0]);
    saturation = _parseFraction(args[1]);
    lightness = _parseFraction(args[2]);
    alpha = _parseAlpha(args[4]);
  } else {
    hue = _parseHueDegrees(args[0]);
    saturation = _parseFraction(args[1]);
    lightness = _parseFraction(args[2]);
    if (args.length >= 4) {
      alpha = _parseAlpha(args[3]);
    }
  }

  return _hslToColor(hue, saturation, lightness, alpha);
}

List<String> _parseColorFunctionArgs(String input) {
  if (input.contains(',')) {
    return input
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  return input
      .replaceAll('/', ' / ')
      .split(RegExp(r'\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

int _parseRgbChannel(String input) {
  final value = input.trim();
  if (value.endsWith('%')) {
    final percent =
        double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
    final normalized = percent.clamp(0.0, 100.0) / 100.0;
    return (normalized * 255).round();
  }

  final number = double.tryParse(value) ?? 0.0;
  return number.clamp(0.0, 255.0).round();
}

double _parseAlpha(String input) {
  final value = input.trim();
  if (value.endsWith('%')) {
    final percent =
        double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
    return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
  }

  final alpha = double.tryParse(value) ?? 1.0;
  return alpha.clamp(0.0, 1.0).toDouble();
}

double _parseFraction(String input) {
  final value = input.trim();
  if (value.endsWith('%')) {
    final percent =
        double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
    return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
  }

  final number = double.tryParse(value) ?? 0.0;
  return number.clamp(0.0, 1.0).toDouble();
}

double _parseHueDegrees(String input) {
  final match = RegExp(
    r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
    caseSensitive: false,
  ).firstMatch(input.trim());
  if (match == null) {
    return 0.0;
  }

  final value = double.tryParse(match.group(1) ?? '') ?? 0.0;
  final unit = (match.group(2) ?? 'deg').toLowerCase();
  return switch (unit) {
    'deg' => value,
    'rad' => value * 180.0 / math.pi,
    'turn' => value * 360.0,
    'grad' => value * 0.9,
    _ => value,
  };
}

ui.Color _colorFromRgba(int r, int g, int b, double alpha) {
  final a = (alpha.clamp(0.0, 1.0) * 255).round();
  return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
}

ui.Color _hslToColor(
  double hueDegrees,
  double saturation,
  double lightness,
  double alpha,
) {
  final h = ((hueDegrees % 360.0) + 360.0) % 360.0 / 360.0;
  final s = saturation.clamp(0.0, 1.0).toDouble();
  final l = lightness.clamp(0.0, 1.0).toDouble();

  if (s == 0.0) {
    final gray = (l * 255).round();
    return _colorFromRgba(gray, gray, gray, alpha);
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  final r = _hueToRgb(p, q, h + (1 / 3));
  final g = _hueToRgb(p, q, h);
  final b = _hueToRgb(p, q, h - (1 / 3));
  return _colorFromRgba(
    (r * 255).round(),
    (g * 255).round(),
    (b * 255).round(),
    alpha,
  );
}

double _hueToRgb(double p, double q, double t) {
  var adjusted = t;
  if (adjusted < 0) adjusted += 1;
  if (adjusted > 1) adjusted -= 1;

  if (adjusted < 1 / 6) {
    return p + (q - p) * 6 * adjusted;
  }
  if (adjusted < 1 / 2) {
    return q;
  }
  if (adjusted < 2 / 3) {
    return p + (q - p) * (2 / 3 - adjusted) * 6;
  }
  return p;
}
