import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/path_normalizer.dart';
import 'package:full_svg_flutter/src/animation/path_interpolation.dart';
import 'dart:ui' as ui;

/// Advanced path morphing example with multiple shapes
void main() {
  runApp(const AdvancedPathMorphingApp());
}

class AdvancedPathMorphingApp extends StatelessWidget {
  const AdvancedPathMorphingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Path Morphing',
      theme: ThemeData(primarySwatch: Colors.purple, useMaterial3: true),
      home: const AdvancedMorphingDemo(),
    );
  }
}

/// Predefined shape paths
class ShapePaths {
  // Star
  static const String star =
      'M50,5 L61,38 L95,38 L68,58 L79,91 L50,71 L21,91 L32,58 L5,38 L39,38 Z';

  // Heart
  static const String heart =
      'M50,85 L20,55 C10,45 10,30 20,20 C30,10 45,10 50,20 '
      'C55,10 70,10 80,20 C90,30 90,45 80,55 Z';

  // Triangle
  static const String triangle = 'M50,10 L90,90 L10,90 Z';

  // Square
  static const String square = 'M10,10 L90,10 L90,90 L10,90 Z';

  // Circle
  static const String circle =
      'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 '
      'A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

  // Hexagon
  static const String hexagon = 'M50,10 L80,30 L80,70 L50,90 L20,70 L20,30 Z';

  static final List<ShapeDefinition> all = [
    ShapeDefinition('Star', star, Colors.amber),
    ShapeDefinition('Heart', heart, Colors.red),
    ShapeDefinition('Triangle', triangle, Colors.blue),
    ShapeDefinition('Square', square, Colors.green),
    ShapeDefinition('Circle', circle, Colors.purple),
    ShapeDefinition('Hexagon', hexagon, Colors.orange),
  ];
}

class ShapeDefinition {
  const ShapeDefinition(this.name, this.path, this.color);

  final String name;
  final String path;
  final Color color;
}

class AdvancedMorphingDemo extends StatefulWidget {
  const AdvancedMorphingDemo({super.key});

  @override
  State<AdvancedMorphingDemo> createState() => _AdvancedMorphingDemoState();
}

class _AdvancedMorphingDemoState extends State<AdvancedMorphingDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  PathMorpher? _morpher;
  int _fromIndex = 0;
  int _toIndex = 1;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _updateMorpher();
  }

  void _updateMorpher() {
    final parser = PathParser();
    final normalizer = PathNormalizer();

    final fromCommands = parser.parse(ShapePaths.all[_fromIndex].path);
    final toCommands = parser.parse(ShapePaths.all[_toIndex].path);

    final normalized = normalizer.normalize(fromCommands, toCommands);

    setState(() {
      _morpher = PathMorpher(
        fromCommands: normalized.from,
        toCommands: normalized.to,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _interpolatedColor {
    return Color.lerp(
      ShapePaths.all[_fromIndex].color,
      ShapePaths.all[_toIndex].color,
      _controller.value,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Path Morphing'), elevation: 2),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  if (_morpher == null) {
                    return const CircularProgressIndicator();
                  }
                  return CustomPaint(
                    painter: PathMorphPainter(
                      path: _morpher!.getPathAt(_controller.value),
                      color: _interpolatedColor,
                    ),
                    size: const Size(400, 400),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildShapeSelector('From Shape', _fromIndex, (
                        index,
                      ) {
                        if (index != _toIndex) {
                          setState(() => _fromIndex = index);
                          _updateMorpher();
                        }
                      }),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.arrow_forward, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildShapeSelector('To Shape', _toIndex, (index) {
                        if (index != _fromIndex) {
                          setState(() => _toIndex = index);
                          _updateMorpher();
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_controller.isAnimating) {
                          _controller.stop();
                        } else {
                          _controller.repeat(reverse: true);
                        }
                        setState(() {});
                      },
                      icon: Icon(
                        _controller.isAnimating
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(_controller.isAnimating ? 'Pause' : 'Play'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _controller.reset();
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _controller.value,
                  onChanged: (value) {
                    _controller.value = value;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Morphing: ${(_controller.value * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeSelector(
    String label,
    int selectedIndex,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButton<int>(
          value: selectedIndex,
          isExpanded: true,
          items: ShapePaths.all.asMap().entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: entry.value.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }
}

/// Custom painter for rendering morphed paths
class PathMorphPainter extends CustomPainter {
  PathMorphPainter({required this.path, required this.color});

  final ui.Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Scale canvas to fit path
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PathMorphPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.color != color;
  }
}
