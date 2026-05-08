import 'package:flutter/material.dart';

import '../data/svg_animations.dart';
import '../pages/svg_detail_page.dart';
import '../widgets/svg_gallery_card.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  SvgCategory? _filter; // null = all

  List<SvgAnimationItem> get _items => _filter == null
      ? kAllAnimations
      : kAllAnimations.where((a) => a.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E12),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            children: [
              const TextSpan(text: 'SVG '),
              TextSpan(
                text: 'Animation Gallery',
                style: TextStyle(
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF7C6FFF), Color(0xFF00E5CC)],
                    ).createShader(const Rect.fromLTWH(0, 0, 260, 24)),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildFilterRow(),
        ),
      ),
      body: _buildGrid(),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: 'All (${kAllAnimations.length})',
            selected: _filter == null,
            color: const Color(0xFF7C6FFF),
            onTap: () => setState(() => _filter = null),
          ),
          const SizedBox(width: 6),
          ...SvgCategory.values.map((cat) {
            final count = kAllAnimations.where((a) => a.category == cat).length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: '${cat.label} ($count)',
                selected: _filter == cat,
                color: cat.color,
                onTap: () => setState(() => _filter = _filter == cat ? null : cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = _items;
    if (items.isEmpty) {
      return Center(
        child: Text('No animations in this category',
            style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = (constraints.maxWidth / 240).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 4 / 3,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            return SvgGalleryCard(
              key: ValueKey(item.url),
              item: item,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SvgDetailPage(item: item),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
