import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:full_svg_flutter/full_svg_debug_protocol.dart';

import 'full_svg_protocol_client.dart';
import 'full_svg_transport.dart';

enum FullSvgInspectorStatus {
  connecting,
  disconnected,
  unavailable,
  empty,
  ready,
  error,
}

class FullSvgInspectorController extends ChangeNotifier {
  FullSvgInspectorController({
    required this.transport,
    FullSvgProtocolClient? client,
    this.enablePolling = true,
  }) : client = client ?? FullSvgProtocolClient(transport) {
    transport.addListener(_handleTransportChange);
  }

  final FullSvgTransport transport;
  final FullSvgProtocolClient client;
  final bool enablePolling;

  FullSvgInspectorStatus status = FullSvgInspectorStatus.connecting;
  String? errorMessage;
  List<SvgDebugInstanceSummary> instances = const <SvgDebugInstanceSummary>[];
  SvgDebugInstanceSummary? selectedInstance;
  SvgDebugNodeSummary? rootNode;
  SvgDebugNodeDetails? selectedNode;
  SvgDebugStats? stats;
  final Map<String, List<SvgDebugNodeSummary>> childrenByNode =
      <String, List<SvgDebugNodeSummary>>{};
  final Set<String> loadingNodeIds = <String>{};

  Timer? _instanceTimer;
  Timer? _playbackTimer;
  int _connectionGeneration = 0;
  bool _refreshingInstances = false;
  bool _refreshingSelection = false;
  bool _protocolVerifiedOnce = false;

  Future<void> start() async {
    await _connect(_connectionGeneration);
  }

  Future<void> retry() async {
    final generation = ++_connectionGeneration;
    _stopPolling();
    status = transport.connected
        ? FullSvgInspectorStatus.connecting
        : FullSvgInspectorStatus.disconnected;
    errorMessage = null;
    notifyListeners();
    await _connect(generation);
  }

  void _handleTransportChange() {
    final generation = ++_connectionGeneration;
    _stopPolling();
    if (!transport.connected) {
      status = FullSvgInspectorStatus.disconnected;
      errorMessage = null;
      instances = const <SvgDebugInstanceSummary>[];
      _clearSelection();
      notifyListeners();
      return;
    }
    status = FullSvgInspectorStatus.connecting;
    errorMessage = null;
    notifyListeners();
    unawaited(_connect(generation));
  }

  Future<void> _connect(int generation, {int reconnectAttempt = 0}) async {
    if (!transport.connected) {
      if (generation != _connectionGeneration) return;
      status = FullSvgInspectorStatus.disconnected;
      notifyListeners();
      return;
    }
    try {
      await client.verifyProtocol();
      if (generation != _connectionGeneration) return;
      _protocolVerifiedOnce = true;
      await refreshInstances();
      if (generation != _connectionGeneration) return;
      _startPolling();
    } catch (error) {
      if (generation != _connectionGeneration) return;
      if (_protocolVerifiedOnce &&
          transport.connected &&
          reconnectAttempt < 8) {
        status = FullSvgInspectorStatus.connecting;
        errorMessage = 'FullSVG runtime restarted. Reconnecting…';
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (generation != _connectionGeneration) return;
        await _connect(generation, reconnectAttempt: reconnectAttempt + 1);
        return;
      }
      status = FullSvgInspectorStatus.unavailable;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  void _startPolling() {
    if (!enablePolling) return;
    _instanceTimer?.cancel();
    _playbackTimer?.cancel();
    _instanceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(refreshInstances(background: true));
    });
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(refreshSelected(background: true));
    });
  }

  void _stopPolling() {
    _instanceTimer?.cancel();
    _playbackTimer?.cancel();
    _instanceTimer = null;
    _playbackTimer = null;
  }

  Future<void> refreshInstances({bool background = false}) async {
    if (_refreshingInstances || !transport.connected) return;
    _refreshingInstances = true;
    try {
      final refreshed = await client.getInstances();
      instances = refreshed;
      if (refreshed.isEmpty) {
        _clearSelection();
        status = FullSvgInspectorStatus.empty;
      } else {
        status = FullSvgInspectorStatus.ready;
        final selectedId = selectedInstance?.instanceId;
        final retained = selectedId == null
            ? null
            : _findInstance(refreshed, selectedId);
        if (retained == null) {
          await selectInstance(refreshed.first.instanceId);
        } else {
          selectedInstance = retained;
        }
      }
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      _handleRequestError(error, background: background);
    } finally {
      _refreshingInstances = false;
    }
  }

  Future<void> selectInstance(String instanceId) async {
    final oldId = selectedInstance?.instanceId;
    if (oldId != null && oldId != instanceId) {
      unawaited(_ignoreProtocolError(client.clearHighlight(oldId)));
    }
    selectedInstance = _findInstance(instances, instanceId);
    rootNode = null;
    selectedNode = null;
    stats = null;
    childrenByNode.clear();
    loadingNodeIds.clear();
    notifyListeners();
    try {
      final result = await client.getInstance(instanceId);
      if (selectedInstance?.instanceId != instanceId) return;
      selectedInstance = result.instance;
      rootNode = result.root;
      stats = await client.getStats(instanceId);
      if (selectedInstance?.instanceId != instanceId) return;
      notifyListeners();
    } catch (error) {
      _handleRequestError(error);
    }
  }

  Future<void> loadChildren(SvgDebugNodeSummary node) async {
    final instanceId = selectedInstance?.instanceId;
    if (instanceId == null ||
        node.childCount == 0 ||
        childrenByNode.containsKey(node.nodeId) ||
        loadingNodeIds.contains(node.nodeId)) {
      return;
    }
    loadingNodeIds.add(node.nodeId);
    notifyListeners();
    try {
      final children = await client.getChildren(instanceId, node.nodeId);
      if (selectedInstance?.instanceId != instanceId) return;
      childrenByNode[node.nodeId] = children;
    } catch (error) {
      _handleRequestError(error);
    } finally {
      loadingNodeIds.remove(node.nodeId);
      notifyListeners();
    }
  }

  Future<void> selectNode(SvgDebugNodeSummary node) async {
    final instanceId = selectedInstance?.instanceId;
    if (instanceId == null) return;
    try {
      selectedNode = await client.getNode(instanceId, node.nodeId);
      await client.highlightNode(instanceId, node.nodeId);
      if (selectedInstance?.instanceId != instanceId) return;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      _handleRequestError(error);
    }
  }

  Future<void> clearHighlight() async {
    final instanceId = selectedInstance?.instanceId;
    if (instanceId == null) return;
    try {
      await client.clearHighlight(instanceId);
      selectedNode = null;
      notifyListeners();
    } catch (error) {
      _handleRequestError(error);
    }
  }

  Future<void> refreshSelected({bool background = false}) async {
    final instanceId = selectedInstance?.instanceId;
    if (_refreshingSelection || instanceId == null || !transport.connected) {
      return;
    }
    _refreshingSelection = true;
    try {
      final result = await client.getInstance(instanceId);
      final refreshedStats = await client.getStats(instanceId);
      if (selectedInstance?.instanceId != instanceId) return;
      selectedInstance = result.instance;
      stats = refreshedStats;
      final index = instances.indexWhere(
        (instance) => instance.instanceId == instanceId,
      );
      if (index >= 0) {
        final updated = List<SvgDebugInstanceSummary>.of(instances);
        updated[index] = result.instance;
        instances = updated;
      }
      notifyListeners();
    } catch (error) {
      _handleRequestError(error, background: background);
    } finally {
      _refreshingSelection = false;
    }
  }

  Future<void> togglePlayback() async {
    final instance = selectedInstance;
    if (instance == null || !instance.animated) return;
    await _runCommand(
      instance.playing
          ? client.pause(instance.instanceId)
          : client.play(instance.instanceId),
    );
  }

  Future<void> restart() async {
    final id = selectedInstance?.instanceId;
    if (id == null) return;
    await _runCommand(client.seek(id, 0));
  }

  Future<void> seek(double positionMs) async {
    final id = selectedInstance?.instanceId;
    if (id == null) return;
    await _runCommand(client.seek(id, positionMs), refresh: false);
  }

  Future<void> setPlaybackRate(double rate) async {
    final id = selectedInstance?.instanceId;
    if (id == null) return;
    await _runCommand(client.setPlaybackRate(id, rate));
  }

  Future<void> _runCommand(Future<void> command, {bool refresh = true}) async {
    try {
      await command;
      if (refresh) await refreshSelected();
    } catch (error) {
      _handleRequestError(error);
    }
  }

  void _handleRequestError(Object error, {bool background = false}) {
    if (error is FullSvgProtocolException &&
        error.code == FullSvgDebugErrorCode.instanceNotFound) {
      unawaited(refreshInstances(background: true));
      return;
    }
    errorMessage = error.toString();
    if (!background && instances.isEmpty) {
      status = FullSvgInspectorStatus.error;
    }
    notifyListeners();
  }

  SvgDebugInstanceSummary? _findInstance(
    List<SvgDebugInstanceSummary> source,
    String id,
  ) {
    for (final instance in source) {
      if (instance.instanceId == id) return instance;
    }
    return null;
  }

  void _clearSelection() {
    selectedInstance = null;
    rootNode = null;
    selectedNode = null;
    stats = null;
    childrenByNode.clear();
    loadingNodeIds.clear();
  }

  Future<void> _ignoreProtocolError(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // The old instance may have been disposed between refreshes.
    }
  }

  @override
  void dispose() {
    _stopPolling();
    transport.removeListener(_handleTransportChange);
    super.dispose();
  }
}
