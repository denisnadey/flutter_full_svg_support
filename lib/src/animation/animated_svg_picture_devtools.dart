part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureDevToolsLifecycle on _AnimatedSvgPictureState {
  void _registerWithFullSvgDevTools() {
    assert(() {
      final adapter = _AnimatedSvgDebugAdapter(this);
      FullSvgDebugRegistry.instance.register(adapter);
      _debugAdapter = adapter;
      return true;
    }());
  }

  void _unregisterFromFullSvgDevTools() {
    assert(() {
      final adapter = _debugAdapter;
      if (adapter != null && adapter.debugInstanceId.isNotEmpty) {
        FullSvgDebugRegistry.instance.unregister(adapter.debugInstanceId);
      }
      _debugAdapter = null;
      return true;
    }());
  }

  void _debugPlayAnimation() {
    final timeline = _timeline;
    if (timeline == null) return;
    _ensureDebugAnimationController(timeline);
    _startPlayback();
  }

  void _ensureDebugAnimationController(SvgTimeline timeline) {
    if (_controller != null) return;
    final rate = timeline.playbackRate;
    final durationMicros = (timeline.totalDuration.inMicroseconds / rate)
        .round()
        .clamp(1, 0x7fffffffffffffff);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: durationMicros),
    );
    final totalMicros = timeline.totalDuration.inMicroseconds;
    if (totalMicros > 0) {
      _controller!.value = timeline.currentTime.inMicroseconds / totalMicros;
    }
    _controller!.addListener(_onAnimationTick);
  }

  void _debugPauseAnimation() {
    _controller?.stop();
  }

  void _debugSeekAnimation(Duration position) {
    final timeline = _timeline;
    if (timeline == null) return;
    timeline.seek(position);
    final controller = _controller;
    final totalMicros = timeline.totalDuration.inMicroseconds;
    if (controller != null && totalMicros > 0) {
      final wasAnimating = controller.isAnimating;
      controller.value = timeline.currentTime.inMicroseconds / totalMicros;
      if (!wasAnimating) controller.stop();
    }
    _markNeedsRepaint();
  }

  void _debugSetAnimationRate(double rate) {
    final timeline = _timeline;
    if (timeline == null) return;
    final controller = _controller;
    final wasAnimating = controller?.isAnimating ?? false;
    final currentProgress =
        controller?.value ??
        (timeline.totalDuration.inMicroseconds == 0
            ? 0.0
            : timeline.currentTime.inMicroseconds /
                  timeline.totalDuration.inMicroseconds);
    timeline.playbackRate = rate;
    if (controller != null) {
      controller.stop();
      controller.duration = Duration(
        microseconds: (timeline.totalDuration.inMicroseconds / rate)
            .round()
            .clamp(1, 0x7fffffffffffffff),
      );
      controller.value = currentProgress.clamp(0.0, 1.0);
      if (wasAnimating) _startPlayback();
    }
  }
}

class _AnimatedSvgDebugAdapter implements FullSvgDebugInspectable {
  _AnimatedSvgDebugAdapter(this.state) {
    var ordinal = 1;
    void index(SvgNode node) {
      final id = 'n${ordinal++}';
      _nodeToId[node] = id;
      _idToNode[id] = node;
      for (final child in node.children) {
        index(child);
      }
    }

    index(state._document.root);
    _maskCount = _countTag('mask');
    _clipPathCount = _countTag('clipPath');
    _gradientCount = _countTag('linearGradient') + _countTag('radialGradient');
  }

  final _AnimatedSvgPictureState state;
  final Map<SvgNode, String> _nodeToId = Map<SvgNode, String>.identity();
  final Map<String, SvgNode> _idToNode = <String, SvgNode>{};
  late final int _maskCount;
  late final int _clipPathCount;
  late final int _gradientCount;

  @override
  String debugInstanceId = '';

  SvgTimeline? get _timeline => state._timeline;

  @override
  bool get debugCanAnimate => _timeline != null;

  @override
  SvgDebugNodeSummary get debugRootNode => _summary(state._document.root);

  @override
  SvgDebugInstanceSummary createDebugSummary() {
    final document = state._document;
    final timeline = _timeline;
    final viewBox = document.activeViewBox;
    return SvgDebugInstanceSummary(
      instanceId: debugInstanceId,
      sourceType: state._debugSourceType,
      sourceLabel: state._debugSourceLabel,
      width: state.widget.width ?? document.width ?? viewBox?.width,
      height: state.widget.height ?? document.height ?? viewBox?.height,
      animated: timeline != null,
      playing: state._controller?.isAnimating ?? false,
      currentTimeMs: timeline?.currentTime.inMilliseconds,
      durationMs: timeline?.totalDuration.inMilliseconds,
      playbackRate: timeline?.playbackRate ?? state.widget.playbackRate,
      nodeCount: _idToNode.length,
      animationCount: timeline?.animations.length ?? 0,
      hasJavaScript: document.scripts?.isNotEmpty ?? false,
      hasFilters: document.filters?.all.isNotEmpty ?? false,
      hasMasks: _maskCount > 0,
      hasClipPaths: _clipPathCount > 0,
    );
  }

  @override
  List<SvgDebugNodeSummary>? getDebugChildren(String nodeId) {
    final node = _idToNode[nodeId];
    if (node == null) return null;
    return node.children.map(_summary).toList(growable: false);
  }

  @override
  SvgDebugNodeDetails? getDebugNode(String nodeId) {
    final node = _idToNode[nodeId];
    if (node == null) return null;
    final attributes = <SvgDebugAttribute>[
      if (node.id != null)
        SvgDebugAttribute(
          name: 'id',
          rawValue: node.id,
          resolvedValue: node.id!,
          animated: false,
        ),
      if (node.className != null)
        SvgDebugAttribute(
          name: 'class',
          rawValue: node.className,
          resolvedValue: node.className!,
          animated: false,
        ),
      for (final entry in node.attributes.entries)
        SvgDebugAttribute(
          name: entry.key,
          rawValue: node.getRawAttributeValue(entry.key),
          resolvedValue: entry.value.effectiveValue.toString(),
          animated: entry.value.isAnimated,
        ),
    ]..sort((left, right) => left.name.compareTo(right.name));
    final animations = <SvgDebugAnimationDescriptor>[
      for (final animation in _timeline?.animations ?? const <SmilAnimation>[])
        if (identical(animation.targetNode, node))
          SvgDebugAnimationDescriptor(
            type: animation.type.name,
            attributeName: animation.attributeName,
            durationMs: animation.dur.inMilliseconds,
            beginMs: animation.getEffectiveBeginTime().inMilliseconds,
            repeatCount: animation.repeatCount.isInfinite
                ? 'indefinite'
                : animation.repeatCount.toString(),
            active: animation.isActive,
          ),
    ];
    return SvgDebugNodeDetails(
      summary: _summary(node),
      attributes: attributes,
      animations: animations,
    );
  }

  @override
  SvgDebugStats createDebugStats() {
    final timeline = _timeline;
    return SvgDebugStats(
      domNodes: _idToNode.length,
      animationCount: timeline?.animations.length ?? 0,
      activeAnimationCount: timeline?.getActiveAnimations().length ?? 0,
      filterPrimitiveCount: state._document.filters?.all.length ?? 0,
      maskCount: _maskCount,
      gradientCount: _gradientCount,
      clipPathCount: _clipPathCount,
      javaScriptEnabled: state._document.scripts?.isNotEmpty ?? false,
      currentTimeMs: timeline?.currentTime.inMilliseconds,
      durationMs: timeline?.totalDuration.inMilliseconds,
    );
  }

  int _countTag(String tagName) =>
      _idToNode.values.where((node) => node.tagName == tagName).length;

  SvgDebugNodeSummary _summary(SvgNode node) {
    return SvgDebugNodeSummary(
      nodeId: _nodeToId[node]!,
      tagName: node.tagName,
      svgId: node.id,
      classes:
          node.className
              ?.split(RegExp(r'\s+'))
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      childCount: node.children.length,
      animated: node.hasAnimations,
    );
  }

  @override
  void debugPlay() => state._debugPlayAnimation();

  @override
  void debugPause() => state._debugPauseAnimation();

  @override
  void debugSeek(Duration position) => state._debugSeekAnimation(position);

  @override
  void debugSetPlaybackRate(double rate) {
    state._debugSetAnimationRate(rate);
  }

  @override
  bool debugHighlightNode(String nodeId) {
    final node = _idToNode[nodeId];
    if (node == null) return false;
    state._debugHighlightedNode = node;
    state._markNeedsRepaint();
    return true;
  }

  @override
  void debugClearHighlight() {
    state._debugHighlightedNode = null;
    state._markNeedsRepaint();
  }
}
