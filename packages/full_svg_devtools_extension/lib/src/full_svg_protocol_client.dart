import 'package:full_svg_flutter/full_svg_debug_protocol.dart';

import 'full_svg_transport.dart';

class FullSvgProtocolClient {
  const FullSvgProtocolClient(this.transport);

  final FullSvgTransport transport;

  Future<void> verifyProtocol() async {
    final response = await _call(FullSvgDebugProtocol.getProtocolVersion);
    final version = (response['protocolVersion']! as num).toInt();
    if (version != FullSvgDebugProtocol.version) {
      throw FullSvgProtocolException(
        'Unsupported FullSVG protocol version $version. '
        'This inspector supports version ${FullSvgDebugProtocol.version}.',
        code: 'unsupported_protocol',
      );
    }
  }

  Future<List<SvgDebugInstanceSummary>> getInstances() async {
    final response = await _call(FullSvgDebugProtocol.getInstances);
    return (response['instances']! as List<Object?>)
        .map(
          (item) => SvgDebugInstanceSummary.fromJson(
            (item! as Map<Object?, Object?>).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  Future<({SvgDebugInstanceSummary instance, SvgDebugNodeSummary root})>
  getInstance(String instanceId) async {
    final response = await _call(
      FullSvgDebugProtocol.getInstance,
      args: <String, Object?>{'instanceId': instanceId},
    );
    return (
      instance: SvgDebugInstanceSummary.fromJson(
        (response['instance']! as Map<Object?, Object?>)
            .cast<String, Object?>(),
      ),
      root: SvgDebugNodeSummary.fromJson(
        (response['root']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
    );
  }

  Future<List<SvgDebugNodeSummary>> getChildren(
    String instanceId,
    String nodeId,
  ) async {
    final response = await _call(
      FullSvgDebugProtocol.getTree,
      args: <String, Object?>{'instanceId': instanceId, 'nodeId': nodeId},
    );
    return (response['nodes']! as List<Object?>)
        .map(
          (item) => SvgDebugNodeSummary.fromJson(
            (item! as Map<Object?, Object?>).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  Future<SvgDebugNodeDetails> getNode(String instanceId, String nodeId) async {
    final response = await _call(
      FullSvgDebugProtocol.getNode,
      args: <String, Object?>{'instanceId': instanceId, 'nodeId': nodeId},
    );
    return SvgDebugNodeDetails.fromJson(
      (response['node']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  Future<SvgDebugStats> getStats(String instanceId) async {
    final response = await _call(
      FullSvgDebugProtocol.getStats,
      args: <String, Object?>{'instanceId': instanceId},
    );
    return SvgDebugStats.fromJson(
      (response['stats']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
  }

  Future<void> play(String instanceId) => _command(
    FullSvgDebugProtocol.play,
    <String, Object?>{'instanceId': instanceId},
  );

  Future<void> pause(String instanceId) => _command(
    FullSvgDebugProtocol.pause,
    <String, Object?>{'instanceId': instanceId},
  );

  Future<void> seek(String instanceId, double positionMs) => _command(
    FullSvgDebugProtocol.seek,
    <String, Object?>{'instanceId': instanceId, 'positionMs': positionMs},
  );

  Future<void> setPlaybackRate(String instanceId, double rate) => _command(
    FullSvgDebugProtocol.setPlaybackRate,
    <String, Object?>{'instanceId': instanceId, 'rate': rate},
  );

  Future<void> highlightNode(String instanceId, String nodeId) => _command(
    FullSvgDebugProtocol.highlightNode,
    <String, Object?>{'instanceId': instanceId, 'nodeId': nodeId},
  );

  Future<void> clearHighlight(String instanceId) => _command(
    FullSvgDebugProtocol.clearHighlight,
    <String, Object?>{'instanceId': instanceId},
  );

  Future<void> _command(String method, Map<String, Object?> args) async {
    await _call(method, args: args);
  }

  Future<Map<String, Object?>> _call(
    String method, {
    Map<String, Object?> args = const <String, Object?>{},
  }) async {
    final response = await transport.call(method, args: args);
    if (response['ok'] != true) {
      final error = (response['error'] as Map<Object?, Object?>?)
          ?.cast<String, Object?>();
      throw FullSvgProtocolException(
        error?['message'] as String? ?? 'FullSVG request failed.',
        code: error?['code'] as String? ?? 'unknown_error',
      );
    }
    return response;
  }
}

class FullSvgProtocolException implements Exception {
  const FullSvgProtocolException(this.message, {required this.code});

  final String message;
  final String code;

  @override
  String toString() => message;
}
