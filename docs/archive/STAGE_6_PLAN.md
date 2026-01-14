# Stage 6: Path Animations & animateMotion - Detailed Plan

**Дата начала:** 20 ноября 2025 г.  
**Приоритет:** P1 (High Priority)  
**Сложность:** ⭐⭐⭐⭐ (High - path morphing is complex)

---

## 🎯 Цели Stage 6

Реализовать полную поддержку path анимаций:
1. **Path morphing** - плавное преобразование одного пути в другой
2. **animateMotion** - движение элемента вдоль пути
3. **Path interpolation** - интерполяция между path командами

---

## 📋 Scope & Features

### 6.1 Path Parsing & Data Structures

**Файл:** `lib/src/animation/path_parser.dart`

```dart
// Структуры данных для path команд
abstract class PathCommand {
  String get type;
  List<double> get params;
}

class MoveToCommand extends PathCommand {
  final double x, y;
  final bool isRelative;
}

class LineToCommand extends PathCommand {
  final double x, y;
  final bool isRelative;
}

class CubicBezierCommand extends PathCommand {
  final double x1, y1, x2, y2, x, y;
  final bool isRelative;
}

class QuadraticBezierCommand extends PathCommand {
  final double x1, y1, x, y;
  final bool isRelative;
}

class ArcCommand extends PathCommand {
  final double rx, ry, rotation;
  final bool largeArc, sweep;
  final double x, y;
  final bool isRelative;
}

class ClosePathCommand extends PathCommand {}
```

**Функциональность:**
- ✅ Парсинг SVG path syntax (d="M10,10 L20,20")
- ✅ Поддержка всех команд: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z
- ✅ Обработка запятых и пробелов
- ✅ Обработка implicit команд (L после M)
- ✅ Валидация синтаксиса

**Примеры:**
```dart
final parser = PathParser();
final commands = parser.parse('M10,10 L20,20 C30,30 40,40 50,50 Z');
// Returns: [MoveToCommand(10,10), LineToCommand(20,20), 
//           CubicBezierCommand(30,30,40,40,50,50), ClosePathCommand()]
```

### 6.2 Path Normalization

**Файл:** `lib/src/animation/path_normalizer.dart`

**Функциональность:**
- ✅ Конвертация relative → absolute координаты
- ✅ Конвертация H/V → L (horizontal/vertical lines)
- ✅ Конвертация S/T → C/Q (smooth curves)
- ✅ Разбивка composite paths на одинаковое количество сегментов
- ✅ Добавление промежуточных точек для выравнивания

**Алгоритм:**
```
1. Parse path1 and path2
2. Convert all to absolute coordinates
3. Convert all to C (cubic bezier) commands
4. Ensure same number of commands
5. If different, subdivide curves
```

**Примеры:**
```dart
final normalizer = PathNormalizer();
final result = normalizer.normalize(
  'M10,10 L20,20',
  'M10,10 C15,15 20,20 25,25'
);
// Both normalized to same number of cubic bezier segments
```

### 6.3 Path Interpolation

**Файл:** `lib/src/animation/path_interpolation.dart`

**Функциональность:**
- ✅ Интерполяция между двумя нормализованными путями
- ✅ Linear interpolation координат
- ✅ Smooth interpolation для curve control points
- ✅ Генерация промежуточного пути по t (0.0 - 1.0)

**Алгоритм:**
```dart
Path interpolate(List<PathCommand> from, List<PathCommand> to, double t) {
  final path = Path();
  for (int i = 0; i < from.length; i++) {
    final cmdFrom = from[i];
    final cmdTo = to[i];
    
    if (cmdFrom is CubicBezierCommand && cmdTo is CubicBezierCommand) {
      final x1 = lerpDouble(cmdFrom.x1, cmdTo.x1, t)!;
      final y1 = lerpDouble(cmdFrom.y1, cmdTo.y1, t)!;
      final x2 = lerpDouble(cmdFrom.x2, cmdTo.x2, t)!;
      final y2 = lerpDouble(cmdFrom.y2, cmdTo.y2, t)!;
      final x = lerpDouble(cmdFrom.x, cmdTo.x, t)!;
      final y = lerpDouble(cmdFrom.y, cmdTo.y, t)!;
      
      path.cubicTo(x1, y1, x2, y2, x, y);
    }
  }
  return path;
}
```

### 6.4 Animate d Attribute

**Обновление:** `lib/src/animation/smil_parser.dart`

**Поддержка:**
```xml
<path d="M10,10 L50,10 L50,50 Z">
  <animate 
    attributeName="d" 
    from="M10,10 L50,10 L50,50 Z"
    to="M10,10 C30,10 50,30 50,50 Z"
    dur="2s"
    repeatCount="indefinite"/>
</path>
```

**Интеграция:**
```dart
// В SmilAnimation
if (attributeName == 'd') {
  final pathFrom = pathParser.parse(from);
  final pathTo = pathParser.parse(to);
  final normalized = normalizer.normalize(pathFrom, pathTo);
  
  return PathMorphAnimation(
    from: normalized.from,
    to: normalized.to,
    duration: duration,
    // ...
  );
}
```

### 6.5 animateMotion Support

**Файл:** `lib/src/animation/motion_path.dart`

**Функциональность:**
- ✅ Парсинг `<animateMotion>` элемента
- ✅ Вычисление позиции на пути по t (0.0 - 1.0)
- ✅ Поддержка `rotate="auto"` - автоматический поворот
- ✅ Поддержка `rotate="auto-reverse"`
- ✅ Поддержка `keyPoints` - контрольные точки на пути
- ✅ Path.computeMetrics() для точного позиционирования

**Пример XML:**
```xml
<circle cx="0" cy="0" r="5">
  <animateMotion 
    path="M10,10 C30,30 50,10 70,30"
    dur="3s"
    rotate="auto"
    repeatCount="indefinite"/>
</circle>
```

**Алгоритм:**
```dart
class MotionPathAnimation {
  final Path path;
  final Duration duration;
  final String? rotate; // "auto", "auto-reverse", or angle
  
  Matrix4 getTransformAt(double t) {
    final metrics = path.computeMetrics().first;
    final length = metrics.length;
    final tangent = metrics.getTangentForOffset(length * t)!;
    
    final position = tangent.position;
    final angle = tangent.angle;
    
    final matrix = Matrix4.identity();
    matrix.translate(position.dx, position.dy);
    
    if (rotate == 'auto') {
      matrix.rotateZ(angle);
    } else if (rotate == 'auto-reverse') {
      matrix.rotateZ(angle + pi);
    }
    
    return matrix;
  }
}
```

### 6.6 Integration with AnimatedSvgPainter

**Обновление:** `lib/src/animation/animated_svg_painter.dart`

```dart
class AnimatedSvgPainter extends CustomPainter {
  // Добавить обработку path morphing
  void _applyPathMorph(Canvas canvas, PathMorphAnimation anim, double t) {
    final interpolated = pathInterpolator.interpolate(
      anim.fromCommands,
      anim.toCommands,
      t,
    );
    
    canvas.drawPath(interpolated, paint);
  }
  
  // Добавить обработку animateMotion
  void _applyMotionPath(Canvas canvas, MotionPathAnimation anim, double t) {
    final transform = anim.getTransformAt(t);
    canvas.save();
    canvas.transform(transform.storage);
    // Render element
    canvas.restore();
  }
}
```

---

## 🧪 Testing Strategy

### Test Coverage: Minimum 20 tests

**Файл:** `test/animation/path_morphing_test.dart`

1. **Path Parser Tests (8 tests)**
   - Parse simple path (M, L, Z)
   - Parse cubic bezier (C)
   - Parse quadratic bezier (Q)
   - Parse arc (A)
   - Parse relative commands
   - Parse multiple subpaths
   - Handle invalid syntax
   - Handle edge cases (empty, whitespace)

2. **Path Normalization Tests (5 tests)**
   - Normalize different command counts
   - Convert relative to absolute
   - Convert H/V to L
   - Subdivide curves
   - Handle closed paths

3. **Path Interpolation Tests (4 tests)**
   - Interpolate at t=0 (should equal from)
   - Interpolate at t=1 (should equal to)
   - Interpolate at t=0.5 (midpoint)
   - Interpolate complex paths

**Файл:** `test/animation/motion_path_test.dart`

4. **animateMotion Tests (3 tests)**
   - Position at start (t=0)
   - Position at end (t=1)
   - Auto rotation calculation

**Golden Tests:**
```dart
test/animation/path_morph_golden_test.dart
- Star to circle morph
- Rectangle to rounded rectangle
- Complex shape morphing
```

---

## 📐 Implementation Steps

### Phase 1: Foundation (Day 1)
- [x] Create STAGE_6_PLAN.md
- [ ] Create `lib/src/animation/path_parser.dart`
- [ ] Create `lib/src/animation/path_data.dart` (data structures)
- [ ] Implement basic path parsing (M, L, Z commands)
- [ ] Write tests for path parser

### Phase 2: Normalization (Day 1-2)
- [ ] Create `lib/src/animation/path_normalizer.dart`
- [ ] Implement relative→absolute conversion
- [ ] Implement command standardization
- [ ] Implement curve subdivision
- [ ] Write normalization tests

### Phase 3: Interpolation (Day 2)
- [ ] Create `lib/src/animation/path_interpolation.dart`
- [ ] Implement linear interpolation
- [ ] Handle command alignment
- [ ] Write interpolation tests

### Phase 4: Integration (Day 2-3)
- [ ] Update SmilParser for `attributeName="d"`
- [ ] Update AnimatedSvgPainter for path morphing
- [ ] Create PathMorphAnimation class
- [ ] Integration tests

### Phase 5: animateMotion (Day 3)
- [ ] Create `lib/src/animation/motion_path.dart`
- [ ] Implement path metrics calculation
- [ ] Implement auto rotation
- [ ] Update SmilParser for `<animateMotion>`
- [ ] Write motion tests

### Phase 6: Polish & Docs (Day 3-4)
- [ ] Golden tests
- [ ] Performance testing
- [ ] Create examples in example/
- [ ] Update ANIMATION_README.md
- [ ] Create STAGE_6_RESULTS.md

---

## 📊 Success Criteria

### Code Quality
- ✅ All tests passing (minimum 20 new tests)
- ✅ No performance regressions
- ✅ Clean, documented code
- ✅ Type safety (no dynamic)

### Feature Completeness
- ✅ Path morphing works for simple shapes
- ✅ Path morphing works for complex paths
- ✅ animateMotion positions correctly
- ✅ Auto rotation works
- ✅ Examples demonstrate all features

### Performance Targets
- ✅ Path parsing: <1ms for typical paths
- ✅ Interpolation: <2ms per frame
- ✅ 60 FPS for simple morphs
- ✅ 30+ FPS for complex morphs

---

## 🚧 Known Challenges

### Challenge 1: Path Compatibility
**Problem:** Paths with different structures are hard to morph  
**Solution:** Aggressive normalization + curve subdivision

### Challenge 2: Arc Commands
**Problem:** Arc interpolation is mathematically complex  
**Solution:** Convert arcs to cubic bezier approximations

### Challenge 3: Performance
**Problem:** Path interpolation every frame is expensive  
**Solution:** 
- Cache normalized paths
- Use PathMetrics efficiently
- Consider rasterization for very complex paths

### Challenge 4: Different Subpath Counts
**Problem:** From has 2 subpaths, To has 3  
**Solution:** Add zero-length subpaths to match count

---

## 📚 References

### SVG Specification
- [SVG Path Specification](https://www.w3.org/TR/SVG/paths.html)
- [animateMotion Element](https://www.w3.org/TR/SVG/animate.html#AnimateMotionElement)

### Path Morphing Algorithms
- [Flubber.js Path Interpolation](https://github.com/veltman/flubber)
- [GreenSock MorphSVG](https://greensock.com/docs/v3/Plugins/MorphSVGPlugin)
- [D3 Path Interpolation](https://github.com/d3/d3-interpolate)

### Flutter APIs
- [Path class](https://api.flutter.dev/flutter/dart-ui/Path-class.html)
- [PathMetric](https://api.flutter.dev/flutter/dart-ui/PathMetric-class.html)
- [Tangent](https://api.flutter.dev/flutter/dart-ui/Tangent-class.html)

---

## 🎯 Expected Outcomes

### New Files (6-8 files)
1. `lib/src/animation/path_parser.dart` (~200 lines)
2. `lib/src/animation/path_data.dart` (~150 lines)
3. `lib/src/animation/path_normalizer.dart` (~250 lines)
4. `lib/src/animation/path_interpolation.dart` (~150 lines)
5. `lib/src/animation/motion_path.dart` (~200 lines)
6. `test/animation/path_morphing_test.dart` (~300 lines)
7. `test/animation/motion_path_test.dart` (~150 lines)
8. `test/animation/path_morph_golden_test.dart` (~100 lines)

### Total New Code: ~1500 lines

### Test Count
- Current: 113 tests
- Adding: 20+ tests
- **Target: 133+ tests**

---

## 🚀 Next Steps After Stage 6

**Stage 7:** CSS Animations (@keyframes)  
**Stage 8:** Event-based timing & sync  
**Stage 9:** Performance optimizations  
**Stage 10:** Complete documentation  

---

**Ready to start implementation!** 🎉

Let's begin with path parser foundation.
