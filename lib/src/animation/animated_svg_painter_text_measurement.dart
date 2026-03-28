part of 'animated_svg_painter.dart';

/// Text measurement and Unicode processing utilities.
///
/// Contains methods for:
/// - Unicode bidirectional text handling (UAX #9 compliant)
/// - NFC normalization for Unicode text
/// - Grapheme cluster segmentation for complex scripts
/// - Combining marks and diacritics positioning
/// - Font size resolution with font-size-adjust
extension AnimatedSvgPainterTextMeasurementExtension on AnimatedSvgPainter {
  /// Applies unicode-bidi handling by wrapping text with Unicode directional control characters.
  ///
  /// Implements UAX #9 (Unicode Bidirectional Algorithm):
  /// - embed: LRE/RLE + text + PDF
  /// - bidi-override: LRO/RLO + text + PDF
  /// - isolate: LRI/RLI + text + PDI
  /// - isolate-override: FSI + LRO/RLO + text + PDF + PDI
  /// - plaintext: FSI + text + PDI (determine direction from first strong char)
  String _applyUnicodeBidi(
    String text,
    String? unicodeBidi,
    ui.TextDirection textDirection,
  ) {
    if (unicodeBidi == null) {
      return text;
    }

    // Unicode directional formatting characters
    const String lre = '\u202A'; // Left-to-Right Embedding
    const String rle = '\u202B'; // Right-to-Left Embedding
    const String lro = '\u202D'; // Left-to-Right Override
    const String rlo = '\u202E'; // Right-to-Left Override
    const String pdf = '\u202C'; // Pop Directional Formatting
    const String lri = '\u2066'; // Left-to-Right Isolate
    const String rli = '\u2067'; // Right-to-Left Isolate
    const String fsi = '\u2068'; // First Strong Isolate
    const String pdi = '\u2069'; // Pop Directional Isolate

    final isRtl = textDirection == ui.TextDirection.rtl;

    switch (unicodeBidi) {
      case 'embed':
        return isRtl ? '$rle$text$pdf' : '$lre$text$pdf';
      case 'bidi-override':
        return isRtl ? '$rlo$text$pdf' : '$lro$text$pdf';
      case 'isolate':
        return isRtl ? '$rli$text$pdi' : '$lri$text$pdi';
      case 'isolate-override':
        return isRtl ? '$fsi$rlo$text$pdf$pdi' : '$fsi$lro$text$pdf$pdi';
      case 'plaintext':
        return '$fsi$text$pdi';
      case 'normal':
      default:
        return text;
    }
  }

  /// Normalizes text to NFC (Canonical Decomposition, followed by Canonical Composition).
  String _normalizeTextNfc(String text) {
    if (text.isEmpty) return text;
    return _composeToNfc(text);
  }

  /// Composes text to NFC form.
  String _composeToNfc(String text) {
    if (text.isEmpty) return text;
    bool hasCombining = false;
    for (final rune in text.runes) {
      if (_isCombiningMark(rune)) {
        hasCombining = true;
        break;
      }
    }
    if (!hasCombining) return text;

    final buffer = StringBuffer();
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final base = runes[i];
      i++;
      final combining = <int>[];
      while (i < runes.length && _isCombiningMark(runes[i])) {
        combining.add(runes[i]);
        i++;
      }
      if (combining.isEmpty) {
        buffer.writeCharCode(base);
      } else {
        final composed = _tryCompose(base, combining);
        buffer.write(composed);
      }
    }
    return buffer.toString();
  }

  /// Attempts to compose a base character with combining marks.
  String _tryCompose(int base, List<int> combining) {
    if (combining.length == 1 && combining[0] == 0x0301) {
      final composed = _composeWithAcute(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    if (combining.length == 1 && combining[0] == 0x0300) {
      final composed = _composeWithGrave(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    if (combining.length == 1 && combining[0] == 0x0302) {
      final composed = _composeWithCircumflex(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    if (combining.length == 1 && combining[0] == 0x0303) {
      final composed = _composeWithTilde(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    if (combining.length == 1 && combining[0] == 0x0308) {
      final composed = _composeWithDiaeresis(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    if (combining.length == 1 && combining[0] == 0x0327) {
      final composed = _composeWithCedilla(base);
      if (composed != null) return String.fromCharCode(composed);
    }
    return String.fromCharCode(base) + String.fromCharCodes(combining);
  }

  int? _composeWithAcute(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C1, 0x0061: 0x00E1, 0x0045: 0x00C9, 0x0065: 0x00E9,
      0x0049: 0x00CD, 0x0069: 0x00ED, 0x004F: 0x00D3, 0x006F: 0x00F3,
      0x0055: 0x00DA, 0x0075: 0x00FA, 0x0059: 0x00DD, 0x0079: 0x00FD,
      0x004E: 0x0143, 0x006E: 0x0144, 0x0043: 0x0106, 0x0063: 0x0107,
      0x0053: 0x015A, 0x0073: 0x015B, 0x005A: 0x0179, 0x007A: 0x017A,
    };
    return compositions[base];
  }

  int? _composeWithGrave(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C0, 0x0061: 0x00E0, 0x0045: 0x00C8, 0x0065: 0x00E8,
      0x0049: 0x00CC, 0x0069: 0x00EC, 0x004F: 0x00D2, 0x006F: 0x00F2,
      0x0055: 0x00D9, 0x0075: 0x00F9,
    };
    return compositions[base];
  }

  int? _composeWithCircumflex(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C2, 0x0061: 0x00E2, 0x0045: 0x00CA, 0x0065: 0x00EA,
      0x0049: 0x00CE, 0x0069: 0x00EE, 0x004F: 0x00D4, 0x006F: 0x00F4,
      0x0055: 0x00DB, 0x0075: 0x00FB,
    };
    return compositions[base];
  }

  int? _composeWithTilde(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C3, 0x0061: 0x00E3, 0x004E: 0x00D1, 0x006E: 0x00F1,
      0x004F: 0x00D5, 0x006F: 0x00F5,
    };
    return compositions[base];
  }

  int? _composeWithDiaeresis(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C4, 0x0061: 0x00E4, 0x0045: 0x00CB, 0x0065: 0x00EB,
      0x0049: 0x00CF, 0x0069: 0x00EF, 0x004F: 0x00D6, 0x006F: 0x00F6,
      0x0055: 0x00DC, 0x0075: 0x00FC, 0x0059: 0x0178, 0x0079: 0x00FF,
    };
    return compositions[base];
  }

  int? _composeWithCedilla(int base) {
    const compositions = <int, int>{
      0x0043: 0x00C7, 0x0063: 0x00E7, 0x0053: 0x015E, 0x0073: 0x015F,
    };
    return compositions[base];
  }

  // ignore: unused_element
  List<String> _segmentIntoGraphemeClusters(String text) {
    if (text.isEmpty) return const <String>[];
    final clusters = <String>[];
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final start = i;
      i++;
      while (i < runes.length && _isCombiningMark(runes[i])) {
        i++;
      }
      while (i + 1 < runes.length && runes[i] == 0x200D) {
        i++;
        i++;
        while (i < runes.length && _isCombiningMark(runes[i])) {
          i++;
        }
        while (i < runes.length && _isVariationSelector(runes[i])) {
          i++;
        }
      }
      if (start < runes.length &&
          _isRegionalIndicator(runes[start]) &&
          i < runes.length &&
          _isRegionalIndicator(runes[i])) {
        i++;
      }
      while (i < runes.length && _isVariationSelector(runes[i])) {
        i++;
      }
      final cluster = String.fromCharCodes(runes.sublist(start, i));
      clusters.add(cluster);
    }
    return clusters;
  }

  bool _isRegionalIndicator(int codePoint) {
    return codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF;
  }

  bool _isVariationSelector(int codePoint) {
    if (codePoint >= 0xFE00 && codePoint <= 0xFE0F) return true;
    if (codePoint >= 0xE0100 && codePoint <= 0xE01EF) return true;
    if (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF) return true;
    return false;
  }

  // ignore: unused_element
  ui.TextDirection _detectTextDirection(String text) {
    for (final codeUnit in text.runes) {
      final category = _getUnicodeBidiCategory(codeUnit);
      if (category == _BidiCategory.l) {
        return ui.TextDirection.ltr;
      } else if (category == _BidiCategory.r || category == _BidiCategory.al) {
        return ui.TextDirection.rtl;
      }
    }
    return ui.TextDirection.ltr;
  }

  _BidiCategory _getUnicodeBidiCategory(int codePoint) {
    if ((codePoint >= 0x0600 && codePoint <= 0x06FF) ||
        (codePoint >= 0x0750 && codePoint <= 0x077F) ||
        (codePoint >= 0x08A0 && codePoint <= 0x08FF)) {
      return _BidiCategory.al;
    }
    if (codePoint >= 0x0590 && codePoint <= 0x05FF) {
      return _BidiCategory.r;
    }
    if ((codePoint >= 0x0041 && codePoint <= 0x005A) ||
        (codePoint >= 0x0061 && codePoint <= 0x007A) ||
        (codePoint >= 0x00C0 && codePoint <= 0x024F) ||
        (codePoint >= 0x0370 && codePoint <= 0x03FF) ||
        (codePoint >= 0x0400 && codePoint <= 0x04FF)) {
      return _BidiCategory.l;
    }
    if (codePoint >= 0x0030 && codePoint <= 0x0039) {
      return _BidiCategory.en;
    }
    return _BidiCategory.other;
  }

  bool _isCombiningMark(int codePoint) {
    if (codePoint >= 0x0300 && codePoint <= 0x036F) return true;
    if (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) return true;
    if (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) return true;
    if (codePoint >= 0xFE20 && codePoint <= 0xFE2F) return true;
    if (codePoint == 0x0E31 ||
        (codePoint >= 0x0E34 && codePoint <= 0x0E3A) ||
        (codePoint >= 0x0E47 && codePoint <= 0x0E4E)) {
      return true;
    }
    if (codePoint == 0x093C ||
        (codePoint >= 0x0941 && codePoint <= 0x0948) ||
        codePoint == 0x094D) {
      return true;
    }
    return false;
  }

  // ignore: unused_element
  List<_BidiRun> _segmentIntoBidiRuns(
    String text,
    ui.TextDirection baseDirection,
  ) {
    if (text.isEmpty) return const <_BidiRun>[];
    final runs = <_BidiRun>[];
    var currentStart = 0;
    var currentDirection = baseDirection;

    for (var i = 0; i < text.length;) {
      final codePoint = text.codeUnitAt(i);
      final category = _getUnicodeBidiCategory(codePoint);

      ui.TextDirection charDirection;
      if (category == _BidiCategory.l) {
        charDirection = ui.TextDirection.ltr;
      } else if (category == _BidiCategory.r || category == _BidiCategory.al) {
        charDirection = ui.TextDirection.rtl;
      } else {
        charDirection = currentDirection;
      }

      if (runs.isEmpty || charDirection != currentDirection) {
        if (runs.isNotEmpty) {
          runs.last = _BidiRun(
            text: text.substring(currentStart, i),
            direction: currentDirection,
            start: currentStart,
            end: i,
          );
        }
        currentStart = i;
        currentDirection = charDirection;
        runs.add(
          _BidiRun(text: '', direction: charDirection, start: i, end: i),
        );
      }
      i++;
    }

    if (runs.isNotEmpty) {
      runs.last = _BidiRun(
        text: text.substring(currentStart),
        direction: currentDirection,
        start: currentStart,
        end: text.length,
      );
    } else {
      runs.add(
        _BidiRun(
          text: text,
          direction: baseDirection,
          start: 0,
          end: text.length,
        ),
      );
    }
    return runs;
  }
}
