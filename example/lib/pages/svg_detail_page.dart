import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/svg_animations.dart';
import '../widgets/svg_gallery_card.dart'; // for shared svgNetworkCache
import 'svg_debug_viewer_page.dart';

class SvgDetailPage extends StatefulWidget {
  const SvgDetailPage({super.key, required this.item});
  final SvgAnimationItem item;

  @override
  State<SvgDetailPage> createState() => _SvgDetailPageState();
}

class _SvgDetailPageState extends State<SvgDetailPage> {
  String? _svg;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = svgNetworkCache[widget.item.url];
    if (cached != null) {
      if (mounted) setState(() { _svg = cached; _loading = false; });
      return;
    }
    try {
      final res = await http.get(Uri.parse(widget.item.url));
      if (!mounted) return;
      if (res.statusCode == 200) {
        svgNetworkCache[widget.item.url] = res.body;
        setState(() { _svg = res.body; _loading = false; });
      } else {
        setState(() { _error = 'HTTP ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.item.category;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          widget.item.title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(cat.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: cat.color.withOpacity(0.85),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              avatar: Icon(cat.icon, size: 14, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_rounded, size: 20),
            tooltip: 'Open in Debug viewer (scrubber + layer tree + JSON)',
            color: Colors.amberAccent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SvgDebugViewerPage(item: widget.item),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy URL',
            color: Colors.white54,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.item.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.item.category.color),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 56, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: widget.item.category.color.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: widget.item.category.color.withOpacity(0.15),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSvgPicture.string(
              _svg!,
              width: 800,
              height: 700,
            ),
          ),
        ),
      ),
    );
  }
}
