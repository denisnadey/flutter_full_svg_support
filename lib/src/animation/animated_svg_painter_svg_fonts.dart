part of 'animated_svg_painter.dart';

/// Minimal renderer for SVG 1.1 `<font>` definitions embedded in the document.
///
/// This is used as a functional fallback for W3C legacy font fixtures where
/// glyph paths are defined inline via `<font>/<glyph>` and cannot be handled by
/// Flutter's normal text shaping pipeline.
extension AnimatedSvgPainterSvgFontsExtension on AnimatedSvgPainter {
  Map<String, _SvgFontDefinition> _svgFontsByFamily() {
    final cached = _svgFontsByFamilyCache;
    if (cached != null) {
      return cached;
    }

    final parsedByFamily = <String, _SvgFontDefinition>{};
    final parsedById = <String, _SvgFontDefinition>{};
    for (final fontNode in document.getElementsByTag('font')) {
      final definition = _parseSvgFontDefinition(fontNode);
      if (definition == null) {
        continue;
      }
      final family = definition.family;
      if (family != null && family.trim().isNotEmpty) {
        parsedByFamily[_normalizeSvgFontFamily(family)] = definition;
      }
      final fontId = definition.fontId;
      if (fontId != null && fontId.trim().isNotEmpty) {
        parsedById[_normalizeSvgFontId(fontId)] = definition;
      }
    }

    _svgFontsByFamilyCache = parsedByFamily;
    _svgFontsByIdCache = parsedById;
    return parsedByFamily;
  }

  Map<String, _SvgFontDefinition> _svgFontsById() {
    final cached = _svgFontsByIdCache;
    if (cached != null) {
      return cached;
    }
    _svgFontsByFamily();
    return _svgFontsByIdCache ?? const <String, _SvgFontDefinition>{};
  }

  Map<String, String> _svgFontFamilyToFontId() {
    final cached = _svgFontFamilyToFontIdCache;
    if (cached != null) {
      return cached;
    }

    final mapping = <String, String>{};

    final cssFontFaceRules = document.cssFontFaceRules;
    if (cssFontFaceRules != null) {
      for (final rule in cssFontFaceRules) {
        final fontId = _extractSvgFontIdFromSrc(rule.src);
        if (fontId == null) {
          continue;
        }
        mapping[_normalizeSvgFontFamily(rule.fontFamily)] = fontId;
      }
    }

    for (final fontFaceNode in document.getElementsByTag('font-face')) {
      final family = _getString(fontFaceNode, 'font-family');
      if (family == null || family.trim().isEmpty) {
        continue;
      }

      String? href;
      for (final child in fontFaceNode.children) {
        if (child.tagName != 'font-face-src') {
          continue;
        }
        for (final srcChild in child.children) {
          if (srcChild.tagName != 'font-face-uri') {
            continue;
          }
          href =
              _getString(srcChild, 'href') ??
              _getString(srcChild, 'xlink:href');
          if (href != null && href.trim().isNotEmpty) {
            break;
          }
        }
        if (href != null && href.trim().isNotEmpty) {
          break;
        }
      }

      final fontId = _extractSvgFontIdFromSrc(href);
      if (fontId != null) {
        mapping[_normalizeSvgFontFamily(family)] = fontId;
      }
    }

    _svgFontFamilyToFontIdCache = mapping;
    return mapping;
  }

  String? _extractSvgFontIdFromSrc(String? src) {
    if (src == null || src.trim().isEmpty) {
      return null;
    }

    final raw = src.trim();
    final urlMatches = RegExp(
      r'url\(\s*([^)]+?)\s*\)',
      caseSensitive: false,
    ).allMatches(raw);

    for (final match in urlMatches) {
      final rawUrl = match.group(1);
      if (rawUrl == null || rawUrl.trim().isEmpty) {
        continue;
      }
      final normalizedUrl = _stripCssStringQuotes(rawUrl.trim());
      final fromUrl = _extractSvgFontIdFromHref(normalizedUrl);
      if (fromUrl != null) {
        return fromUrl;
      }
    }

    final direct = _extractSvgFontIdFromHref(_stripCssStringQuotes(raw));
    if (direct != null) {
      return direct;
    }

    return null;
  }

  String _stripCssStringQuotes(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized;
  }

  String? _extractSvgFontIdFromHref(String href) {
    final hashIndex = href.lastIndexOf('#');
    if (hashIndex < 0 || hashIndex + 1 >= href.length) {
      return null;
    }

    var fragment = href.substring(hashIndex + 1).trim();
    final end = RegExp("[\\s\"'\\),]").firstMatch(fragment)?.start;
    if (end != null && end > 0) {
      fragment = fragment.substring(0, end);
    } else if (end == 0) {
      return null;
    }

    if (fragment.isEmpty) {
      return null;
    }

    return _normalizeSvgFontId(fragment);
  }

  _SvgFontDefinition? _resolveSvgFontDefinition(_ResolvedTextStyle style) {
    final familyValue = style.fontFamily;
    if (familyValue == null || familyValue.trim().isEmpty) {
      return null;
    }

    final fontsByFamily = _svgFontsByFamily();
    final fontsById = _svgFontsById();
    if (fontsByFamily.isEmpty && fontsById.isEmpty) {
      return null;
    }
    final familyToFontId = _svgFontFamilyToFontId();

    for (final rawFamily in familyValue.split(',')) {
      final familyKey = _normalizeSvgFontFamily(rawFamily);
      final definition = fontsByFamily[familyKey];
      if (definition != null) {
        return definition;
      }

      final mappedFontId = familyToFontId[familyKey];
      if (mappedFontId != null) {
        final byIdDefinition = fontsById[mappedFontId];
        if (byIdDefinition != null) {
          return byIdDefinition;
        }
      }

      final directIdMatch = fontsById[_normalizeSvgFontId(rawFamily)];
      if (directIdMatch != null) {
        return directIdMatch;
      }
    }

    return null;
  }

  String _normalizeSvgFontFamily(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized.toLowerCase();
  }

  String _normalizeSvgFontId(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1).trim();
    }
    return normalized.toLowerCase();
  }

  _SvgFontDefinition? _parseSvgFontDefinition(SvgNode fontNode) {
    SvgNode? fontFaceNode;
    for (final child in fontNode.children) {
      if (child.tagName == 'font-face') {
        fontFaceNode = child;
        break;
      }
    }
    if (fontFaceNode == null) {
      return null;
    }

    final family = _getString(fontFaceNode, 'font-family');
    final fontId = _getString(fontNode, 'id');
    if ((family == null || family.trim().isEmpty) &&
        (fontId == null || fontId.trim().isEmpty)) {
      return null;
    }

    final unitsPerEm = (_getNumber(fontFaceNode, 'units-per-em') ?? 1000.0)
        .clamp(1.0, double.infinity);
    final horizAdvXDefault =
        _getNumber(fontNode, 'horiz-adv-x') ?? unitsPerEm.toDouble();
    final ascent = _getNumber(fontFaceNode, 'ascent') ?? unitsPerEm * 0.8;
    final descent = _getNumber(fontFaceNode, 'descent') ?? -unitsPerEm * 0.2;

    final glyphsByUnicode = <String, List<_SvgFontGlyph>>{};
    final glyphByName = <String, _SvgFontGlyph>{};
    final kerningRules = <_SvgFontKerningRule>[];
    _SvgFontGlyph? missingGlyph;

    for (final child in fontNode.children) {
      if (child.tagName == 'glyph') {
        final glyph = _parseSvgFontGlyph(
          child,
          horizAdvXDefault: horizAdvXDefault.toDouble(),
        );
        if (glyph == null) {
          continue;
        }
        final unicode = glyph.unicode;
        if (unicode != null && unicode.isNotEmpty) {
          glyphsByUnicode
              .putIfAbsent(unicode, () => <_SvgFontGlyph>[])
              .add(glyph);
        }
        final glyphName = glyph.glyphName;
        if (glyphName != null && glyphName.isNotEmpty) {
          glyphByName[glyphName] = glyph;
        }
      } else if (child.tagName == 'missing-glyph') {
        missingGlyph = _parseSvgFontGlyph(
          child,
          horizAdvXDefault: horizAdvXDefault.toDouble(),
        );
      } else if (child.tagName == 'hkern') {
        final rule = _parseSvgFontKerningRule(child);
        if (rule != null) {
          kerningRules.add(rule);
        }
      }
    }

    if (glyphsByUnicode.isEmpty &&
        glyphByName.isEmpty &&
        missingGlyph == null) {
      return null;
    }

    return _SvgFontDefinition(
      family: family,
      fontId: fontId,
      unitsPerEm: unitsPerEm.toDouble(),
      horizAdvXDefault: horizAdvXDefault.toDouble(),
      ascent: ascent.toDouble(),
      descent: descent.toDouble(),
      glyphsByUnicode: glyphsByUnicode,
      glyphByName: glyphByName,
      missingGlyph: missingGlyph,
      kerningRules: kerningRules,
    );
  }

  _SvgFontGlyph? _parseSvgFontGlyph(
    SvgNode glyphNode, {
    required double horizAdvXDefault,
  }) {
    final unicode = _getString(glyphNode, 'unicode');
    final glyphName = _getString(glyphNode, 'glyph-name');
    final arabicForm = _getString(glyphNode, 'arabic-form')?.toLowerCase();
    final horizAdvX = _getNumber(glyphNode, 'horiz-adv-x') ?? horizAdvXDefault;
    final pathData = _getString(glyphNode, 'd');
    final path = (pathData == null || pathData.trim().isEmpty)
        ? null
        : _buildPath(pathData);

    return _SvgFontGlyph(
      unicode: unicode,
      glyphName: glyphName,
      arabicForm: arabicForm,
      horizAdvX: horizAdvX.toDouble(),
      path: path,
    );
  }

  _SvgFontKerningRule? _parseSvgFontKerningRule(SvgNode hkernNode) {
    final k = (_getNumber(hkernNode, 'k') ?? 0.0).toDouble();
    final leftUnicodeSelectors = _parseSvgUnicodeSelectors(
      _getString(hkernNode, 'u1'),
    );
    final rightUnicodeSelectors = _parseSvgUnicodeSelectors(
      _getString(hkernNode, 'u2'),
    );
    final leftGlyphNames = _parseSvgGlyphNames(_getString(hkernNode, 'g1'));
    final rightGlyphNames = _parseSvgGlyphNames(_getString(hkernNode, 'g2'));

    if (leftUnicodeSelectors.isEmpty &&
        rightUnicodeSelectors.isEmpty &&
        leftGlyphNames.isEmpty &&
        rightGlyphNames.isEmpty) {
      return null;
    }

    return _SvgFontKerningRule(
      k: k,
      leftUnicodeSelectors: leftUnicodeSelectors,
      rightUnicodeSelectors: rightUnicodeSelectors,
      leftGlyphNames: leftGlyphNames,
      rightGlyphNames: rightGlyphNames,
    );
  }

  List<_SvgUnicodeSelector> _parseSvgUnicodeSelectors(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const <_SvgUnicodeSelector>[];
    }

    final selectors = <_SvgUnicodeSelector>[];
    for (final token in rawValue.split(',')) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final selector = _SvgUnicodeSelector.parse(trimmed);
      if (selector != null) {
        selectors.add(selector);
      }
    }
    return selectors;
  }

  Set<String> _parseSvgGlyphNames(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const <String>{};
    }
    final names = <String>{};
    for (final token in rawValue.split(',')) {
      final trimmed = token.trim();
      if (trimmed.isNotEmpty) {
        names.add(trimmed);
      }
    }
    return names;
  }

  double? _lookupSvgKerningAdjust(
    _SvgFontDefinition font,
    _SvgFontLayoutGlyph previous,
    _SvgFontLayoutGlyph current,
  ) {
    for (int i = font.kerningRules.length - 1; i >= 0; i--) {
      final rule = font.kerningRules[i];
      if (rule.matches(previous: previous, current: current)) {
        // SVG hkern 'k' is subtracted from advance.
        return -rule.k;
      }
    }
    return null;
  }

  _SvgFontGlyph _selectSvgFontGlyph(
    _SvgFontDefinition font,
    List<String> logicalChars,
    int index,
  ) {
    final character = logicalChars[index];
    final candidates = font.glyphsByUnicode[character];
    if (candidates == null || candidates.isEmpty) {
      return font.missingGlyph ??
          _SvgFontGlyph(
            unicode: character,
            glyphName: null,
            arabicForm: null,
            horizAdvX: font.horizAdvXDefault,
            path: null,
          );
    }

    if (candidates.length == 1) {
      return candidates.first;
    }

    final prevChar = index > 0 ? logicalChars[index - 1] : null;
    final nextChar = index + 1 < logicalChars.length
        ? logicalChars[index + 1]
        : null;
    final desiredArabicForm = _resolveSvgArabicForm(font, prevChar, nextChar);

    for (final candidate in candidates) {
      final form = candidate.arabicForm;
      if (form == null) {
        continue;
      }
      if (form == desiredArabicForm ||
          (desiredArabicForm == 'terminal' && form == 'final') ||
          (desiredArabicForm == 'final' && form == 'terminal')) {
        return candidate;
      }
    }

    for (final candidate in candidates) {
      if (candidate.arabicForm == null) {
        return candidate;
      }
    }

    return candidates.first;
  }

  String _resolveSvgArabicForm(
    _SvgFontDefinition font,
    String? prevChar,
    String? nextChar,
  ) {
    final hasPrev = _isSvgJoinCandidate(font, prevChar);
    final hasNext = _isSvgJoinCandidate(font, nextChar);

    if (hasPrev && hasNext) {
      return 'medial';
    }
    if (hasPrev) {
      return 'terminal';
    }
    if (hasNext) {
      return 'initial';
    }
    return 'isolated';
  }

  bool _isSvgJoinCandidate(_SvgFontDefinition font, String? character) {
    if (character == null || character.isEmpty) {
      return false;
    }
    if (character.trim().isEmpty) {
      return false;
    }
    return font.glyphsByUnicode.containsKey(character);
  }

  double _paintSvgFontText(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required _SvgFontDefinition font,
    required double x,
    required double baselineY,
    bool isFirstLine = false,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final logicalChars = _segmentIntoGraphemeClusters(
      _normalizeTextToNFC(text),
    );
    if (logicalChars.isEmpty) {
      return 0.0;
    }

    final logicalGlyphs = <_SvgFontLayoutGlyph>[];
    for (int i = 0; i < logicalChars.length; i++) {
      final character = logicalChars[i];
      final glyph = _selectSvgFontGlyph(font, logicalChars, i);
      logicalGlyphs.add(
        _SvgFontLayoutGlyph(character: character, glyph: glyph),
      );
    }

    final visualGlyphs = style.textDirection == ui.TextDirection.rtl
        ? logicalGlyphs.reversed.toList()
        : logicalGlyphs;
    if (visualGlyphs.isEmpty) {
      return 0.0;
    }

    final scale = style.fontSize / font.unitsPerEm;
    var totalWidth = 0.0;
    for (int i = 0; i < visualGlyphs.length; i++) {
      if (i > 0) {
        final previous = visualGlyphs[i - 1];
        final current = visualGlyphs[i];
        final kerningAdjust = _lookupSvgKerningAdjust(font, previous, current);
        if (kerningAdjust != null) {
          totalWidth += kerningAdjust * scale;
        }
        totalWidth += style.letterSpacing;
        if (previous.character == ' ' || previous.character == '\u00A0') {
          totalWidth += style.wordSpacing;
        }
      }
      totalWidth += visualGlyphs[i].glyph.horizAdvX * scale;
    }

    var effectiveX = x;
    if (isFirstLine && style.textIndent != 0.0) {
      effectiveX += style.textIndent;
    }

    var effectiveAnchor = style.textAnchor;
    if (style.textDirection == ui.TextDirection.rtl) {
      switch (style.textAnchor) {
        case _SvgTextAnchor.start:
          effectiveAnchor = _SvgTextAnchor.end;
          break;
        case _SvgTextAnchor.end:
          effectiveAnchor = _SvgTextAnchor.start;
          break;
        case _SvgTextAnchor.middle:
          effectiveAnchor = _SvgTextAnchor.middle;
          break;
      }
    }

    var drawX = effectiveX;
    switch (effectiveAnchor) {
      case _SvgTextAnchor.start:
        break;
      case _SvgTextAnchor.middle:
        drawX -= totalWidth / 2.0;
        break;
      case _SvgTextAnchor.end:
        drawX -= totalWidth;
        break;
    }

    final topY = baselineY - font.ascent * scale;
    final bottomY = baselineY - font.descent * scale;
    final paintBounds = ui.Rect.fromLTRB(
      drawX,
      math.min(topY, bottomY),
      drawX + math.max(totalWidth, 1.0),
      math.max(topY, bottomY),
    );

    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (fillPaint == null && strokePaint == null) {
      return totalWidth;
    }

    final strokeFirst =
        strokePaint != null &&
        style.paintOrder.isNotEmpty &&
        style.paintOrder.startsWith('stroke');

    var penX = drawX;
    for (int i = 0; i < visualGlyphs.length; i++) {
      if (i > 0) {
        final previous = visualGlyphs[i - 1];
        final current = visualGlyphs[i];
        final kerningAdjust = _lookupSvgKerningAdjust(font, previous, current);
        if (kerningAdjust != null) {
          penX += kerningAdjust * scale;
        }
        penX += style.letterSpacing;
        if (previous.character == ' ' || previous.character == '\u00A0') {
          penX += style.wordSpacing;
        }
      }

      final glyph = visualGlyphs[i].glyph;
      final path = glyph.path;
      if (path != null) {
        final glyphMatrix = Matrix4.identity()
          ..translateByDouble(penX, baselineY, 0.0, 1.0)
          ..scaleByDouble(scale, -scale, 1.0, 1.0);
        final transformedPath = path.transform(glyphMatrix.storage);
        if (strokeFirst) {
          canvas.drawPath(transformedPath, strokePaint);
          if (fillPaint != null) {
            canvas.drawPath(transformedPath, fillPaint);
          }
        } else {
          if (fillPaint != null) {
            canvas.drawPath(transformedPath, fillPaint);
          }
          if (strokePaint != null) {
            canvas.drawPath(transformedPath, strokePaint);
          }
        }
      }

      penX += glyph.horizAdvX * scale;
    }

    return totalWidth;
  }
}

class _SvgFontDefinition {
  const _SvgFontDefinition({
    required this.family,
    required this.fontId,
    required this.unitsPerEm,
    required this.horizAdvXDefault,
    required this.ascent,
    required this.descent,
    required this.glyphsByUnicode,
    required this.glyphByName,
    required this.missingGlyph,
    required this.kerningRules,
  });

  final String? family;
  final String? fontId;
  final double unitsPerEm;
  final double horizAdvXDefault;
  final double ascent;
  final double descent;
  final Map<String, List<_SvgFontGlyph>> glyphsByUnicode;
  final Map<String, _SvgFontGlyph> glyphByName;
  final _SvgFontGlyph? missingGlyph;
  final List<_SvgFontKerningRule> kerningRules;
}

class _SvgFontGlyph {
  const _SvgFontGlyph({
    required this.unicode,
    required this.glyphName,
    required this.arabicForm,
    required this.horizAdvX,
    required this.path,
  });

  final String? unicode;
  final String? glyphName;
  final String? arabicForm;
  final double horizAdvX;
  final ui.Path? path;
}

class _SvgFontLayoutGlyph {
  const _SvgFontLayoutGlyph({required this.character, required this.glyph});

  final String character;
  final _SvgFontGlyph glyph;
}

class _SvgFontKerningRule {
  const _SvgFontKerningRule({
    required this.k,
    required this.leftUnicodeSelectors,
    required this.rightUnicodeSelectors,
    required this.leftGlyphNames,
    required this.rightGlyphNames,
  });

  final double k;
  final List<_SvgUnicodeSelector> leftUnicodeSelectors;
  final List<_SvgUnicodeSelector> rightUnicodeSelectors;
  final Set<String> leftGlyphNames;
  final Set<String> rightGlyphNames;

  bool matches({
    required _SvgFontLayoutGlyph previous,
    required _SvgFontLayoutGlyph current,
  }) {
    final leftMatches = _matchesSide(
      character: previous.character,
      glyphName: previous.glyph.glyphName,
      unicodeSelectors: leftUnicodeSelectors,
      glyphNames: leftGlyphNames,
    );
    if (!leftMatches) {
      return false;
    }

    return _matchesSide(
      character: current.character,
      glyphName: current.glyph.glyphName,
      unicodeSelectors: rightUnicodeSelectors,
      glyphNames: rightGlyphNames,
    );
  }

  bool _matchesSide({
    required String character,
    required String? glyphName,
    required List<_SvgUnicodeSelector> unicodeSelectors,
    required Set<String> glyphNames,
  }) {
    final hasUnicodeSelectors = unicodeSelectors.isNotEmpty;
    final hasGlyphNames = glyphNames.isNotEmpty;
    if (!hasUnicodeSelectors && !hasGlyphNames) {
      return true;
    }

    final unicodeMatch =
        hasUnicodeSelectors &&
        unicodeSelectors.any((selector) => selector.matches(character));
    final glyphMatch =
        hasGlyphNames && glyphName != null && glyphNames.contains(glyphName);

    return unicodeMatch || glyphMatch;
  }
}

class _SvgUnicodeSelector {
  const _SvgUnicodeSelector._({
    this.exactCharacter,
    this.rangeStart,
    this.rangeEnd,
    this.wildcardPattern,
  });

  final String? exactCharacter;
  final int? rangeStart;
  final int? rangeEnd;
  final String? wildcardPattern;

  static _SvgUnicodeSelector? parse(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final upper = trimmed.toUpperCase();
    if (!upper.startsWith('U+')) {
      return _SvgUnicodeSelector._(exactCharacter: trimmed);
    }

    final value = upper.substring(2);
    if (value.isEmpty) {
      return null;
    }

    if (value.contains('-')) {
      final parts = value.split('-');
      if (parts.length != 2) {
        return null;
      }
      final start = int.tryParse(parts[0], radix: 16);
      final end = int.tryParse(parts[1], radix: 16);
      if (start == null || end == null) {
        return null;
      }
      return _SvgUnicodeSelector._(rangeStart: start, rangeEnd: end);
    }

    if (value.contains('?')) {
      return _SvgUnicodeSelector._(wildcardPattern: value);
    }

    final codePoint = int.tryParse(value, radix: 16);
    if (codePoint == null) {
      return null;
    }
    return _SvgUnicodeSelector._(
      exactCharacter: String.fromCharCode(codePoint),
    );
  }

  bool matches(String character) {
    if (character.isEmpty) {
      return false;
    }

    final exact = exactCharacter;
    if (exact != null) {
      return character == exact;
    }

    final codePoint = character.runes.first;

    final start = rangeStart;
    final end = rangeEnd;
    if (start != null && end != null) {
      return codePoint >= start && codePoint <= end;
    }

    final wildcard = wildcardPattern;
    if (wildcard != null) {
      final hex = codePoint
          .toRadixString(16)
          .toUpperCase()
          .padLeft(wildcard.length, '0');
      if (hex.length != wildcard.length) {
        return false;
      }
      for (int i = 0; i < wildcard.length; i++) {
        final expected = wildcard[i];
        if (expected != '?' && expected != hex[i]) {
          return false;
        }
      }
      return true;
    }

    return false;
  }
}
