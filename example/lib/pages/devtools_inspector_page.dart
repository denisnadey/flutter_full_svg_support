import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

/// A stable manual-verification surface for the FullSVG DevTools extension.
class DevToolsInspectorPage extends StatelessWidget {
  const DevToolsInspectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FullSVG DevTools Test Screen')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Keep this screen open, then select the FullSVG extension in '
            'Flutter DevTools. Leaving this route should remove all four '
            'instances from the inspector.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              const _ExampleCard(
                title: 'Static asset',
                description: 'Filters, gradient, and stable asset metadata',
                child: FSvgPicture.asset(
                  'assets/simple/linear_gradient.svg',
                  width: 220,
                  height: 180,
                ),
              ),
              const _ExampleCard(
                title: 'SMIL + CSS animation',
                description: 'Pause, seek, restart, and change playback rate',
                child: FSvgPicture.string(
                  _animatedSvg,
                  width: 220,
                  height: 180,
                ),
              ),
              const _ExampleCard(
                title: 'Nested DOM',
                description: 'Expand groups and highlight exact path geometry',
                child: FSvgPicture.string(_nestedSvg, width: 220, height: 180),
              ),
              _ExampleCard(
                title: 'JavaScript runtime',
                description: 'Real inline-script bridge (inspection only)',
                child: AnimatedSvgPicture.asset(
                  'assets/simple/js_interactive_demo.svg',
                  width: 220,
                  height: 180,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Center(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

const _animatedSvg = '''
<svg viewBox="0 0 220 180" xmlns="http://www.w3.org/2000/svg">
  <style>
    @keyframes pulse { from { opacity: .35; } to { opacity: 1; } }
    .halo { animation: pulse 1s ease-in-out infinite alternate; }
  </style>
  <circle class="halo" cx="110" cy="90" r="64" fill="#6750A4" opacity=".5"/>
  <g id="spinner">
    <path id="animated-path" d="M110 25 A65 65 0 0 1 175 90"
          fill="none" stroke="#EADDFF" stroke-width="12" stroke-linecap="round">
      <animateTransform attributeName="transform" type="rotate"
          from="0 110 90" to="360 110 90" dur="3s" repeatCount="indefinite"/>
    </path>
  </g>
</svg>
''';

const _nestedSvg = '''
<svg viewBox="0 0 220 180" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="nested-gradient"><stop stop-color="#4FC3F7"/><stop offset="1" stop-color="#1565C0"/></linearGradient>
    <clipPath id="round-clip"><rect x="20" y="20" width="180" height="140" rx="24"/></clipPath>
  </defs>
  <g id="scene" clip-path="url(#round-clip)">
    <rect id="background" x="20" y="20" width="180" height="140" fill="url(#nested-gradient)"/>
    <g id="character" class="hero featured" transform="translate(55 35)">
      <g id="head"><circle id="face" cx="55" cy="35" r="26" fill="#FFE0B2"/><path id="smile" d="M43 40 Q55 51 67 40" fill="none" stroke="#5D4037" stroke-width="3"/></g>
      <g id="body"><path id="torso" d="M25 70 Q55 55 85 70 L95 130 L15 130 Z" fill="#7E57C2"/><path id="badge" d="M55 74 l7 14 15 2-11 11 3 15-14-7-14 7 3-15-11-11 15-2z" fill="#FFD54F"/></g>
    </g>
  </g>
</svg>
''';
