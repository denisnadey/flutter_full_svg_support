import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../l10n/app_localizations.dart';
import '../widgets/animation_theme.dart';

/// Page demonstrating path morphing animations
class PathMorphingPage extends StatefulWidget {
  const PathMorphingPage({super.key});

  @override
  State<PathMorphingPage> createState() => _PathMorphingPageState();
}

class _PathMorphingPageState extends State<PathMorphingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedExample = 0;

  final List<_MorphingExample> _examples = const [
    _MorphingExample(
      name: 'square_to_circle',
      path1: 'M10,10 L90,10 L90,90 L10,90 Z',
      path2:
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z',
      color1: Colors.green,
      color2: Colors.purple,
    ),
    _MorphingExample(
      name: 'star_to_heart',
      path1:
          'M50,10 L61,35 L90,35 L67,52 L78,85 L50,65 L22,85 L33,52 L10,35 L39,35 Z',
      path2:
          'M50,90 C50,90 20,65 20,45 C20,30 27,20 40,20 C47,20 50,25 50,25 C50,25 53,20 60,20 C73,20 80,30 80,45 C80,65 50,90 50,90 Z',
      color1: Colors.amber,
      color2: Colors.red,
    ),
    _MorphingExample(
      name: 'triangle_to_hexagon',
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
    final l10n = AppLocalizations.of(context);
    final example = _examples[_selectedExample];

    return AnimationExampleLayout(
      title: l10n.pathMorphing,
      headerWidget: _buildExampleSelector(context, l10n),
      animationDisplay: _MorphingWidget(
        example: example,
        controller: _controller,
      ),
      controlPanel: AnimationControlPanel(
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
        title:
            _getShapeName(_selectedExample, true, l10n) +
            ' ↔ ' +
            _getShapeName(_selectedExample, false, l10n),
        subtitle: l10n.pathMorphingDesc,
      ),
    );
  }

  Widget _buildExampleSelector(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AnimationTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.pathAnimations,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AnimationTheme.spacingMedium),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.squareToCircle),
                icon: const Icon(Icons.crop_square, size: 18),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.starToHeart),
                icon: const Icon(Icons.favorite_border, size: 18),
              ),
              ButtonSegment(
                value: 2,
                label: Text(l10n.triangleToHexagon),
                icon: const Icon(Icons.change_history, size: 18),
              ),
            ],
            selected: {_selectedExample},
            onSelectionChanged: (Set<int> selected) {
              setState(() {
                _selectedExample = selected.first;
              });
            },
          ),
        ],
      ),
    );
  }

  String _getShapeName(int index, bool isFirst, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return isFirst ? 'Square' : 'Circle';
      case 1:
        return isFirst ? 'Star' : 'Heart';
      case 2:
        return isFirst ? 'Triangle' : 'Hexagon';
      default:
        return '';
    }
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

class _MorphingWidget extends StatefulWidget {
  const _MorphingWidget({required this.example, required this.controller});

  final _MorphingExample example;
  final AnimationController controller;

  @override
  State<_MorphingWidget> createState() => _MorphingWidgetState();
}

class _MorphingWidgetState extends State<_MorphingWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        // Interpolate color
        final color = Color.lerp(
          widget.example.color1,
          widget.example.color2,
          widget.controller.value,
        )!;

        // Create path based on progress
        // Simple transition for now
        final t = widget.controller.value;
        final path = ui.Path();

        // Parse SVG paths and interpolate
        if (t < 0.5) {
          // Use start path
          path.addRect(const Rect.fromLTWH(10, 10, 80, 80));
        } else {
          // Use end path
          path.addOval(const Rect.fromLTWH(10, 10, 80, 80));
        }

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

    // Center the path
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

    // Draw stroke
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
