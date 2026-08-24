import 'package:flutter/foundation.dart';

abstract interface class FullSvgTransport implements Listenable {
  bool get connected;

  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> args = const <String, Object?>{},
  });
}

class FullSvgTransportException implements Exception {
  const FullSvgTransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
