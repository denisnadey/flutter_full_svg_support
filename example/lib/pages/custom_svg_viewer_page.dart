import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/src/animation.dart';

/// Custom SVG Viewer - allows users to paste SVG code or provide URL
class CustomSvgViewerPage extends StatefulWidget {
  const CustomSvgViewerPage({super.key});

  @override
  State<CustomSvgViewerPage> createState() => _CustomSvgViewerPageState();
}

class _CustomSvgViewerPageState extends State<CustomSvgViewerPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _svgController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  late TabController _inputTabController;

  String? _currentSvg;
  String? _errorMessage;
  bool _isLoading = false;
  bool _autoPlay = true;
  double _playbackRate = 1.0;
  double _svgSize = 300.0;

  // Example SVG templates
  static const String _circleTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <circle cx="100" cy="100" r="40" fill="#FF5722">
    <animate attributeName="r" from="40" to="80" dur="2s" repeatCount="indefinite" />
  </circle>
</svg>''';

  static const String _rotatingSquareTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect x="75" y="75" width="50" height="50" fill="#2196F3">
    <animateTransform attributeName="transform" type="rotate"
      from="0 100 100" to="360 100 100" dur="3s" repeatCount="indefinite" />
  </rect>
</svg>''';

  static const String _pathMorphTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <path fill="#4CAF50">
    <animate attributeName="d" dur="4s" repeatCount="indefinite"
      values="M100,50 L150,150 L50,150 Z;
              M100,50 L175,100 L150,175 L50,175 L25,100 Z;
              M100,50 L150,150 L50,150 Z" />
  </path>
</svg>''';

  @override
  void initState() {
    super.initState();
    _inputTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _svgController.dispose();
    _urlController.dispose();
    _inputTabController.dispose();
    super.dispose();
  }

  void _loadSvgFromCode() {
    setState(() {
      _errorMessage = null;
      _currentSvg = _svgController.text.trim();
      if (_currentSvg!.isEmpty) {
        _errorMessage = 'Please enter SVG code';
        _currentSvg = null;
      }
    });
  }

  Future<void> _loadSvgFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Note: In production, you'd use http package to fetch the URL
      // For now, we'll just show how to use SvgPicture.network
      setState(() {
        _currentSvg = url; // Store URL for network loading
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading SVG: $e';
        _isLoading = false;
      });
    }
  }

  void _loadTemplate(String template) {
    _svgController.text = template;
    _loadSvgFromCode();
  }

  void _clearSvg() {
    setState(() {
      _currentSvg = null;
      _errorMessage = null;
      _svgController.clear();
      _urlController.clear();
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _svgController.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom SVG Viewer'),
        actions: [
          if (_currentSvg != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: _clearSvg,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Input Section
            Card(
              margin: EdgeInsets.all(isMobile ? 8 : 16),
              child: Column(
                children: [
                  TabBar(
                    controller: _inputTabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.code), text: 'SVG Code'),
                      Tab(icon: Icon(Icons.link), text: 'URL'),
                    ],
                  ),
                  SizedBox(
                    height: 200,
                    child: TabBarView(
                      controller: _inputTabController,
                      children: [
                        // SVG Code Input
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _svgController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: InputDecoration(
                                    hintText: 'Paste SVG code here...',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.paste),
                                      tooltip: 'Paste from clipboard',
                                      onPressed: _pasteFromClipboard,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _loadSvgFromCode,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Load SVG'),
                              ),
                            ],
                          ),
                        ),
                        // URL Input
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextField(
                                controller: _urlController,
                                decoration: const InputDecoration(
                                  hintText: 'https://example.com/image.svg',
                                  labelText: 'SVG URL',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.language),
                                ),
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _loadSvgFromUrl,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download),
                                label: Text(
                                  _isLoading ? 'Loading...' : 'Load from URL',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Templates Section
            if (!isMobile || _currentSvg == null)
              Card(
                margin: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 16,
                  vertical: 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Templates',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TemplateChip(
                            label: 'Pulsing Circle',
                            icon: Icons.circle,
                            onTap: () => _loadTemplate(_circleTemplate),
                          ),
                          _TemplateChip(
                            label: 'Rotating Square',
                            icon: Icons.crop_square,
                            onTap: () => _loadTemplate(_rotatingSquareTemplate),
                          ),
                          _TemplateChip(
                            label: 'Path Morph',
                            icon: Icons.change_history,
                            onTap: () => _loadTemplate(_pathMorphTemplate),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // SVG Display Section
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 8 : 16),
                  child: _buildSvgDisplay(isMobile),
                ),
              ),
            ),

            // Controls Panel (only when SVG is loaded)
            if (_currentSvg != null)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Size Slider
                      Row(
                        children: [
                          const Icon(Icons.photo_size_select_small, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: _svgSize,
                              min: 100,
                              max: 500,
                              divisions: 40,
                              label: '${_svgSize.toInt()}px',
                              onChanged: (value) {
                                setState(() {
                                  _svgSize = value;
                                });
                              },
                            ),
                          ),
                          const Icon(Icons.photo_size_select_large, size: 20),
                        ],
                      ),
                      // Animation Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _autoPlay,
                                onChanged: (value) {
                                  setState(() {
                                    _autoPlay = value;
                                  });
                                },
                              ),
                              Text(
                                'Auto Play',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Speed: ${_playbackRate}x',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              SizedBox(
                                width: 150,
                                child: Slider(
                                  value: _playbackRate,
                                  min: 0.25,
                                  max: 2.0,
                                  divisions: 7,
                                  label: '${_playbackRate}x',
                                  onChanged: (value) {
                                    setState(() {
                                      _playbackRate = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgDisplay(bool isMobile) {
    if (_errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentSvg == null) {
      return Card(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No SVG loaded',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste SVG code, enter URL, or use a template',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: _isLoading
            ? const CircularProgressIndicator()
            : _buildSvgWidget(),
      ),
    );
  }

  Widget _buildSvgWidget() {
    // Check if it's a URL or SVG code
    final isUrl =
        _currentSvg!.startsWith('http://') ||
        _currentSvg!.startsWith('https://');

    try {
      if (isUrl) {
        return SvgPicture.network(
          _currentSvg!,
          width: _svgSize,
          height: _svgSize,
          placeholderBuilder: (context) => const CircularProgressIndicator(),
          // ignore: deprecated_member_use_from_same_package
          // ignore: deprecated_member_use
          semanticsLabel: 'Custom SVG from URL',
        );
      } else {
        // Try to detect if SVG has animations
        final hasAnimations =
            _currentSvg!.contains('<animate') ||
            _currentSvg!.contains('<animateTransform') ||
            _currentSvg!.contains('<animateMotion');

        if (hasAnimations) {
          return AnimatedSvgPicture.string(
            _currentSvg!,
            width: _svgSize,
            height: _svgSize,
            autoPlay: _autoPlay,
            playbackRate: _playbackRate,
          );
        } else {
          return SvgPicture.string(
            _currentSvg!,
            width: _svgSize,
            height: _svgSize,
          );
        }
      }
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error rendering SVG',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
