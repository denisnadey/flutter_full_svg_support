part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateStyleExtension on _AnimatedSvgPictureState {
  FontWeight _resolveFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return FontWeight.normal;
    }
    switch (fontWeight.toLowerCase()) {
      case '100':
      case 'thin':
        return FontWeight.w100;
      case '200':
      case 'extralight':
      case 'extra-light':
        return FontWeight.w200;
      case '300':
      case 'light':
        return FontWeight.w300;
      case '500':
      case 'medium':
        return FontWeight.w500;
      case '600':
      case 'semibold':
      case 'semi-bold':
        return FontWeight.w600;
      case '700':
      case 'bold':
        return FontWeight.w700;
      case '800':
      case 'extrabold':
      case 'extra-bold':
        return FontWeight.w800;
      case '900':
      case 'black':
        return FontWeight.w900;
      case '400':
      case 'normal':
      default:
        return FontWeight.normal;
    }
  }

  FontStyle _resolveFontStyle(String? fontStyle) {
    return fontStyle?.toLowerCase() == 'italic'
        ? FontStyle.italic
        : FontStyle.normal;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared == 0) {
      return (p - a).distance;
    }

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(
      0.0,
      1.0,
    );
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  List<Offset> _parsePoints(SvgNode node) {
    final value = node.getAttributeValue('points')?.toString();
    if (value == null || value.trim().isEmpty) {
      return const <Offset>[];
    }

    final numbers = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (numbers.length < 2) {
      return const <Offset>[];
    }

    final points = <Offset>[];
    for (int i = 0; i + 1 < numbers.length; i += 2) {
      points.add(Offset(numbers[i], numbers[i + 1]));
    }
    return points;
  }
}
