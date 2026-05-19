import 'package:flutter/material.dart';
import 'package:woff2/woff2.dart';

// Replace with a .woff2 asset declared in your pubspec.yaml.
const _assetPath = 'assets/fonts/Inter.woff2';
const _fontFamily = 'Inter';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One-call helper: decodes the WOFF2 to SFNT (TTF/OTF) and
  // registers the family with Flutter's FontLoader.
  await loadWoffFontFromAsset(
    fontFamily: _fontFamily,
    assetPath: _assetPath,
  );

  runApp(const _DemoApp());
}

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'woff2 demo',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: _fontFamily),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('woff2 demo')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This text uses an embedded WOFF2 font, decoded and '
              'registered at runtime by the woff2 package.',
              style: TextStyle(fontFamily: _fontFamily, fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
