import 'dart:math' as math;
import 'dart:ui' as ui;

/// Тип SVG фильтра
enum SvgFilterType {
  /// Gaussian blur - размытие
  gaussianBlur,
  
  /// Drop shadow - тень
  dropShadow,
  
  /// Color matrix - цветовые трансформации
  colorMatrix,
}

/// Тип цветовой матрицы для feColorMatrix
enum SvgColorMatrixType {
  /// Матрица 5x4 (20 значений)
  matrix,
  
  /// Насыщенность (1 значение: 0-1)
  saturate,
  
  /// Hue rotate (1 значение: градусы)
  hueRotate,
  
  /// Luminance to alpha (нет значений)
  luminanceToAlpha,
}

/// Базовый класс для SVG фильтра
abstract class SvgFilter {
  /// ID фильтра
  final String id;
  
  /// Тип фильтра
  final SvgFilterType type;
  
  SvgFilter({required this.id, required this.type});
  
  /// Применить фильтр к изображению
  /// Возвращает ImageFilter для использования в Flutter Canvas
  ui.ImageFilter? apply();
}

/// Gaussian Blur фильтр
/// 
/// Использует ImageFilter.blur для размытия
class SvgGaussianBlurFilter extends SvgFilter {
  /// Стандартное отклонение по X (размытие по горизонтали)
  final double stdDeviationX;
  
  /// Стандартное отклонение по Y (размытие по вертикали)
  final double stdDeviationY;
  
  SvgGaussianBlurFilter({
    required super.id,
    required this.stdDeviationX,
    required this.stdDeviationY,
  }) : super(type: SvgFilterType.gaussianBlur);
  
  @override
  ui.ImageFilter? apply() {
    // Flutter ImageFilter.blur использует sigma (стандартное отклонение)
    // В SVG stdDeviation = sigma
    return ui.ImageFilter.blur(
      sigmaX: stdDeviationX,
      sigmaY: stdDeviationY,
    );
  }
}

/// Drop Shadow фильтр
/// 
/// Создает тень от объекта
class SvgDropShadowFilter extends SvgFilter {
  /// Смещение по X
  final double dx;
  
  /// Смещение по Y
  final double dy;
  
  /// Стандартное отклонение (размытие тени)
  final double stdDeviation;
  
  /// Цвет тени
  final ui.Color? floodColor;
  
  SvgDropShadowFilter({
    required super.id,
    required this.dx,
    required this.dy,
    required this.stdDeviation,
    this.floodColor,
  }) : super(type: SvgFilterType.dropShadow);
  
  @override
  ui.ImageFilter? apply() {
    // Flutter не имеет прямого drop shadow ImageFilter
    // Используем комбинацию blur + offset
    // Можно использовать PictureRecorder для создания тени, затем blur
    // Для упрощения используем только blur, offset будет применен через transform
    // TODO: Реализовать полный drop shadow с цветом через PictureRecorder
    
    // Создаем blur фильтр для тени
    final blurFilter = ui.ImageFilter.blur(sigmaX: stdDeviation, sigmaY: stdDeviation);
    
    // TODO: Реализовать полный drop shadow с offset через PictureRecorder
    // Пока возвращаем blur фильтр
    return blurFilter;
  }
  
  /// Получить offset для применения через transform
  ui.Offset get offset => ui.Offset(dx, dy);
}

/// Color Matrix фильтр
/// 
/// Применяет цветовые трансформации
class SvgColorMatrixFilter extends SvgFilter {
  /// Тип трансформации
  final SvgColorMatrixType matrixType;
  
  /// Значения для матрицы (зависят от типа)
  final List<double> values;
  
  SvgColorMatrixFilter({
    required super.id,
    required this.matrixType,
    required this.values,
  }) : super(type: SvgFilterType.colorMatrix);
  
  @override
  ui.ImageFilter? apply() {
    switch (matrixType) {
      case SvgColorMatrixType.matrix:
        if (values.length == 20) {
          // Матрица 5x4 для RGBA
          // Преобразуем в ColorFilter.matrix (4x5 матрица в Flutter)
          return ui.ColorFilter.matrix(_convertSvgMatrixToFlutter(values));
        }
        return null;
        
      case SvgColorMatrixType.saturate:
        if (values.isNotEmpty) {
          // Насыщенность (0 = grayscale, 1 = normal)
          return ui.ColorFilter.matrix(_saturateMatrix(values[0]));
        }
        return null;
        
      case SvgColorMatrixType.hueRotate:
        if (values.isNotEmpty) {
          // Hue rotation в градусах
          return ui.ColorFilter.matrix(_hueRotateMatrix(values[0]));
        }
        return null;
        
      case SvgColorMatrixType.luminanceToAlpha:
        // Luminance to alpha - специальная матрица
        return ui.ColorFilter.matrix(_luminanceToAlphaMatrix());
    }
  }
  
  /// Конвертирует SVG матрицу 5x4 (20 значений) в Flutter матрицу 4x5 (20 значений)
  /// 
  /// SVG формат: строка за строкой (R, G, B, A, 1 для каждой строки)
  /// Flutter формат: столбец за столбцом (RGBA + offset)
  List<double> _convertSvgMatrixToFlutter(List<double> svgMatrix) {
    // SVG matrix (5x4):
    // [Rr Rg Rb Ra Rk]
    // [Gr Gg Gb Ga Gk]
    // [Br Bg Bb Ba Bk]
    // [Ar Ag Ab Aa Ak]
    //
    // Flutter matrix (4x5):
    // [Rr Gr Br Ar] - red column
    // [Rg Gg Bg Ag] - green column
    // [Rb Gb Bb Ab] - blue column
    // [Ra Ga Ba Aa] - alpha column
    // [Rk Gk Bk Ak] - offset row
    
    final result = <double>[];
    
    // Red column: Rr, Gr, Br, Ar
    result.addAll([svgMatrix[0], svgMatrix[5], svgMatrix[10], svgMatrix[15]]);
    
    // Green column: Rg, Gg, Bg, Ag
    result.addAll([svgMatrix[1], svgMatrix[6], svgMatrix[11], svgMatrix[16]]);
    
    // Blue column: Rb, Gb, Bb, Ab
    result.addAll([svgMatrix[2], svgMatrix[7], svgMatrix[12], svgMatrix[17]]);
    
    // Alpha column: Ra, Ga, Ba, Aa
    result.addAll([svgMatrix[3], svgMatrix[8], svgMatrix[13], svgMatrix[18]]);
    
    // Offset row: Rk, Gk, Bk, Ak (умножаем на 255 так как Flutter работает в [0-1], а SVG в [0-255])
    result.addAll([
      svgMatrix[4] / 255.0,
      svgMatrix[9] / 255.0,
      svgMatrix[14] / 255.0,
      svgMatrix[19] / 255.0,
    ]);
    
    return result;
  }
  
  /// Создает матрицу для насыщенности (saturate)
  List<double> _saturateMatrix(double s) {
    // SVG saturate matrix formula
    final r = 0.2126 + 0.7874 * s;
    final g = 0.7152 + 0.2848 * s;
    final b = 0.0722 + 0.9278 * s;
    
    return [
      r, 0, 0, 0, 0, // Red row
      0, g, 0, 0, 0, // Green row
      0, 0, b, 0, 0, // Blue row
      0, 0, 0, 1, 0, // Alpha row
    ];
  }
  
  /// Создает матрицу для hue rotation (поворот оттенка)
  List<double> _hueRotateMatrix(double degrees) {
    // Конвертируем градусы в радианы
    final radians = degrees * 3.141592653589793 / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    
    // Hue rotation matrix
    return [
      0.213 + cos * 0.787 + sin * -0.213, // Rr
      0.715 + cos * -0.715 + sin * -0.715, // Rg
      0.072 + cos * -0.072 + sin * 0.928, // Rb
      0, 0, // Ra, Rk
      
      0.213 + cos * -0.213 + sin * 0.143, // Gr
      0.715 + cos * 0.285 + sin * 0.140, // Gg
      0.072 + cos * -0.072 + sin * -0.283, // Gb
      0, 0, // Ga, Gk
      
      0.213 + cos * -0.213 + sin * -0.787, // Br
      0.715 + cos * -0.715 + sin * 0.715, // Bg
      0.072 + cos * 0.928 + sin * 0.072, // Bb
      0, 0, // Ba, Bk
      
      0, 0, 0, 1, 0, // Alpha row
    ];
  }
  
  /// Создает матрицу для luminance to alpha
  List<double> _luminanceToAlphaMatrix() {
    // Luminance weights: 0.2126 * R + 0.7152 * G + 0.0722 * B
    return [
      0, 0, 0, 0, 0, // Red row
      0, 0, 0, 0, 0, // Green row
      0, 0, 0, 0, 0, // Blue row
      0.2126, 0.7152, 0.0722, 0, 0, // Alpha row
    ];
  }
}

/// Коллекция фильтров в SVG документе
class SvgFilters {
  /// Карта ID фильтра -> фильтр
  final Map<String, SvgFilter> _filters = {};
  
  /// Добавить фильтр
  void add(SvgFilter filter) {
    _filters[filter.id] = filter;
  }
  
  /// Получить фильтр по ID
  SvgFilter? getById(String id) {
    return _filters[id];
  }
  
  /// Проверить наличие фильтра
  bool hasFilter(String id) {
    return _filters.containsKey(id);
  }
  
  /// Получить все фильтры
  List<SvgFilter> get all => _filters.values.toList();
}
