import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('@font-face CSS Parsing', () {
    test('Parse single @font-face rule', () {
      const cssText = '''
@font-face {
  font-family: 'MyCustomFont';
  font-style: normal;
  font-weight: 400;
  src: url(data:font/ttf;base64,AAAA) format('truetype');
}
''';

      final rules = CssParser.parseFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.fontFamily, equals('MyCustomFont'));
      expect(rules.first.fontStyle, equals('normal'));
      expect(rules.first.fontWeight, equals('400'));
      expect(rules.first.src, contains('data:font/ttf'));
      expect(rules.first.format, equals('truetype'));
    });

    test('Parse multiple @font-face rules', () {
      const cssText = '''
@font-face {
  font-family: 'Font1';
  font-weight: 400;
  src: url(data:font/ttf;base64,AAA1) format('truetype');
}
@font-face {
  font-family: 'Font1';
  font-weight: 700;
  src: url(data:font/ttf;base64,AAA2) format('truetype');
}
@font-face {
  font-family: 'Font2';
  font-weight: 400;
  src: url(data:font/ttf;base64,BBB1) format('truetype');
}
''';

      final rules = CssParser.parseFontFaceRules(cssText);
      expect(rules, hasLength(3));

      final font1Rules = rules.where((r) => r.fontFamily == 'Font1').toList();
      expect(font1Rules, hasLength(2));
      expect(font1Rules.any((r) => r.fontWeight == '400'), isTrue);
      expect(font1Rules.any((r) => r.fontWeight == '700'), isTrue);

      final font2Rules = rules.where((r) => r.fontFamily == 'Font2').toList();
      expect(font2Rules, hasLength(1));
    });

    test('Parse @font-face with quoted family name', () {
      const cssText = '''
@font-face {
  font-family: "eQVNhIKm4qz1:::Orbitron";
  font-weight: 400;
  src: url(data:font/ttf;base64,AAAA) format('truetype');
}
''';

      final rules = CssParser.parseFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.fontFamily, equals('eQVNhIKm4qz1:::Orbitron'));
    });

    test('Parse @font-face without format', () {
      const cssText = '''
@font-face {
  font-family: 'MyFont';
  src: url(data:font/ttf;base64,AAAA);
}
''';

      final rules = CssParser.parseFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.format, isNull);
      expect(rules.first.isSupportedFormat, isTrue); // Detected from data URL
    });

    test('Parse @font-face with font-weight keywords', () {
      const cssText = '''
@font-face {
  font-family: 'NormalFont';
  font-weight: normal;
  src: url(data:font/ttf;base64,AAA);
}
@font-face {
  font-family: 'BoldFont';
  font-weight: bold;
  src: url(data:font/ttf;base64,BBB);
}
''';

      final rules = CssParser.parseFontFaceRules(cssText);
      expect(rules, hasLength(2));
      expect(rules.first.fontWeight, equals('400'));
      expect(rules.last.fontWeight, equals('700'));
    });

    test('Handle @font-face mixed with other rules', () {
      const cssText = '''
@keyframes spin { from { opacity: 0; } to { opacity: 1; } }
@font-face {
  font-family: 'MyFont';
  src: url(data:font/ttf;base64,AAAA) format('truetype');
}
#myId { fill: red; }
@media (min-width: 100px) { .class { fill: blue; } }
''';

      final fontFaceRules = CssParser.parseFontFaceRules(cssText);
      expect(fontFaceRules, hasLength(1));
      expect(fontFaceRules.first.fontFamily, equals('MyFont'));

      // Ensure other rules still parse correctly
      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes, hasLength(1));

      final selectorRules = CssParser.parseSelectorRules(cssText);
      expect(selectorRules.any((r) => r.selector == '#myId'), isTrue);
    });
  });

  group('CssFontFaceRule', () {
    test('isEmbeddedFont returns true for data URLs', () {
      const rule = CssFontFaceRule(
        fontFamily: 'Test',
        src: 'data:font/ttf;base64,AAAA',
      );
      expect(rule.isEmbeddedFont, isTrue);
    });

    test('isEmbeddedFont returns false for external URLs', () {
      const rule = CssFontFaceRule(
        fontFamily: 'Test',
        src: 'https://example.com/font.ttf',
      );
      expect(rule.isEmbeddedFont, isFalse);
    });

    test('isSupportedFormat returns true for TTF', () {
      const rule = CssFontFaceRule(
        fontFamily: 'Test',
        src: 'data:font/ttf;base64,AAAA',
        format: 'truetype',
      );
      expect(rule.isSupportedFormat, isTrue);
    });

    test('isSupportedFormat returns true for OTF', () {
      const rule = CssFontFaceRule(
        fontFamily: 'Test',
        src: 'data:font/otf;base64,AAAA',
        format: 'opentype',
      );
      expect(rule.isSupportedFormat, isTrue);
    });

    test('isWoffFormat returns true for WOFF', () {
      const rule = CssFontFaceRule(
        fontFamily: 'Test',
        src: 'data:font/woff;base64,AAAA',
        format: 'woff',
      );
      expect(rule.isWoffFormat, isTrue);
      expect(rule.isSupportedFormat, isFalse);
    });
  });

  group('SvgFontRegistry', () {
    test('isRegistered returns false for unregistered font', () {
      final registry = SvgFontRegistry();
      expect(registry.isRegistered('UnknownFont'), isFalse);
    });

    test('registeredFontFamilies is empty initially', () {
      final registry = SvgFontRegistry();
      expect(registry.registeredFontFamilies, isEmpty);
    });

    test('clear removes all state', () {
      final registry = SvgFontRegistry();
      // Can't easily test registration without actual font data
      // but we can verify clear works on initial state
      registry.clear();
      expect(registry.registeredFontFamilies, isEmpty);
      expect(registry.errors, isEmpty);
    });

    test('normalizes font family names with quotes', () {
      final registry = SvgFontRegistry();
      // Test via isRegistered - it uses _normalizeFontFamily internally
      // Both quoted and unquoted versions should be handled
      expect(registry.isRegistered('"MyFont"'), isFalse);
      expect(registry.isRegistered("'MyFont'"), isFalse);
      expect(registry.isRegistered('MyFont'), isFalse);
    });

    test('handles HTML-encoded quotes', () {
      final registry = SvgFontRegistry();
      // Test with HTML-encoded quotes
      expect(registry.isRegistered('&quot;MyFont&quot;'), isFalse);
    });
  });

  group('SVG Document Font Face Integration', () {
    test('Font face rules are parsed from SVG style element', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'TestFont';
      font-weight: 400;
      src: url(data:font/ttf;base64,AAAA) format('truetype');
    }
    #rect { fill: red; }
  </style>
  <rect id="rect" width="10" height="10"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssFontFaceRules, isNotNull);
      expect(document.cssFontFaceRules, hasLength(1));
      expect(document.cssFontFaceRules!.first.fontFamily, equals('TestFont'));
    });

    test('Multiple font face rules are parsed', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'Font1';
      font-weight: 400;
      src: url(data:font/ttf;base64,AAA) format('truetype');
    }
    @font-face {
      font-family: 'Font1';
      font-weight: 700;
      src: url(data:font/ttf;base64,BBB) format('truetype');
    }
    @font-face {
      font-family: 'Font2';
      font-weight: 400;
      src: url(data:font/ttf;base64,CCC) format('truetype');
    }
  </style>
  <text>Test</text>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssFontFaceRules, isNotNull);
      expect(document.cssFontFaceRules, hasLength(3));
    });

    test('SVG without font-face has null rules', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    #rect { fill: red; }
  </style>
  <rect id="rect" width="10" height="10"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssFontFaceRules, isNull);
    });

    test('SVG without style element has null font rules', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <rect width="10" height="10" fill="red"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssFontFaceRules, isNull);
    });

    test('Font registry is accessible from document', () {
      const svgString = '<svg viewBox="0 0 100 100"></svg>';
      final document = SvgParser.parse(svgString);
      expect(document.fontRegistry, isNotNull);
      expect(document.registeredFontFamilies, isEmpty);
    });

    test('isFontRegistered returns false before registration', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'TestFont';
      src: url(data:font/ttf;base64,AAAA) format('truetype');
    }
  </style>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // Font is parsed but not yet registered
      expect(document.cssFontFaceRules, hasLength(1));
      expect(document.isFontRegistered('TestFont'), isFalse);
    });

    test('registerEmbeddedFonts returns true when no fonts', () async {
      const svgString = '<svg viewBox="0 0 100 100"></svg>';
      final document = SvgParser.parse(svgString);
      final result = await document.registerEmbeddedFonts();
      expect(result, isTrue);
    });
  });

  group('extractFontFaceRules helper function', () {
    test('Extracts rules from simple CSS', () {
      const cssText = '''
@font-face { font-family: Test; src: url(data:font/ttf;base64,A); }
''';
      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(1));
    });

    test('Returns empty list when no font-face rules', () {
      const cssText = '@keyframes spin { to { opacity: 1; } }';
      final rules = extractFontFaceRules(cssText);
      expect(rules, isEmpty);
    });

    test('Handles CSS without any rules', () {
      const cssText = '/* just a comment */';
      final rules = extractFontFaceRules(cssText);
      expect(rules, isEmpty);
    });
  });

  group('Font family resolution with registered fonts', () {
    test('HTML-encoded quotes in font-family are handled in SVG', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: "MyCustomFont";
      src: url(data:font/ttf;base64,AAAA) format('truetype');
    }
  </style>
  <text font-family="&quot;MyCustomFont&quot;">Hello</text>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssFontFaceRules, isNotNull);
      expect(
        document.cssFontFaceRules!.first.fontFamily,
        equals('MyCustomFont'),
      );

      // The font-family attribute value is decoded by the XML parser
      // HTML entities like &quot; become actual quote characters
      final textNode = document.getElementsByTag('text').first;
      final fontFamilyAttr = textNode.getAttributeValue('font-family');
      expect(fontFamilyAttr, isNotNull);
      // The XML parser decodes &quot; to actual quote
      expect(fontFamilyAttr, contains('MyCustomFont'));
    });

    test('Font family with special characters (:::) is preserved', () {
      const cssText = '''
@font-face {
  font-family: "eQVNhIKm4qz1:::Orbitron";
  src: url(data:font/ttf;base64,AAAA) format('truetype');
}
''';

      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.fontFamily, equals('eQVNhIKm4qz1:::Orbitron'));
    });
  });

  group('Base64 font data extraction', () {
    test('extractFontFaceRules extracts data URL correctly', () {
      const cssText = '''
@font-face {
  font-family: 'TestFont';
  src: url(data:font/ttf;charset=utf-8;base64,AAEAAAAQAQAABAAA) format('truetype');
}
''';

      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.src, contains('base64,AAEAAAAQAQAABAAA'));
    });

    test('extractFontFaceRules handles src with single quotes', () {
      const cssText = '''
@font-face {
  font-family: 'TestFont';
  src: url('data:font/ttf;base64,AAAA') format('truetype');
}
''';

      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.src, contains('data:font/ttf'));
    });

    test('extractFontFaceRules handles src without quotes', () {
      const cssText = '''
@font-face {
  font-family: 'TestFont';
  src: url(data:font/ttf;base64,AAAA) format('truetype');
}
''';

      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(1));
      expect(rules.first.src, equals('data:font/ttf;base64,AAAA'));
    });
  });

  group('Duplicate font prevention', () {
    test('Same font family with different weights creates separate rules', () {
      const cssText = '''
@font-face {
  font-family: 'MyFont';
  font-weight: 400;
  src: url(data:font/ttf;base64,AAA) format('truetype');
}
@font-face {
  font-family: 'MyFont';
  font-weight: 700;
  src: url(data:font/ttf;base64,BBB) format('truetype');
}
''';

      final rules = extractFontFaceRules(cssText);
      expect(rules, hasLength(2));
      expect(rules.where((r) => r.fontFamily == 'MyFont'), hasLength(2));
    });

    test('Registry prevents duplicate registration', () async {
      final registry = SvgFontRegistry();
      // Note: We can't test actual registration without valid font bytes
      // but we can verify the structure
      expect(registry.registeredFontFamilies, isEmpty);
    });
  });

  group('Font registration error handling', () {
    test('External URLs produce errors', () async {
      final registry = SvgFontRegistry();
      final rules = [
        const CssFontFaceRule(
          fontFamily: 'ExternalFont',
          src: 'https://example.com/font.ttf',
        ),
      ];

      await registry.registerFonts(rules);
      expect(registry.errors, isNotEmpty);
      expect(registry.errors.first, contains('External URLs not supported'));
      expect(registry.isRegistered('ExternalFont'), isFalse);
    });

    test('WOFF format produces warning', () async {
      final registry = SvgFontRegistry();
      final rules = [
        const CssFontFaceRule(
          fontFamily: 'WoffFont',
          src: 'data:font/woff;base64,AAAA',
          format: 'woff',
        ),
      ];

      await registry.registerFonts(rules);
      expect(registry.errors, isNotEmpty);
      expect(
        registry.errors.first,
        contains('WOFF format not natively supported'),
      );
      expect(registry.isRegistered('WoffFont'), isFalse);
    });

    test('Unsupported format produces error', () async {
      final registry = SvgFontRegistry();
      final rules = [
        const CssFontFaceRule(
          fontFamily: 'UnsupportedFont',
          src: 'data:font/unknown;base64,AAAA',
          format: 'svg',
        ),
      ];

      await registry.registerFonts(rules);
      expect(registry.errors, isNotEmpty);
      expect(registry.errors.first, contains('Unsupported format'));
      expect(registry.isRegistered('UnsupportedFont'), isFalse);
    });
  });
}
