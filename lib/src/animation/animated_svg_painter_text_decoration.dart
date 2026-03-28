part of 'animated_svg_painter.dart';

/// Text decoration and visual effects utilities.
///
/// Contains methods for:
/// - Decoration rendering (underline, overline, line-through)
/// - Text shadow parsing and rendering
/// - Text emphasis marks (CJK typography)
/// - Text transform (capitalize, uppercase, lowercase)
/// - Color resolution for text effects
extension AnimatedSvgPainterTextDecorationExtension on AnimatedSvgPainter {
  /// Draws a paragraph with optional effects (filter, color filter, blend mode).
  void _drawParagraphWithEffects(
    ui.Canvas canvas, {
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    _ResolvedTextStyle? style,
    String? text,
  }) {
    if (imageFilter == null && colorFilter == null && blendMode == null) {
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
      if (style != null && text != null && style.textEmphasisStyle != null) {
        _drawTextEmphasisMarks(canvas, paragraph, x, y, text, style);
      }
      return;
    }

    final layerPaint = ui.Paint();
    if (imageFilter != null) layerPaint.imageFilter = imageFilter;
    if (colorFilter != null) layerPaint.colorFilter = colorFilter;
    if (blendMode != null) layerPaint.blendMode = blendMode;
    final bounds = ui.Rect.fromLTWH(
      x,
      y,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    ).inflate(1.0);
    canvas.saveLayer(bounds, layerPaint);
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
    if (style != null && text != null && style.textEmphasisStyle != null) {
      _drawTextEmphasisMarks(canvas, paragraph, x, y, text, style);
    }
    canvas.restore();
  }

  /// Draws text emphasis marks above or below text.
  void _drawTextEmphasisMarks(
    ui.Canvas canvas,
    ui.Paragraph paragraph,
    double x,
    double y,
    String text,
    _ResolvedTextStyle style,
  ) {
    final emphasisStyle = style.textEmphasisStyle;
    if (emphasisStyle == null) return;

    final emphasisMark = _resolveEmphasisMarkCharacter(emphasisStyle);
    if (emphasisMark == null) return;

    final position = style.textEmphasisPosition;
    final isAbove = !position.contains('under');

    final emphasisColor = style.textEmphasisColor != null
        ? _resolveColorFromString(style.textEmphasisColor!)
        : style.color;
    final markFontSize = style.fontSize * 0.5;
    final markSpacing = style.fontSize * 0.2;

    final emphasisParagraphStyle = ui.ParagraphStyle(
      fontSize: markFontSize,
      textAlign: ui.TextAlign.center,
    );
    final emphasisBuilder = ui.ParagraphBuilder(emphasisParagraphStyle);
    emphasisBuilder.pushStyle(
      ui.TextStyle(color: emphasisColor, fontSize: markFontSize),
    );
    emphasisBuilder.addText(emphasisMark);
    final emphasisParagraph = emphasisBuilder.build();
    emphasisParagraph.layout(const ui.ParagraphConstraints(width: 100));

    final glyphs = text.runes.map((r) => String.fromCharCode(r)).toList();
    var charX = x;

    for (var i = 0; i < glyphs.length; i++) {
      final glyph = glyphs[i];
      if (glyph == ' ' || glyph == '\t' || glyph == '\n') {
        final glyphParagraph = _buildTextParagraph(glyph, style);
        charX += glyphParagraph.maxIntrinsicWidth + style.letterSpacing;
        continue;
      }

      final glyphParagraph = _buildTextParagraph(glyph, style);
      final glyphWidth = glyphParagraph.maxIntrinsicWidth;
      final markX =
          charX + (glyphWidth - emphasisParagraph.maxIntrinsicWidth) / 2;
      final markY = isAbove
          ? y - markSpacing - emphasisParagraph.height
          : y + paragraph.height + markSpacing;
      canvas.drawParagraph(emphasisParagraph, ui.Offset(markX, markY));
      charX += glyphWidth + style.letterSpacing;
    }
  }

  /// Resolves emphasis mark character from style value.
  String? _resolveEmphasisMarkCharacter(String style) {
    final normalized = style.toLowerCase();
    final parts = normalized.split(RegExp(r'\s+'));

    var isFilled = true;
    String? markType;

    for (final part in parts) {
      switch (part) {
        case 'filled':
          isFilled = true;
          break;
        case 'open':
          isFilled = false;
          break;
        case 'dot':
        case 'circle':
        case 'double-circle':
        case 'triangle':
        case 'sesame':
          markType = part;
          break;
        default:
          if (part.startsWith("'") || part.startsWith('"'))
            return part.substring(1, part.length - 1);
          else if (part.isNotEmpty &&
              !['none', 'filled', 'open'].contains(part))
            return part;
      }
    }

    switch (markType ?? 'dot') {
      case 'dot':
        return isFilled ? '\u2022' : '\u25E6';
      case 'circle':
        return isFilled ? '\u25CF' : '\u25CB';
      case 'double-circle':
        return '\u25CE';
      case 'triangle':
        return isFilled ? '\u25B2' : '\u25B3';
      case 'sesame':
        return isFilled ? '\uFE45' : '\uFE46';
      default:
        return null;
    }
  }

  /// Helper to resolve color from a string value.
  ui.Color _resolveColorFromString(String colorStr) {
    final normalized = colorStr.toLowerCase().trim();

    const colorMap = <String, int>{
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'yellow': 0xFFFFFF00,
      'cyan': 0xFF00FFFF,
      'magenta': 0xFFFF00FF,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'orange': 0xFFFFA500,
      'purple': 0xFF800080,
      'pink': 0xFFFFC0CB,
      'brown': 0xFFA52A2A,
    };

    if (colorMap.containsKey(normalized))
      return ui.Color(colorMap[normalized]!);

    if (normalized.startsWith('#')) {
      final hex = normalized.substring(1);
      if (hex.length == 6) {
        final value = int.tryParse('FF$hex', radix: 16);
        if (value != null) return ui.Color(value);
      } else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        final value = int.tryParse('FF$r$r$g$g$b$b', radix: 16);
        if (value != null) return ui.Color(value);
      }
    }

    return const ui.Color(0xFF000000);
  }

  /// Applies text-transform CSS property to text.
  String _applyTextTransform(String text, String textTransform) {
    if (textTransform == 'none' || text.isEmpty) return text;

    switch (textTransform) {
      case 'uppercase':
        return text.toUpperCase();
      case 'lowercase':
        return text.toLowerCase();
      case 'capitalize':
        return _capitalizeWords(text);
      case 'full-width':
        return _toFullWidth(text);
      default:
        return text;
    }
  }

  /// Capitalizes the first letter of each word in text.
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == '-' ||
          char == '_') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Converts ASCII characters to full-width equivalents.
  String _toFullWidth(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x21 && rune <= 0x7E)
        buffer.writeCharCode(rune + 0xFEE0);
      else if (rune == 0x20)
        buffer.writeCharCode(0x3000);
      else
        buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// Maps CSS text-decoration-style to Flutter ui.TextDecorationStyle.
  ui.TextDecorationStyle _mapDecorationStyle(String? value) {
    switch (value) {
      case 'double':
        return ui.TextDecorationStyle.double;
      case 'dotted':
        return ui.TextDecorationStyle.dotted;
      case 'dashed':
        return ui.TextDecorationStyle.dashed;
      case 'wavy':
        return ui.TextDecorationStyle.wavy;
      case 'solid':
      default:
        return ui.TextDecorationStyle.solid;
    }
  }

  /// Parses CSS text-shadow value into Flutter Shadow list.
  List<ui.Shadow> _parseTextShadows(String value) {
    final shadows = <ui.Shadow>[];
    final parts = value.split(',');
    for (final part in parts) {
      final shadow = _parseSingleTextShadow(part.trim());
      if (shadow != null) shadows.add(shadow);
    }
    return shadows;
  }

  /// Parses a single CSS text-shadow value.
  ui.Shadow? _parseSingleTextShadow(String value) {
    if (value.isEmpty) return null;
    final tokens = value.split(RegExp(r'\s+'));
    if (tokens.length < 2) return null;

    var color = const ui.Color(0xFF000000);
    final numericTokens = <double>[];

    for (final token in tokens) {
      final numVal = double.tryParse(token.replaceAll(RegExp(r'px$'), ''));
      if (numVal != null) {
        numericTokens.add(numVal);
      } else {
        final parsed = _tryParseColor(token);
        if (parsed != null) color = parsed;
      }
    }

    if (numericTokens.length < 2) return null;

    return ui.Shadow(
      offset: ui.Offset(numericTokens[0], numericTokens[1]),
      blurRadius: numericTokens.length > 2 ? numericTokens[2] : 0.0,
      color: color,
    );
  }

  /// Tries to parse a color string for text-shadow.
  ui.Color? _tryParseColor(String token) {
    final normalized = token.toLowerCase().trim();
    const colorMap = <String, int>{
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'transparent': 0x00000000,
    };
    if (colorMap.containsKey(normalized))
      return ui.Color(colorMap[normalized]!);

    if (normalized.startsWith('#')) {
      final hex = normalized.substring(1);
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) return ui.Color(val);
      } else if (hex.length == 3) {
        final r = hex[0], g = hex[1], b = hex[2];
        final val = int.tryParse('FF$r$r$g$g$b$b', radix: 16);
        if (val != null) return ui.Color(val);
      }
    }

    if (normalized.startsWith('rgb')) {
      final match = RegExp(
        r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)',
      ).firstMatch(normalized);
      if (match != null) {
        final r = int.tryParse(match.group(1)!) ?? 0;
        final g = int.tryParse(match.group(2)!) ?? 0;
        final b = int.tryParse(match.group(3)!) ?? 0;
        final a = match.group(4) != null
            ? ((double.tryParse(match.group(4)!) ?? 1.0) * 255).round()
            : 255;
        return ui.Color.fromARGB(a, r, g, b);
      }
    }
    return null;
  }
}
