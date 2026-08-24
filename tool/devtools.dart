import 'dart:io';

Future<void> main(List<String> arguments) async {
  final command = arguments.isEmpty ? 'all' : arguments.first;
  if (!const <String>{
    'all',
    'build',
    'validate',
    'simulate',
  }.contains(command)) {
    stderr.writeln(
      'Usage: dart run tool/devtools.dart [all|build|validate|simulate]',
    );
    exitCode = 64;
    return;
  }

  final root = Directory.current.absolute;
  final source = Directory(
    '${root.path}${Platform.pathSeparator}packages${Platform.pathSeparator}'
    'full_svg_devtools_extension',
  );
  final destination = Directory(
    '${root.path}${Platform.pathSeparator}extension${Platform.pathSeparator}'
    'devtools',
  );
  final flutter = _flutterExecutable(root);
  final dart = _dartExecutable(flutter);
  final environment = <String, String>{
    ...Platform.environment,
    'PATH':
        '${File(flutter).parent.path}${Platform.isWindows ? ';' : ':'}'
        '${Platform.environment['PATH'] ?? ''}',
  };

  if (command == 'all' || command == 'build') {
    await _run(
      flutter,
      const <String>['pub', 'get'],
      workingDirectory: source.path,
      environment: environment,
    );
    await _run(
      dart,
      <String>[
        'run',
        'devtools_extensions',
        'build_and_copy',
        '--source=${source.path}',
        '--dest=${destination.path}',
      ],
      workingDirectory: source.path,
      environment: environment,
    );
  }

  if (command == 'all' || command == 'validate') {
    await _run(
      dart,
      <String>[
        'run',
        'devtools_extensions',
        'validate',
        '--package=${root.path}',
      ],
      workingDirectory: source.path,
      environment: environment,
    );
  }

  if (command == 'simulate') {
    await _run(
      flutter,
      const <String>[
        'run',
        '-d',
        'chrome',
        '--dart-define=use_simulated_environment=true',
      ],
      workingDirectory: source.path,
      environment: environment,
    );
  }
}

String _flutterExecutable(Directory root) {
  final suffix = Platform.isWindows ? '.bat' : '';
  final local = File(
    '${root.path}${Platform.pathSeparator}.fvm${Platform.pathSeparator}'
    'flutter_sdk${Platform.pathSeparator}bin${Platform.pathSeparator}'
    'flutter$suffix',
  );
  return local.existsSync() ? local.path : 'flutter$suffix';
}

String _dartExecutable(String flutter) {
  if (flutter == 'flutter' || flutter == 'flutter.bat') return 'dart';
  final suffix = Platform.isWindows ? '.exe' : '';
  return '${File(flutter).parent.path}${Platform.pathSeparator}dart$suffix';
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
}) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, 'Command failed', result);
  }
}
