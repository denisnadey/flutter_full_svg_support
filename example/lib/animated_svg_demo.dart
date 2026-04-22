import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

/// SMIL animation demo examples
void main() {
  runApp(const AnimatedSvgDemo());
}

class AnimatedSvgDemo extends StatelessWidget {
  const AnimatedSvgDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animated SVG Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const DemoHomePage(),
    );
  }
}

/// Demo example data class
class _DemoExample {
  final String title;
  final String subtitle;
  final String svgXml;
  final Color accentColor;

  const _DemoExample({
    required this.title,
    required this.subtitle,
    required this.svgXml,
    required this.accentColor,
  });
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  static const _examples = [
    _DemoExample(
      title: 'Horizontal Motion',
      subtitle: 'animate x position',
      accentColor: Colors.blue,
      svgXml: '''
        <svg viewBox="0 0 100 50">
          <rect x="0" y="15" width="20" height="20" fill="blue">
            <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Pulsing Circle',
      subtitle: 'animate radius',
      accentColor: Colors.red,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="10" fill="red">
            <animate attributeName="r" from="10" to="40" dur="1s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Fade Effect',
      subtitle: 'animate opacity',
      accentColor: Colors.green,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="25" y="25" width="50" height="50" fill="green">
            <animate attributeName="opacity" from="1" to="0" dur="2s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Size Animation',
      subtitle: 'animate width & height',
      accentColor: Colors.purple,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="25" y="25" width="10" height="10" fill="purple">
            <animate attributeName="width" from="10" to="50" dur="1.5s" repeatCount="indefinite"/>
            <animate attributeName="height" from="10" to="50" dur="1.5s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Keyframe Animation',
      subtitle: 'values + keyTimes',
      accentColor: Colors.orange,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="20" fill="orange">
            <animate 
              attributeName="cx" 
              values="20;80;20" 
              keyTimes="0;0.5;1"
              dur="3s" 
              repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Discrete Mode',
      subtitle: 'calcMode="discrete"',
      accentColor: Colors.cyan,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="40" width="20" height="20" fill="cyan">
            <animate 
              attributeName="x" 
              values="10;40;70" 
              calcMode="discrete"
              dur="1.5s" 
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Multi-Element',
      subtitle: 'synchronized circles',
      accentColor: Colors.teal,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="20" cy="50" r="8" fill="red">
            <animate attributeName="cy" from="50" to="20" dur="1s" repeatCount="indefinite"/>
          </circle>
          <circle cx="50" cy="50" r="8" fill="green">
            <animate attributeName="cy" from="50" to="80" dur="1s" repeatCount="indefinite"/>
          </circle>
          <circle cx="80" cy="50" r="8" fill="blue">
            <animate attributeName="cy" from="50" to="20" dur="1s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Fill Color',
      subtitle: 'animate fill attribute',
      accentColor: Colors.red,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="25" y="25" width="50" height="50" fill="red">
            <animate attributeName="fill" from="#ff0000" to="#0000ff" dur="2s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Stroke Color',
      subtitle: 'animate stroke attribute',
      accentColor: Colors.lime,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="30" fill="none" stroke="#00ff00" stroke-width="4">
            <animate attributeName="stroke" from="#00ff00" to="#ff00ff" dur="3s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Color Keyframes',
      subtitle: 'multi-color animation',
      accentColor: Colors.pink,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="20" y="20" width="60" height="60" fill="#ff0000">
            <animate 
              attributeName="fill" 
              values="#ff0000;#00ff00;#0000ff;#ff0000" 
              keyTimes="0;0.33;0.66;1"
              dur="4s" 
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Combined Animation',
      subtitle: 'size + color',
      accentColor: Colors.tealAccent,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="15" fill="#ff6b6b">
            <animate attributeName="r" from="15" to="35" dur="2s" repeatCount="indefinite"/>
            <animate attributeName="fill" from="#ff6b6b" to="#4ecdc4" dur="2s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Rotation',
      subtitle: 'animateTransform rotate',
      accentColor: Colors.deepOrange,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="#ff6b6b">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Translation',
      subtitle: 'animateTransform translate',
      accentColor: Colors.cyan,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <circle cx="20" cy="50" r="10" fill="#4ecdc4">
            <animateTransform
              attributeName="transform"
              type="translate"
              from="0 0"
              to="60 0"
              dur="1.5s"
              repeatCount="indefinite"/>
          </circle>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Scale',
      subtitle: 'animateTransform scale',
      accentColor: Colors.deepPurple,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <g transform="translate(50, 50)">
            <rect x="-15" y="-15" width="30" height="30" fill="#9b59b6">
              <animateTransform
                attributeName="transform"
                type="scale"
                from="1"
                to="2"
                dur="1s"
                repeatCount="indefinite"/>
            </rect>
          </g>
        </svg>
      ''',
    ),
    _DemoExample(
      title: 'Combined Transform',
      subtitle: 'rotate + scale effect',
      accentColor: Colors.red,
      svgXml: '''
        <svg viewBox="0 0 100 100">
          <rect x="35" y="35" width="30" height="30" fill="#e74c3c">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="180 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final crossAxisCount = screenWidth > 1200
        ? 4
        : screenWidth > 900
        ? 3
        : screenWidth > 600
        ? 2
        : 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.animation,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SMIL Animation Examples',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_examples.length} interactive examples',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grid of examples
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: isMobile ? 12 : 16,
                crossAxisSpacing: isMobile ? 12 : 16,
                childAspectRatio: isMobile ? 0.9 : 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _ExampleCard(example: _examples[index], index: index),
                childCount: _examples.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example, required this.index});

  final _DemoExample example;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark
            ? BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with number and title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: example.accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
              border: Border(
                bottom: BorderSide(
                  color: example.accentColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: example.accentColor.withValues(
                      alpha: isDark ? 0.3 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: example.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        example.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        example.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // SVG Animation Display
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF1a1a1a) : Colors.grey.shade50,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedSvgPicture.string(
                    example.svgXml,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
