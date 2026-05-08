import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

class SvgatorDemoPage extends StatefulWidget {
  const SvgatorDemoPage({super.key});

  @override
  State<SvgatorDemoPage> createState() => _SvgatorDemoPageState();
}

class _SvgatorDemoPageState extends State<SvgatorDemoPage> {
  String? _svgString;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    try {
      final svgString = await rootBundle.loadString(
        'assets/simple/svgator_dog.svg',
      );
      if (mounted) {
        setState(() {
          _svgString = svgString;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVGator Dog Animation'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load SVG',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    final svg = _svgString!;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AnimatedSvgPicture.string(
              svg,
              width: 400,
              height: 400,
            ),
          ),
        ),
        _buildInfoPanel(),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SVGator Dog Character Animation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Rendered via JS bridge: inline <script> loads the SVGator player '
            'from CDN, which drives transforms/paths via requestAnimationFrame.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
