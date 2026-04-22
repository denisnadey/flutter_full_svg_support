import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import 'animation_theme.dart';

/// Reusable Metrics Widget for unified examples
class MetricsWidget extends StatelessWidget {
  const MetricsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const svgXml = '''
      <svg viewBox="0 0 100 100">
        <circle cx="50" cy="50" r="10" fill="blue">
          <animate attributeName="r" from="10" to="40" dur="2s" repeatCount="indefinite"/>
        </circle>
        <rect x="30" y="30" width="5" height="5" fill="red">
          <animate attributeName="x" from="10" to="80" dur="3s" repeatCount="indefinite"/>
          <animate attributeName="y" from="10" to="80" dur="2s" repeatCount="indefinite"/>
        </rect>
      </svg>
    ''';

    return Column(
      children: [
        // SVG Display
        Expanded(
          child: Container(
            decoration: AnimationTheme.getAnimationDisplayDecoration(context),
            margin: const EdgeInsets.all(AnimationTheme.spacingMedium),
            child: const Center(
              child: AnimatedSvgPicture.string(svgXml, width: 300, height: 300),
            ),
          ),
        ),

        // Metrics Panel
        Container(
          padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
          decoration: AnimationTheme.getControlPanelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Performance Metrics',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnimationTheme.spacingMedium),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric(context, 'Elements', '2'),
                  _buildMetric(context, 'Animations', '3'),
                  _buildMetric(context, 'Duration', '∞'),
                ],
              ),
              const SizedBox(height: AnimationTheme.spacingSmall),
              const Divider(),
              const SizedBox(height: AnimationTheme.spacingSmall),
              Text(
                'Use FPS monitor (top right) to track real-time performance',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AnimationTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
