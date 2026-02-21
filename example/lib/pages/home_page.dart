import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../main.dart';
import 'unified_examples_page.dart';
import 'examples_page.dart';
import 'custom_svg_viewer_page.dart';
import 'controller_demo_page.dart';

/// The SVG to display on home page
const String svgString = '''
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
  <defs>
    <linearGradient id="triangleGradient">
      <stop offset="20%" stop-color="#000000" stop-opacity=".55" />
      <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
    </linearGradient>
    <linearGradient id="rectangleGradient" x1="0%" x2="0%" y1="0%" y2="100%">
      <stop offset="20%" stop-color="#000000" stop-opacity=".15" />
      <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
    </linearGradient>
  </defs>
  <path fill="#42A5F5" fill-opacity=".8" d="M37.7 128.9 9.8 101 100.4 10.4 156.2 10.4" />
  <path fill="#42A5F5" fill-opacity=".8" d="M156.2 94 100.4 94 79.5 114.9 107.4 142.8" />
  <path fill="#0D47A1" d="M79.5 170.7 100.4 191.6 156.2 191.6 156.2 191.6 107.4 142.8" />
  <g transform="matrix(0.7071, -0.7071, 0.7071, 0.7071, -77.667, 98.057)">
    <rect width="39.4" height="39.4" x="59.8" y="123.1" fill="#42A5F5" />
    <rect width="39.4" height="5.5" x="59.8" y="162.5" fill="url(#rectangleGradient)" />
  </g>
  <path d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>
''';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter SVG Animations')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Logo
            Hero(
              tag: 'flutter_logo',
              child: SvgPicture.string(
                svgString,
                width: isMobile ? 150 : 200,
                height: isMobile ? 150 : 200,
              ),
            ),
            SizedBox(height: isMobile ? 24 : 32),

            // Title
            Text(
              'SMIL Animation Examples',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 20 : null,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Subtitle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 24),
              child: Text(
                'Explore animated SVG with SMIL support in Flutter',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isMobile ? 14 : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),

            // Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Wrap(
                  spacing: isMobile ? 12 : 16,
                  runSpacing: isMobile ? 12 : 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildNavigationCard(
                      context,
                      title: 'Gallery',
                      icon: Icons.grid_view,
                      color: Colors.green,
                      isMobile: isMobile,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListenableBuilder(
                              listenable: appState,
                              builder: (context, _) =>
                                  ExamplesPage(state: appState),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildNavigationCard(
                      context,
                      title: 'Unified Examples',
                      icon: Icons.animation,
                      color: Colors.blue,
                      isMobile: isMobile,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UnifiedExamplesPage(),
                          ),
                        );
                      },
                    ),
                    _buildNavigationCard(
                      context,
                      title: 'SVG Playground',
                      icon: Icons.code,
                      color: Colors.deepPurple,
                      isMobile: isMobile,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomSvgViewerPage(),
                          ),
                        );
                      },
                    ),
                    _buildNavigationCard(
                      context,
                      title: 'Controller Demo',
                      icon: Icons.control_camera,
                      color: Colors.orange,
                      isMobile: isMobile,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ControllerDemoPage(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Features',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFeature('✓ SMIL Animations'),
                    _buildFeature(
                      '✓ Transform Animations (rotate, translate, scale, skew, matrix)',
                    ),
                    _buildFeature('✓ Path Morphing (shape interpolation)'),
                    _buildFeature('✓ Color Animations'),
                    _buildFeature('✓ Real-time FPS Monitoring'),
                    _buildFeature('✓ Detailed Performance Metrics'),
                    _buildFeature('✓ Unified Design System'),
                    _buildFeature('✓ Tab-based Navigation'),
                    _buildFeature('✓ Multilingual Support (English/Russian)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    final cardWidth = isMobile ? 160.0 : 200.0;
    final iconSize = isMobile ? 40.0 : 48.0;
    final padding = isMobile ? 16.0 : 24.0;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: color),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
