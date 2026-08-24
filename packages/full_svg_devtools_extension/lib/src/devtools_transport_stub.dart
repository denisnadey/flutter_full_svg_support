import 'package:flutter/foundation.dart';

import 'full_svg_transport.dart';

/// VM-test fallback. Production DevTools extensions compile the web transport.
class DevToolsFullSvgTransport extends ChangeNotifier
    implements FullSvgTransport {
  @override
  bool get connected => false;

  @override
  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> args = const <String, Object?>{},
  }) {
    throw const FullSvgTransportException(
      'The DevTools VM transport is only available on web.',
    );
  }
}
