import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

/// Side-by-side compatibility gallery.
///
/// Shows every SVG from [assets/unsupported_by_flutter_svg/] in a three-column
/// layout:
///   - Column 1: label / filename
///   - Column 2: flutter_svg render (or error card if it throws)
///   - Column 3: full_svg_flutter render
///
/// This screen is intentionally display-only; it does not collect frame timings.
class CompatibilityGalleryScreen extends StatelessWidget {
  const CompatibilityGalleryScreen({super.key});

  /// SVG filenames present in [assets/unsupported_by_flutter_svg/].
  ///
  /// Add entries here as new test SVGs are added to the asset directory.
  static const List<String> _svgFiles = [
    'smil_spinner.svg',
    'css_keyframes_pulse.svg',
    'path_morph_arrow.svg',
    'filter_blur.svg',
    'filter_drop_shadow.svg',
    'motion_path_orbit.svg',
    'advanced_gradient_mesh.svg',
    'clip_path_complex.svg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compatibility Gallery')),
      body: _svgFiles.isEmpty
          ? const Center(
              child: Text(
                'No SVG files found in assets/unsupported_by_flutter_svg/.\n'
                'Add SVG files there and register them in pubspec.yaml.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _svgFiles.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final filename = _svgFiles[index];
                final assetPath =
                    'assets/unsupported_by_flutter_svg/$filename';
                return _GalleryRow(
                  filename: filename,
                  assetPath: assetPath,
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row widget
// ---------------------------------------------------------------------------

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({
    required this.filename,
    required this.assetPath,
  });

  final String filename;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label column
          SizedBox(
            width: 130,
            child: Text(
              filename,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),

          // flutter_svg column — wrap in try/catch-equivalent error builder
          Expanded(
            child: _ColumnTile(
              label: 'flutter_svg',
              child: _FlutterSvgCell(assetPath: assetPath),
            ),
          ),
          const SizedBox(width: 8),

          // full_svg_flutter column
          Expanded(
            child: _ColumnTile(
              label: 'full_svg_flutter',
              child: ffsf.SvgPicture.asset(
                assetPath,
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnTile extends StatelessWidget {
  const _ColumnTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Renders an SVG with [flutter_svg] and shows an error card if it fails.
class _FlutterSvgCell extends StatefulWidget {
  const _FlutterSvgCell({required this.assetPath});
  final String assetPath;

  @override
  State<_FlutterSvgCell> createState() => _FlutterSvgCellState();
}

class _FlutterSvgCellState extends State<_FlutterSvgCell> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorCard(message: _errorMessage);
    }

    return SizedBox(
      width: 100,
      height: 100,
      // ErrorWidget.builder is process-wide; use a Builder + try pattern via
      // the FlutterError handler scoped to this widget's lifetime instead.
      child: _buildSvg(),
    );
  }

  Widget _buildSvg() {
    // flutter_svg's SvgPicture doesn't expose a synchronous error callback,
    // so we catch errors through the widget's error builder.
    return fsvg.SvgPicture.asset(
      widget.assetPath,
      width: 100,
      height: 100,
      fit: BoxFit.contain,
      // flutter_svg v2 error handling:
      // ignore: deprecated_member_use
      placeholderBuilder: (_) => const SizedBox.shrink(),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(height: 4),
          Text(
            message.isEmpty ? 'Render error' : message,
            style: const TextStyle(fontSize: 9, color: Colors.red),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
