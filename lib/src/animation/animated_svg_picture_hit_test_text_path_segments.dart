part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateHitTestTextPathSegmentsExtension
    on _AnimatedSvgPictureState {
  double _appendTextPathSegmentRuns({
    required SvgNode owner,
    required SvgNode styleNode,
    required String text,
    required ui.PathMetric metric,
    required double startOffset,
    required List<_TextHitRun> runs,
    required _TextPathSpacing spacing,
  }) {
    final glyphs = text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (glyphs.isEmpty) {
      return 0.0;
    }

    final glyphMetrics = glyphs
        .map((glyph) => _measureText(glyph, styleNode))
        .toList(growable: false);
    final widths = glyphMetrics
        .map((metrics) => metrics.width)
        .toList(growable: false);
    // For spacing="exact", don't apply letter-spacing/word-spacing
    // For spacing="auto", apply style spacing
    final letterSpacing = spacing == _TextPathSpacing.auto
        ? (_getInheritedNumber(styleNode, 'letter-spacing') ?? 0.0).clamp(
            -1024.0,
            1024.0,
          )
        : 0.0;
    final wordSpacing = spacing == _TextPathSpacing.auto
        ? (_getInheritedNumber(styleNode, 'word-spacing') ?? 0.0).clamp(
            -1024.0,
            1024.0,
          )
        : 0.0;
    final advances = <double>[];
    for (int i = 0; i < glyphs.length; i++) {
      final glyphSpacing = _spacingAfterGlyphForHit(
        glyph: glyphs[i],
        isLast: i == glyphs.length - 1,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
      );
      advances.add(widths[i] + glyphSpacing);
    }
    final displayWidths = List<double>.from(widths);
    final displayAdvances = List<double>.from(advances);
    var totalWidth = displayAdvances.fold<double>(
      0.0,
      (sum, width) => sum + width,
    );
    final targetLength = _resolveTextLength(styleNode);
    final lengthAdjust = _resolveTextLengthAdjust(styleNode);
    if (targetLength != null && targetLength > 0 && totalWidth > 0) {
      if (lengthAdjust == _TextLengthAdjust.spacing && glyphs.length > 1) {
        final extraSpacing = (targetLength - totalWidth) / (glyphs.length - 1);
        for (int i = 0; i < displayAdvances.length - 1; i++) {
          displayAdvances[i] += extraSpacing;
        }
      } else {
        final scaleX = targetLength / totalWidth;
        for (int i = 0; i < displayWidths.length; i++) {
          displayWidths[i] *= scaleX;
          displayAdvances[i] *= scaleX;
        }
      }
      totalWidth = displayAdvances.fold<double>(
        0.0,
        (sum, width) => sum + width,
      );
    }

    var drawOffset = startOffset;
    switch (_resolveTextAnchor(styleNode)) {
      case _TextAnchor.middle:
        drawOffset -= totalWidth / 2;
        break;
      case _TextAnchor.end:
        drawOffset -= totalWidth;
        break;
      case _TextAnchor.start:
        break;
    }

    var consumed = 0.0;
    var cursor = drawOffset;
    final metricLength = metric.length;
    final fontSize = (_getInheritedNumber(styleNode, 'font-size') ?? 16.0)
        .clamp(1.0, 4096.0);
    for (int i = 0; i < widths.length; i++) {
      final glyphWidth = displayWidths[i];
      final glyphAdvance = displayAdvances[i];
      final start = cursor;
      final end = cursor + glyphWidth;
      final clampedStart = start.clamp(0.0, metricLength).toDouble();
      final clampedEnd = end.clamp(0.0, metricLength).toDouble();
      if (clampedEnd > clampedStart) {
        var glyphPath = metric.extractPath(clampedStart, clampedEnd);
        final tangent = metric.getTangentForOffset(
          ((clampedStart + clampedEnd) / 2).clamp(0.0, metricLength),
        );
        if (tangent != null) {
          final centerOffset = _resolveTextPathCenterOffset(
            node: styleNode,
            metrics: glyphMetrics[i],
          );
          if (centerOffset != 0.0) {
            final normal = Offset(
              -math.sin(tangent.angle),
              math.cos(tangent.angle),
            );
            glyphPath = glyphPath.shift(
              Offset(normal.dx * centerOffset, normal.dy * centerOffset),
            );
          }
        }
        final glyphTolerance = (glyphMetrics[i].height / 2)
            .clamp(fontSize / 3, fontSize)
            .toDouble();
        runs.add(
          _TextHitRun.path(
            owner: owner,
            path: glyphPath,
            pathTolerance: glyphTolerance,
          ),
        );
      }

      cursor += glyphAdvance;
      consumed += glyphAdvance;
      if (cursor > metricLength + fontSize) {
        break;
      }
    }

    return consumed;
  }
}
