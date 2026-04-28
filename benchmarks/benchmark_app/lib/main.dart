import 'dart:convert';

import 'package:flutter/material.dart';

import 'result_models.dart';
import 'screens/animated_svg_benchmark_screen.dart';
import 'screens/compatibility_gallery_screen.dart';
import 'screens/filter_stress_benchmark_screen.dart';
import 'screens/mega_stress_benchmark_screen.dart';
import 'screens/scroll_stress_benchmark_screen.dart';
import 'screens/static_grid_benchmark_screen.dart';
import 'screens/static_single_svg_benchmark_screen.dart';
import 'screens/text_svg_benchmark_screen.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVG Benchmark Suite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BenchmarkHomeScreen(),
      onGenerateRoute: _generateRoute,
    );
  }

  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/static_single':
        return MaterialPageRoute(
          builder: (_) => const StaticSingleSvgBenchmarkScreen(),
        );
      case '/static_grid':
        return MaterialPageRoute(
          builder: (_) => const StaticGridBenchmarkScreen(),
        );
      case '/animated':
        return MaterialPageRoute(
          builder: (_) => const AnimatedSvgBenchmarkScreen(),
        );
      case '/scroll_stress':
        return MaterialPageRoute(
          builder: (_) => const ScrollStressBenchmarkScreen(),
        );
      case '/filter_stress':
        return MaterialPageRoute(
          builder: (_) => const FilterStressBenchmarkScreen(),
        );
      case '/text_svg':
        return MaterialPageRoute(
          builder: (_) => const TextSvgBenchmarkScreen(),
        );
      case '/compatibility':
        return MaterialPageRoute(
          builder: (_) => const CompatibilityGalleryScreen(),
        );
      case '/mega_stress':
        return MaterialPageRoute(
          builder: (_) => const MegaStressBenchmarkScreen(),
        );
      case '/benchmark_results':
        final results = settings.arguments as List<BenchmarkMetrics>?;
        return MaterialPageRoute(
          builder: (_) => BenchmarkResultsScreen(results: results ?? []),
        );
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class BenchmarkHomeScreen extends StatelessWidget {
  const BenchmarkHomeScreen({super.key});

  static const List<_NavEntry> _entries = [
    _NavEntry(
      title: 'Static Single SVG',
      subtitle: 'picture vs raster vs flutter_svg — single widget',
      route: '/static_single',
      icon: Icons.image_outlined,
    ),
    _NavEntry(
      title: 'Static Grid',
      subtitle: '100–500 SVG tiles, cache hit / miss scenarios',
      route: '/static_grid',
      icon: Icons.grid_view,
    ),
    _NavEntry(
      title: 'Animated SVG',
      subtitle: 'SMIL / CSS animations (full_svg_flutter only)',
      route: '/animated',
      icon: Icons.animation,
    ),
    _NavEntry(
      title: 'Scroll Stress',
      subtitle: '200-item ListView scroll benchmark',
      route: '/scroll_stress',
      icon: Icons.swap_vert,
    ),
    _NavEntry(
      title: 'Filter Stress',
      subtitle: 'feGaussianBlur, feColorMatrix, composites',
      route: '/filter_stress',
      icon: Icons.blur_on,
    ),
    _NavEntry(
      title: 'Text SVG',
      subtitle: 'textPath and complex text rendering',
      route: '/text_svg',
      icon: Icons.text_fields,
    ),
    _NavEntry(
      title: 'Compatibility Gallery',
      subtitle: 'Side-by-side: features unsupported by flutter_svg',
      route: '/compatibility',
      icon: Icons.compare,
    ),
    _NavEntry(
      title: 'Galactic Storm — Mega Stress',
      subtitle: '2,300+ elements · SMIL · CSS · morph · motion · filters · text',
      route: '/mega_stress',
      icon: Icons.auto_awesome,
    ),
    _NavEntry(
      title: 'All Results (JSON)',
      subtitle: 'View combined benchmark output',
      route: '/benchmark_results',
      icon: Icons.data_object,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVG Benchmark Suite'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ListTile(
            leading: Icon(entry.icon),
            title: Text(entry.title),
            subtitle: Text(entry.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(entry.route),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results screen
// ---------------------------------------------------------------------------

/// Displays the combined JSON dump of all benchmark results.
class BenchmarkResultsScreen extends StatelessWidget {
  const BenchmarkResultsScreen({super.key, required this.results});

  final List<BenchmarkMetrics> results;

  @override
  Widget build(BuildContext context) {
    final encoder = const JsonEncoder.withIndent('  ');
    final jsonText = results.isEmpty
        ? '// No results yet. Run benchmarks from integration_test first.'
        : encoder.convert(results.map((r) => r.toJson()).toList());

    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          jsonText,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _NavEntry {
  const _NavEntry({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}
