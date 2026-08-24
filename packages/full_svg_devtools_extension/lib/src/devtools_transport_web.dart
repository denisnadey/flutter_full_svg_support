import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';

import 'full_svg_transport.dart';

class DevToolsFullSvgTransport extends ChangeNotifier
    implements FullSvgTransport {
  DevToolsFullSvgTransport() {
    serviceManager.connectedState.addListener(_handleConnectionChange);
    serviceManager.isolateManager.mainIsolate.addListener(
      _handleConnectionChange,
    );
  }

  @override
  bool get connected => serviceManager.connectedState.value.connected;

  void _handleConnectionChange() => notifyListeners();

  @override
  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> args = const <String, Object?>{},
  }) async {
    if (!connected) {
      throw const FullSvgTransportException(
        'No Flutter application is connected.',
      );
    }
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        method,
        args: args,
      );
      final json = response.json;
      if (json == null) {
        throw const FullSvgTransportException(
          'FullSVG returned an empty VM-service response.',
        );
      }
      return json.cast<String, Object?>();
    } catch (error) {
      if (error is FullSvgTransportException) rethrow;
      throw FullSvgTransportException(
        'Unable to call $method on the connected application.',
        cause: error,
      );
    }
  }

  @override
  void dispose() {
    serviceManager.connectedState.removeListener(_handleConnectionChange);
    serviceManager.isolateManager.mainIsolate.removeListener(
      _handleConnectionChange,
    );
    super.dispose();
  }
}
