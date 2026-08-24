import 'dart:async';

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_debug_protocol.dart';

import 'devtools_transport.dart';
import 'full_svg_inspector_controller.dart';

class FullSvgExtension extends StatefulWidget {
  const FullSvgExtension({super.key});

  @override
  State<FullSvgExtension> createState() => _FullSvgExtensionState();
}

class _FullSvgExtensionState extends State<FullSvgExtension> {
  late final DevToolsFullSvgTransport _transport;
  late final FullSvgInspectorController _controller;

  @override
  void initState() {
    super.initState();
    _transport = DevToolsFullSvgTransport();
    _controller = FullSvgInspectorController(transport: _transport);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FullSvgInspectorView(controller: _controller);
  }
}

class FullSvgInspectorView extends StatelessWidget {
  const FullSvgInspectorView({super.key, required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: <Widget>[
              _InspectorHeader(controller: controller),
              if (controller.errorMessage != null &&
                  controller.status == FullSvgInspectorStatus.ready)
                _InlineError(
                  message: controller.errorMessage!,
                  onRetry: controller.refreshInstances,
                ),
              Expanded(child: _body(context)),
              if (controller.selectedInstance?.animated ?? false)
                _PlaybackToolbar(controller: controller),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    return switch (controller.status) {
      FullSvgInspectorStatus.connecting => _StatusView(
        icon: Icons.sync,
        title: controller.errorMessage ?? 'Connecting to FullSVG runtime…',
        showProgress: true,
      ),
      FullSvgInspectorStatus.disconnected => const _StatusView(
        icon: Icons.link_off,
        title: 'No Flutter application connected.',
        message: 'Start or attach to a Flutter application to inspect SVGs.',
      ),
      FullSvgInspectorStatus.unavailable => _StatusView(
        icon: Icons.extension_off_outlined,
        title: 'FullSVG debugging is unavailable.',
        message:
            'The connected application does not expose the FullSVG runtime bridge. '
            'Make sure it uses a debug build of full_svg_flutter.',
        action: FilledButton.icon(
          onPressed: controller.retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
      FullSvgInspectorStatus.empty => _StatusView(
        icon: Icons.account_tree_outlined,
        title: 'No mounted FullSVG instances.',
        message: 'SVG renderers will appear here when they are mounted.',
        action: OutlinedButton.icon(
          onPressed: controller.refreshInstances,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      FullSvgInspectorStatus.error => _StatusView(
        icon: Icons.error_outline,
        title: 'Could not load the FullSVG inspector.',
        message: controller.errorMessage,
        action: FilledButton.icon(
          onPressed: controller.retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
      FullSvgInspectorStatus.ready => _InspectorWorkspace(
        controller: controller,
      ),
    };
  }
}

class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.transport.connected;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.polyline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text('FullSVG', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(connected ? 'Connected • main isolate' : 'Disconnected'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh instances',
            onPressed: connected ? controller.refreshInstances : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      leading: const Icon(Icons.warning_amber),
      actions: <Widget>[
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 44,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (showProgress) ...<Widget>[
                const SizedBox(height: 20),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorWorkspace extends StatelessWidget {
  const _InspectorWorkspace({required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return DefaultTabController(
            length: 3,
            child: Column(
              children: <Widget>[
                const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Instances'),
                    Tab(text: 'SVG DOM'),
                    Tab(text: 'Properties'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _InstancePanel(controller: controller),
                      _TreePanel(controller: controller),
                      _PropertiesPanel(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final sidebarWidth = constraints.maxWidth < 1000 ? 190.0 : 240.0;
        final propertiesWidth = constraints.maxWidth < 1000 ? 280.0 : 340.0;
        return Row(
          children: <Widget>[
            SizedBox(
              width: sidebarWidth,
              child: _InstancePanel(controller: controller),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _TreePanel(controller: controller)),
            const VerticalDivider(width: 1),
            SizedBox(
              width: propertiesWidth,
              child: _PropertiesPanel(controller: controller),
            ),
          ],
        );
      },
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InstancePanel extends StatelessWidget {
  const _InstancePanel({required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelTitle(
          'SVG Instances',
          trailing: Text('${controller.instances.length}'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: controller.instances.length,
            itemBuilder: (context, index) {
              final instance = controller.instances[index];
              final selected =
                  instance.instanceId ==
                  controller.selectedInstance?.instanceId;
              return Material(
                color: selected
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => controller.selectInstance(instance.instanceId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _sourceName(instance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${instance.animated ? 'Animated' : 'Static'} • '
                          '${instance.nodeCount} nodes',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _sourceName(SvgDebugInstanceSummary instance) {
    final label = instance.sourceLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return switch (instance.sourceType) {
      'network' => 'Network SVG',
      'string' => 'Inline SVG',
      'memory' => 'Memory SVG',
      _ => 'SVG instance ${instance.instanceId}',
    };
  }
}

class _TreePanel extends StatelessWidget {
  const _TreePanel({required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    final root = controller.rootNode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PanelTitle('SVG DOM'),
        Expanded(
          child: root == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: <Widget>[
                    _TreeNode(
                      key: ValueKey<String>(root.nodeId),
                      node: root,
                      depth: 0,
                      controller: controller,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TreeNode extends StatefulWidget {
  const _TreeNode({
    super.key,
    required this.node,
    required this.depth,
    required this.controller,
  });

  final SvgDebugNodeSummary node;
  final int depth;
  final FullSvgInspectorController controller;

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final controller = widget.controller;
    final children = controller.childrenByNode[node.nodeId];
    final loading = controller.loadingNodeIds.contains(node.nodeId);
    final selected = controller.selectedNode?.summary.nodeId == node.nodeId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          child: InkWell(
            onTap: () => controller.selectNode(node),
            child: SizedBox(
              height: 32,
              child: Row(
                children: <Widget>[
                  SizedBox(width: 8.0 + widget.depth * 16),
                  SizedBox(
                    width: 26,
                    child: node.childCount == 0
                        ? const SizedBox.shrink()
                        : loading
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            tooltip: expanded ? 'Collapse' : 'Load children',
                            onPressed: () {
                              setState(() => expanded = !expanded);
                              if (expanded) {
                                unawaited(controller.loadChildren(node));
                              }
                            },
                            icon: Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 18,
                            ),
                          ),
                  ),
                  Icon(
                    node.animated ? Icons.animation : Icons.code,
                    size: 14,
                    color: node.animated
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _nodeLabel(node),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (node.childCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '${node.childCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (expanded && children != null)
          for (final child in children)
            _TreeNode(
              key: ValueKey<String>(child.nodeId),
              node: child,
              depth: widget.depth + 1,
              controller: controller,
            ),
      ],
    );
  }

  String _nodeLabel(SvgDebugNodeSummary node) {
    final buffer = StringBuffer(node.tagName);
    if (node.svgId != null) buffer.write('#${node.svgId}');
    for (final className in node.classes) {
      buffer.write('.$className');
    }
    return buffer.toString();
  }
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.controller});

  final FullSvgInspectorController controller;

  @override
  Widget build(BuildContext context) {
    final details = controller.selectedNode;
    final instance = controller.selectedInstance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelTitle(
          'Properties',
          trailing: details == null
              ? null
              : IconButton(
                  tooltip: 'Clear selection highlight',
                  onPressed: controller.clearHighlight,
                  icon: const Icon(Icons.highlight_off, size: 18),
                ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              if (instance != null) ...<Widget>[
                _SectionTitle('Instance'),
                _PropertyRow('Runtime ID', instance.instanceId),
                _PropertyRow('Source', instance.sourceLabel ?? '—'),
                _PropertyRow('Source type', instance.sourceType ?? '—'),
                _PropertyRow(
                  'Dimensions',
                  '${_formatDimension(instance.width)} × '
                      '${_formatDimension(instance.height)}',
                ),
                _PropertyRow('Animated', instance.animated ? 'Yes' : 'No'),
                if (instance.animated)
                  _PropertyRow(
                    'Playback',
                    '${instance.playing ? 'Playing' : 'Paused'} • '
                        '${instance.playbackRate}x',
                  ),
                if (controller.stats != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _StatsSection(stats: controller.stats!),
                ],
                const Divider(height: 28),
              ],
              if (details == null) ...<Widget>[
                const _SectionTitle('Select a DOM node'),
                Text(
                  'Its attributes and animations will appear here.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...<Widget>[
                _SectionTitle('Element'),
                _PropertyRow('Tag', details.summary.tagName),
                _PropertyRow('SVG id', details.summary.svgId ?? '—'),
                _PropertyRow(
                  'Classes',
                  details.summary.classes.isEmpty
                      ? '—'
                      : details.summary.classes.join(' '),
                ),
                _PropertyRow('Debug node ID', details.summary.nodeId),
                _PropertyRow('Children', '${details.summary.childCount}'),
                const SizedBox(height: 16),
                _SectionTitle('Attributes (${details.attributes.length})'),
                if (details.attributes.isEmpty)
                  const Text('No attributes')
                else
                  for (final attribute in details.attributes)
                    _AttributeRow(attribute: attribute),
                const SizedBox(height: 16),
                _SectionTitle('Animation'),
                _PropertyRow(
                  'Animated',
                  details.animations.isEmpty ? 'No' : 'Yes',
                ),
                _PropertyRow('Animation count', '${details.animations.length}'),
                for (final animation in details.animations)
                  Card.outlined(
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${animation.type} • ${animation.attributeName}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_formatTime(animation.durationMs)} • '
                            'repeat ${animation.repeatCount} • '
                            '${animation.active ? 'active' : 'inactive'}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.attribute});

  final SvgDebugAttribute attribute;

  @override
  Widget build(BuildContext context) {
    final long = attribute.resolvedValue.length > 80;
    final raw = attribute.rawValue;
    final rawDiffers = raw != null && raw != attribute.resolvedValue;
    final value = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectableText(
          attribute.resolvedValue,
          maxLines: long ? null : 2,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        if (rawDiffers)
          SelectableText(
            'raw: $raw',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    attribute.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: attribute.animated
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (attribute.animated)
                  const Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: Icon(Icons.animation, size: 12),
                  ),
              ],
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final SvgDebugStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionTitle('Stats'),
        _PropertyRow('DOM nodes', '${stats.domNodes}'),
        _PropertyRow('Animations', '${stats.animationCount}'),
        _PropertyRow('Active', '${stats.activeAnimationCount}'),
        _PropertyRow('Filters', '${stats.filterPrimitiveCount}'),
        _PropertyRow('Masks', '${stats.maskCount}'),
        _PropertyRow('Gradients', '${stats.gradientCount}'),
        _PropertyRow('Clip paths', '${stats.clipPathCount}'),
        _PropertyRow('JavaScript', stats.javaScriptEnabled ? 'Enabled' : 'No'),
      ],
    );
  }
}

class _PlaybackToolbar extends StatefulWidget {
  const _PlaybackToolbar({required this.controller});

  final FullSvgInspectorController controller;

  @override
  State<_PlaybackToolbar> createState() => _PlaybackToolbarState();
}

class _PlaybackToolbarState extends State<_PlaybackToolbar> {
  double? _dragValue;
  Timer? _seekDebounce;

  @override
  void dispose() {
    _seekDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instance = widget.controller.selectedInstance!;
    final duration = (instance.durationMs ?? 0).toDouble();
    final current = _dragValue ?? (instance.currentTimeMs ?? 0).toDouble();
    final safeDuration = duration <= 0 ? 1.0 : duration;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: instance.playing ? 'Pause' : 'Play',
            onPressed: widget.controller.togglePlayback,
            icon: Icon(instance.playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Restart',
            onPressed: widget.controller.restart,
            icon: const Icon(Icons.replay),
          ),
          SizedBox(
            width: 70,
            child: Text(_formatTime(current.round()), textAlign: TextAlign.end),
          ),
          Expanded(
            child: Slider(
              value: current.clamp(0, safeDuration),
              max: safeDuration,
              onChanged: duration <= 0
                  ? null
                  : (value) {
                      setState(() => _dragValue = value);
                      _seekDebounce?.cancel();
                      _seekDebounce = Timer(
                        const Duration(milliseconds: 100),
                        () => widget.controller.seek(value),
                      );
                    },
              onChangeEnd: duration <= 0
                  ? null
                  : (value) {
                      _seekDebounce?.cancel();
                      unawaited(widget.controller.seek(value));
                      setState(() => _dragValue = null);
                    },
            ),
          ),
          SizedBox(width: 70, child: Text(_formatTime(duration.round()))),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Playback speed',
            child: DropdownButton<double>(
              value: _nearestRate(instance.playbackRate),
              underline: const SizedBox.shrink(),
              items: const <double>[0.25, 0.5, 1, 1.5, 2]
                  .map(
                    (rate) => DropdownMenuItem<double>(
                      value: rate,
                      child: Text('${rate}x'),
                    ),
                  )
                  .toList(),
              onChanged: (rate) {
                if (rate != null) widget.controller.setPlaybackRate(rate);
              },
            ),
          ),
        ],
      ),
    );
  }

  double _nearestRate(double rate) {
    const rates = <double>[0.25, 0.5, 1, 1.5, 2];
    return rates.reduce(
      (left, right) =>
          (left - rate).abs() < (right - rate).abs() ? left : right,
    );
  }
}

String _formatTime(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis = duration.inMilliseconds
      .remainder(1000)
      .toString()
      .padLeft(3, '0');
  return '$minutes:$seconds.$millis';
}

String _formatDimension(double? value) {
  if (value == null) return '—';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
