import 'dart:convert';
import 'dart:developer' as developer;

import 'full_svg_debug_protocol.dart';

/// Narrow renderer-facing boundary used by the VM-service bridge.
abstract interface class FullSvgDebugInspectable {
  String get debugInstanceId;
  set debugInstanceId(String value);

  SvgDebugInstanceSummary createDebugSummary();
  SvgDebugNodeSummary get debugRootNode;
  List<SvgDebugNodeSummary>? getDebugChildren(String nodeId);
  SvgDebugNodeDetails? getDebugNode(String nodeId);
  SvgDebugStats createDebugStats();

  bool get debugCanAnimate;
  void debugPlay();
  void debugPause();
  void debugSeek(Duration position);
  void debugSetPlaybackRate(double rate);
  bool debugHighlightNode(String nodeId);
  void debugClearHighlight();
}

/// Debug-only registry of mounted renderer adapters.
///
/// Weak references provide a second line of defence against leaks if a widget
/// is removed in an unusual lifecycle path. Renderers still unregister
/// deterministically from `dispose`.
class FullSvgDebugRegistry {
  FullSvgDebugRegistry._();

  static final FullSvgDebugRegistry instance = FullSvgDebugRegistry._();

  final Map<String, WeakReference<FullSvgDebugInspectable>> _instances =
      <String, WeakReference<FullSvgDebugInspectable>>{};
  int _nextInstanceOrdinal = 1;

  String register(FullSvgDebugInspectable inspectable) {
    _ensureServiceExtensionsRegistered();
    final id = 'svg-${_nextInstanceOrdinal++}';
    inspectable.debugInstanceId = id;
    _instances[id] = WeakReference<FullSvgDebugInspectable>(inspectable);
    return id;
  }

  void unregister(String instanceId) {
    _instances.remove(instanceId);
  }

  FullSvgDebugInspectable? lookup(String instanceId) {
    final target = _instances[instanceId]?.target;
    if (target == null) {
      _instances.remove(instanceId);
    }
    return target;
  }

  List<FullSvgDebugInspectable> get liveInstances {
    final result = <FullSvgDebugInspectable>[];
    final staleIds = <String>[];
    for (final entry in _instances.entries) {
      final target = entry.value.target;
      if (target == null) {
        staleIds.add(entry.key);
      } else {
        result.add(target);
      }
    }
    for (final id in staleIds) {
      _instances.remove(id);
    }
    return result;
  }

  /// Resets ordinals and entries for deterministic unit tests.
  void debugResetForTesting() {
    _instances.clear();
    _nextInstanceOrdinal = 1;
  }
}

bool _serviceExtensionsRegistered = false;

void _ensureServiceExtensionsRegistered() {
  if (_serviceExtensionsRegistered) return;
  for (final method in FullSvgDebugProtocol.methods) {
    developer.registerExtension(method, (name, parameters) async {
      final payload = FullSvgDebugService(
        FullSvgDebugRegistry.instance,
      ).handle(name, parameters);
      return developer.ServiceExtensionResponse.result(jsonEncode(payload));
    });
  }
  _serviceExtensionsRegistered = true;
}

/// Pure dispatcher kept separate from `dart:developer` for protocol tests.
class FullSvgDebugService {
  const FullSvgDebugService(this.registry);

  final FullSvgDebugRegistry registry;

  Map<String, Object?> handle(String method, Map<String, String> parameters) {
    try {
      switch (method) {
        case FullSvgDebugProtocol.getProtocolVersion:
          return fullSvgDebugSuccess();
        case FullSvgDebugProtocol.getInstances:
          return fullSvgDebugSuccess(<String, Object?>{
            'instances': registry.liveInstances
                .map((instance) => instance.createDebugSummary().toJson())
                .toList(growable: false),
          });
        case FullSvgDebugProtocol.getInstance:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          final inspectable = instance as FullSvgDebugInspectable;
          return fullSvgDebugSuccess(<String, Object?>{
            'instance': inspectable.createDebugSummary().toJson(),
            'root': inspectable.debugRootNode.toJson(),
          });
        case FullSvgDebugProtocol.getTree:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          final inspectable = instance as FullSvgDebugInspectable;
          final nodeId = parameters['nodeId'];
          if (nodeId == null || nodeId.isEmpty) {
            return fullSvgDebugSuccess(<String, Object?>{
              'parentNodeId': null,
              'nodes': <Map<String, Object?>>[
                inspectable.debugRootNode.toJson(),
              ],
            });
          }
          final children = inspectable.getDebugChildren(nodeId);
          if (children == null) return _nodeNotFound(nodeId);
          return fullSvgDebugSuccess(<String, Object?>{
            'parentNodeId': nodeId,
            'nodes': children.map((node) => node.toJson()).toList(),
          });
        case FullSvgDebugProtocol.getNode:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          final nodeId = _requiredText(parameters, 'nodeId');
          if (nodeId is Map<String, Object?>) return nodeId;
          final details = (instance as FullSvgDebugInspectable).getDebugNode(
            nodeId as String,
          );
          if (details == null) return _nodeNotFound(nodeId);
          return fullSvgDebugSuccess(<String, Object?>{
            'node': details.toJson(),
          });
        case FullSvgDebugProtocol.getStats:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          return fullSvgDebugSuccess(<String, Object?>{
            'stats': (instance as FullSvgDebugInspectable)
                .createDebugStats()
                .toJson(),
          });
        case FullSvgDebugProtocol.play:
          return _animationCommand(parameters, (instance) {
            instance.debugPlay();
          });
        case FullSvgDebugProtocol.pause:
          return _animationCommand(parameters, (instance) {
            instance.debugPause();
          });
        case FullSvgDebugProtocol.seek:
          final value = _finiteDouble(parameters, 'positionMs', minimum: 0);
          if (value is Map<String, Object?>) return value;
          return _animationCommand(parameters, (instance) {
            instance.debugSeek(
              Duration(microseconds: ((value as double) * 1000).round()),
            );
          });
        case FullSvgDebugProtocol.setPlaybackRate:
          final value = _finiteDouble(
            parameters,
            'rate',
            minimum: 0.05,
            maximum: 16,
          );
          if (value is Map<String, Object?>) return value;
          return _animationCommand(parameters, (instance) {
            instance.debugSetPlaybackRate(value as double);
          });
        case FullSvgDebugProtocol.highlightNode:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          final nodeId = _requiredText(parameters, 'nodeId');
          if (nodeId is Map<String, Object?>) return nodeId;
          if (!(instance as FullSvgDebugInspectable).debugHighlightNode(
            nodeId as String,
          )) {
            return _nodeNotFound(nodeId);
          }
          return fullSvgDebugSuccess();
        case FullSvgDebugProtocol.clearHighlight:
          final instance = _requireInstance(parameters);
          if (instance is Map<String, Object?>) return instance;
          (instance as FullSvgDebugInspectable).debugClearHighlight();
          return fullSvgDebugSuccess();
      }
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.unsupportedMethod,
        message: 'Unsupported FullSVG debug method: $method',
      );
    } catch (error) {
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.internalError,
        message: 'The FullSVG runtime could not complete the request.',
        details: <String, Object?>{'errorType': error.runtimeType.toString()},
      );
    }
  }

  Map<String, Object?> _animationCommand(
    Map<String, String> parameters,
    void Function(FullSvgDebugInspectable instance) command,
  ) {
    final instance = _requireInstance(parameters);
    if (instance is Map<String, Object?>) return instance;
    final inspectable = instance as FullSvgDebugInspectable;
    if (!inspectable.debugCanAnimate) {
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.animationUnavailable,
        message: 'This SVG instance has no controllable animation timeline.',
      );
    }
    command(inspectable);
    return fullSvgDebugSuccess(<String, Object?>{
      'instance': inspectable.createDebugSummary().toJson(),
    });
  }

  Object _requireInstance(Map<String, String> parameters) {
    final id = _requiredText(parameters, 'instanceId');
    if (id is Map<String, Object?>) return id;
    final instance = registry.lookup(id as String);
    if (instance == null) {
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.instanceNotFound,
        message: 'SVG instance $id is no longer mounted.',
      );
    }
    return instance;
  }

  Object _requiredText(Map<String, String> parameters, String name) {
    final value = parameters[name]?.trim();
    if (value == null || value.isEmpty) {
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.invalidParameter,
        message: 'Parameter "$name" is required.',
      );
    }
    return value;
  }

  Object _finiteDouble(
    Map<String, String> parameters,
    String name, {
    required double minimum,
    double? maximum,
  }) {
    final raw = parameters[name];
    final value = raw == null ? null : double.tryParse(raw);
    final valid =
        value != null &&
        value.isFinite &&
        value >= minimum &&
        (maximum == null || value <= maximum);
    if (!valid) {
      final range = maximum == null
          ? 'at least $minimum'
          : 'between $minimum and $maximum';
      return fullSvgDebugFailure(
        code: FullSvgDebugErrorCode.invalidParameter,
        message: 'Parameter "$name" must be a finite number $range.',
      );
    }
    return value;
  }

  Map<String, Object?> _nodeNotFound(String nodeId) => fullSvgDebugFailure(
    code: FullSvgDebugErrorCode.nodeNotFound,
    message: 'SVG node $nodeId does not exist in this document instance.',
  );
}
