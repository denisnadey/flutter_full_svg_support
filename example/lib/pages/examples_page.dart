import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../data/examples_data.dart';
import '../models/svg_example.dart';
import '../widgets/animated_svg_viewer.dart';
import '../widgets/parameters_panel.dart';
import '../widgets/fps_monitor.dart';

/// Главная страница примеров
class ExamplesPage extends StatefulWidget {
  final AppState state;

  const ExamplesPage({super.key, required this.state});

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  String _searchQuery = '';

  List<SvgExample> get _filteredExamples {
    if (_searchQuery.isEmpty) {
      return ExamplesData.all;
    }

    final query = _searchQuery.toLowerCase();
    return ExamplesData.all.where((example) {
      return example.title.toLowerCase().contains(query) ||
          example.description.toLowerCase().contains(query) ||
          example.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter SVG Animations'),
        actions: [
          IconButton(
            icon: Icon(
              widget.state.showFPS ? Icons.speed : Icons.speed_outlined,
            ),
            tooltip: widget.state.showFPS ? 'Hide FPS' : 'Show FPS',
            onPressed: widget.state.toggleFPS,
          ),
          IconButton(
            icon: Icon(
              widget.state.showParameters
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            tooltip: widget.state.showParameters
                ? 'Hide Parameters'
                : 'Show Parameters',
            onPressed: widget.state.toggleParameters,
          ),
        ],
      ),
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar with examples list
        SizedBox(width: 280, child: _buildExamplesList()),
        // Main content area
        Expanded(child: _buildMainContent()),
        // Parameters panel
        if (widget.state.showParameters)
          SizedBox(width: 320, child: ParametersPanel(state: widget.state)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          children: [
            // Examples selector (horizontal scroll)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainer
                    : Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              child: _buildExamplesHorizontalList(),
            ),
            // Main content
            Expanded(child: _buildMainContent()),
            // Parameters panel (collapsible)
            if (widget.state.showParameters)
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ParametersPanel(state: widget.state),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExamplesList() {
    final categories = ExamplesData.categories;

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer
                : Colors.grey.shade50,
            border: Border(
              right: BorderSide(
                color: isDark
                    ? theme.colorScheme.outline
                    : Colors.grey.shade300,
              ),
            ),
          ),
          child: Column(
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search examples...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              // Search results count
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    '${_filteredExamples.length} result${_filteredExamples.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Examples list
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildCategorizedList(categories)
                    : _buildSearchResults(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorizedList(List<String> categories) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        final examples = ExamplesData.getByCategory(category);

        return ExpansionTile(
          title: Text(category),
          initiallyExpanded: categoryIndex == 0,
          children: examples.map((example) {
            final globalIndex = ExamplesData.all.indexOf(example);
            final isSelected = widget.state.selectedExampleIndex == globalIndex;

            return ListTile(
              selected: isSelected,
              leading: Icon(example.icon, size: 20),
              title: Text(example.title, style: const TextStyle(fontSize: 13)),
              dense: true,
              onTap: () => widget.state.setSelectedExample(globalIndex),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _filteredExamples.length,
      itemBuilder: (context, index) {
        final example = _filteredExamples[index];
        final globalIndex = ExamplesData.all.indexOf(example);
        final isSelected = widget.state.selectedExampleIndex == globalIndex;

        return ListTile(
          selected: isSelected,
          leading: Icon(example.icon, size: 20),
          title: Text(example.title, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            example.category.toString().split('.').last,
            style: const TextStyle(fontSize: 11),
          ),
          dense: true,
          onTap: () => widget.state.setSelectedExample(globalIndex),
        );
      },
    );
  }

  Widget _buildExamplesHorizontalList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: ExamplesData.all.length,
      itemBuilder: (context, index) {
        final example = ExamplesData.all[index];
        final isSelected = widget.state.selectedExampleIndex == index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(example.icon, size: 24),
                const SizedBox(height: 4),
                Text(example.title, style: const TextStyle(fontSize: 10)),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => widget.state.setSelectedExample(index),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    final example = ExamplesData.all[widget.state.selectedExampleIndex];

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Stack(
          children: [
            Column(
              children: [
                // Example info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? theme.colorScheme.outline
                            : Colors.blue.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        example.icon,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              example.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              example.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: example.tags.map((tag) {
                                return Chip(
                                  label: Text(tag),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      // View Code Button
                      IconButton(
                        icon: const Icon(Icons.code),
                        tooltip: 'View SVG Code',
                        onPressed: () => _showCodeDialog(
                          context,
                          example.title,
                          example.svgContent,
                        ),
                      ),
                    ],
                  ),
                ),
                // SVG viewer
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedSvgViewer(
                        exampleId: example.id,
                        svgContent: example.svgContent,
                        state: widget.state,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // FPS Monitor
            if (widget.state.showFPS)
              const Positioned(top: 16, right: 16, child: FPSMonitor()),
          ],
        );
      },
    );
  }
}

void _showCodeDialog(BuildContext context, String title, String svgContent) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.code,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Code view
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  svgContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            // Footer with copy button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy to Clipboard'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: svgContent));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SVG code copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
