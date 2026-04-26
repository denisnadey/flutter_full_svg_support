part of 'path_parser.dart';

/// Exception thrown when path parsing fails.
class PathParseException implements Exception {
  PathParseException(this.message);

  final String message;

  @override
  String toString() => 'PathParseException: $message';
}
