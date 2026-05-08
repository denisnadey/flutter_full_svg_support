import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

/// Demonstrates SVG <script> + JS DOM bridge support.
class JsDemoPage extends StatelessWidget {
  const JsDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('JS Bridge Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Color Cycler'),
              Tab(text: 'Live Editor'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssetTab(),
            _LiveEditorTab(),
          ],
        ),
      ),
    );
  }
}

// ── Asset demo tab ────────────────────────────────────────────────────────────

class _AssetTab extends StatelessWidget {
  const _AssetTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AnimatedSvgPicture.asset(
                'assets/simple/js_interactive_demo.svg',
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'onclick + setInterval + window.load',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the green button to cycle colors (onclick). '
                'The card fades in via window.addEventListener("load"). '
                'The hint text blinks via setInterval. '
                'Reset button uses a separate onclick handler.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Live editor tab ───────────────────────────────────────────────────────────

class _LiveEditorTab extends StatefulWidget {
  const _LiveEditorTab();

  @override
  State<_LiveEditorTab> createState() => _LiveEditorTabState();
}

class _LiveEditorTabState extends State<_LiveEditorTab> {
  late final TextEditingController _textCtrl;
  String _rendered = _kDefaultSvg;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: _kDefaultSvg);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _run() => setState(() => _rendered = _textCtrl.text);

  void _copy() {
    Clipboard.setData(ClipboardData(text: _textCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSvgPicture.string(_rendered),
            ),
          ),
        ),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text('SVG source', style: theme.textTheme.labelMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy',
                      onPressed: _copy,
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _run,
                      child: const Text('Run'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Default source ────────────────────────────────────────────────────────────

const String _kDefaultSvg = r'''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <script type="text/javascript"><![CDATA[
    var hue = 0;
    window.addEventListener('load', function() {
      setInterval(function() {
        hue = (hue + 2) % 360;
        var c = document.getElementById('c');
        var r = document.getElementById('r');
        if (c) c.setAttribute('fill', 'hsl(' + hue + ',70%,55%)');
        if (r) r.setAttribute('fill', 'hsl(' + ((hue + 180) % 360) + ',70%,55%)');
      }, 30);
    });
  ]]></script>

  <rect id="r" x="20" y="20" width="80" height="80" rx="8" fill="#4CAF50"/>
  <circle id="c" cx="140" cy="120" r="40" fill="#2196F3"/>
  <text x="100" y="185" text-anchor="middle"
        font-family="sans-serif" font-size="12" fill="#888">
    hsl() color loop via setInterval
  </text>
</svg>
''';
