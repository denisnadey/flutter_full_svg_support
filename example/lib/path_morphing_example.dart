// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/path_normalizer.dart';
import 'package:full_svg_flutter/src/animation/path_interpolation.dart';
import 'dart:ui' as ui;

/// Example demonstrating SVG path morphing.
///
/// Shows how to morph between different shapes using path interpolation.
void main() {
  runApp(const PathMorphingExampleApp());
}

class PathMorphingExampleApp extends StatelessWidget {
  const PathMorphingExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Path Morphing Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const PathMorphingDemo(),
    );
  }
}

class PathMorphingDemo extends StatefulWidget {
  const PathMorphingDemo({super.key});

  @override
  State<PathMorphingDemo> createState() => _PathMorphingDemoState();
}

class _PathMorphingDemoState extends State<PathMorphingDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late PathMorpher _morpher;

  // Example paths
  static const String _squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
  static const String _circlePath =
      'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

  @override
  void initState() {
    super.initState();

    // Parse and normalize paths
    final parser = PathParser();
    final normalizer = PathNormalizer();

    final squareCommands = parser.parse(_squarePath);
    final circleCommands = parser.parse(_circlePath);

    final normalized = normalizer.normalize(squareCommands, circleCommands);

    // Create morpher
    _morpher = PathMorpher(
      fromCommands: normalized.from,
      toCommands: normalized.to,
    );

    // Setup animation
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Path Morphing Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Square ↔ Circle Morphing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              height: 300,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: PathMorphPainter(
                      path: _morpher.getPathAt(_controller.value),
                      color: Colors.blue,
                    ),
                    size: const Size(300, 300),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  const Text('Square'),
                  Expanded(
                    child: Slider(
                      value: _controller.value,
                      onChanged: (value) {
                        _controller.value = value;
                      },
                    ),
                  ),
                  const Text('Circle'),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                    _controller.isAnimating ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(_controller.isAnimating ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 16),
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
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This example demonstrates path morphing between a square '
                'and a circle using path interpolation. The paths are '
                'normalized to have the same number of cubic bezier commands, '
                'then smoothly interpolated.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Scale canvas to fit path
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PathMorphPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.color != color;
  }
}
