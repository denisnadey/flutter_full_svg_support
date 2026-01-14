import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../widgets/animation_theme.dart';

/// Reusable Path Morphing Widget for unified examples
class PathMorphingWidget extends StatefulWidget {
  const PathMorphingWidget({super.key});

  @override
  State<PathMorphingWidget> createState() => _PathMorphingWidgetState();
}

class _PathMorphingWidgetState extends State<PathMorphingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedExample = 0;

  final List<_MorphingExample> _examples = const [
    _MorphingExample(
      name: 'Square to Circle',
      path1: 'M10,10 L90,10 L90,90 L10,90 Z',
      path2:
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z',
      color1: Colors.green,
      color2: Colors.purple,
    ),
    _MorphingExample(
      name: 'Star to Heart',
      path1:
          'M50,10 L61,35 L90,35 L67,52 L78,85 L50,65 L22,85 L33,52 L10,35 L39,35 Z',
      path2:
          'M50,90 C50,90 20,65 20,45 C20,30 27,20 40,20 C47,20 50,25 50,25 C50,25 53,20 60,20 C73,20 80,30 80,45 C80,65 50,90 50,90 Z',
      color1: Colors.amber,
      color2: Colors.red,
    ),
    _MorphingExample(
      name: 'Triangle to Hexagon',
      path1: 'M50,10 L90,85 L10,85 Z',
      path2: 'M50,10 L85,30 L85,70 L50,90 L15,70 L15,30 Z',
      color1: Colors.blue,
      color2: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedExample];

    return Column(
      children: [
        // Example selector
        Container(
          padding: const EdgeInsets.all(AnimationTheme.spacingMedium),
          decoration: AnimationTheme.getControlPanelDecoration(context),
          child: SegmentedButton<int>(
            segments: _examples
                .asMap()
                .entries
                .map(
                  (e) => ButtonSegment(
                    value: e.key,
                    label: Text(
                      e.value.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            selected: {_selectedExample},
            onSelectionChanged: (Set<int> selected) {
              setState(() {
                _selectedExample = selected.first;
              });
            },
          ),
        ),

        // Animation display
        Expanded(
          child: Container(
            decoration: AnimationTheme.getAnimationDisplayDecoration(context),
            margin: const EdgeInsets.all(AnimationTheme.spacingMedium),
            child: _MorphingDisplay(example: example, controller: _controller),
          ),
        ),

        // Controls
        AnimationControlPanel(
          controller: _controller,
          onPlayPause: () {
            setState(() {
              if (_controller.isAnimating) {
                _controller.stop();
              } else {
                _controller.repeat(reverse: true);
              }
            });
          },
          onReset: () {
            setState(() {
              _controller.reset();
            });
          },
          title: example.name,
          subtitle: 'Path morphing animation',
        ),
      ],
    );
  }
}

class _MorphingExample {
  const _MorphingExample({
    required this.name,
    required this.path1,
    required this.path2,
    required this.color1,
    required this.color2,
  });

  final String name;
  final String path1;
  final String path2;
  final Color color1;
  final Color color2;
}

class _MorphingDisplay extends StatelessWidget {
  const _MorphingDisplay({required this.example, required this.controller});

  final _MorphingExample example;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Simple transition for now (will be replaced with actual morphing)
        final t = controller.value;
        final path = ui.Path();

        if (t < 0.5) {
          path.addRect(const Rect.fromLTWH(10, 10, 80, 80));
        } else {
          path.addOval(const Rect.fromLTWH(10, 10, 80, 80));
        }

        final color = Color.lerp(example.color1, example.color2, t)!;

        return CustomPaint(
          painter: _PathPainter(path: path, color: color),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.path, required this.color});

  final ui.Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bounds = path.getBounds();
    final scale = (size.width * 0.8) / bounds.width.clamp(1, double.infinity);
    final offsetX =
        (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final offsetY =
        (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    canvas.drawPath(path, paint);
    canvas.restore();

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2 / scale;
    paint.color = color.withValues(alpha: 0.5);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.color != color;
  }
}
