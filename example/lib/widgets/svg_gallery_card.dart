import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/svg_animations.dart';

// Shared in-memory cache – persists for the session
final svgNetworkCache = <String, String>{};

enum _State { idle, loading, playing, error }

class SvgGalleryCard extends StatefulWidget {
  const SvgGalleryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final SvgAnimationItem item;
  final VoidCallback onTap;

  @override
  State<SvgGalleryCard> createState() => _SvgGalleryCardState();
}

class _SvgGalleryCardState extends State<SvgGalleryCard> {
  _State _state = _State.idle;
  String? _svg;
  bool _hovered = false;
  // Incremented on every state transition so AnimatedSwitcher never sees duplicate keys
  // (it keeps both outgoing and incoming children alive during the 250ms fade).
  int _gen = 0;

  void _setState(_State next, {String? svg}) {
    if (!mounted) return;
    setState(() {
      _state = next;
      if (svg != null) _svg = svg;
      _gen++;
    });
  }

  void _onEnter(PointerEvent _) {
    if (!mounted) return;
    setState(() => _hovered = true);
    final cached = svgNetworkCache[widget.item.url];
    if (cached != null) {
      _setState(_State.playing, svg: cached);
    } else {
      _setState(_State.loading);
      _fetch();
    }
  }

  void _onExit(PointerEvent _) {
    if (!mounted) return;
    setState(() => _hovered = false);
    _setState(_State.idle);
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse(widget.item.url));
      if (!mounted || !_hovered) return;
      if (res.statusCode == 200) {
        svgNetworkCache[widget.item.url] = res.body;
        _setState(_State.playing, svg: res.body);
      } else {
        _setState(_State.error);
      }
    } catch (_) {
      if (mounted) _setState(_State.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.item.category;
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? cat.color : Colors.transparent,
              width: 2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: cat.color.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackground(cat),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildContent(),
                  ),
                  _buildOverlay(cat),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(SvgCategory cat) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cat.color.withOpacity(0.15),
            cat.color.withOpacity(0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _State.playing:
        return LayoutBuilder(
          key: ValueKey('playing-$_gen'),
          builder: (ctx, constraints) => AnimatedSvgPicture.string(
            _svg!,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        );
      case _State.loading:
        return Center(
          key: ValueKey('loading-$_gen'),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.item.category.color,
            ),
          ),
        );
      case _State.error:
        return Center(
          key: ValueKey('error-$_gen'),
          child: Icon(Icons.broken_image_outlined,
              size: 36, color: Colors.white.withOpacity(0.3)),
        );
      case _State.idle:
        return Center(
          key: ValueKey('idle-$_gen'),
          child: Icon(
            widget.item.category.icon,
            size: 48,
            color: widget.item.category.color.withOpacity(0.4),
          ),
        );
    }
  }

  Widget _buildOverlay(SvgCategory cat) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(_hovered ? 0.72 : 0.55),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                cat.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
