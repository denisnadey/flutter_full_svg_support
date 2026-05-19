import 'package:flutter_test/flutter_test.dart';
import 'package:woff2/woff2.dart';

void main() {
  group('CssFontFaceRule defaults', () {
    test('weight defaults to 400, style defaults to normal', () {
      const rule = CssFontFaceRule(fontFamily: 'Inter');
      expect(rule.fontWeight, '400');
      expect(rule.fontStyle, 'normal');
      expect(rule.src, isNull);
      expect(rule.format, isNull);
    });
  });

  group('isEmbeddedFont detection', () {
    test('data:font/... is an embedded font', () {
      const rule = CssFontFaceRule(
        fontFamily: 'X',
        src: 'data:font/ttf;base64,AAAA',
      );
      expect(rule.isEmbeddedFont, isTrue);
    });

    test('data:application/x-font-ttf is an embedded font', () {
      const rule = CssFontFaceRule(
        fontFamily: 'X',
        src: 'data:application/x-font-ttf;base64,AAAA',
      );
      expect(rule.isEmbeddedFont, isTrue);
    });

    test('relative path is not embedded', () {
      const rule = CssFontFaceRule(fontFamily: 'X', src: 'fonts/X.woff2');
      expect(rule.isEmbeddedFont, isFalse);
    });
  });

  group('isWoffFormat / isSupportedFormat', () {
    test('explicit format=woff2 is detected', () {
      const rule = CssFontFaceRule(fontFamily: 'X', format: 'woff2');
      expect(rule.isWoffFormat, isTrue);
      expect(rule.isSupportedFormat, isFalse);
    });

    test('explicit format=truetype is supported by Flutter', () {
      const rule = CssFontFaceRule(fontFamily: 'X', format: 'truetype');
      expect(rule.isSupportedFormat, isTrue);
      expect(rule.isWoffFormat, isFalse);
    });

    test('format inferred from data URL mime type — woff2', () {
      const rule = CssFontFaceRule(
        fontFamily: 'X',
        src: 'data:font/woff2;base64,AAAA',
      );
      expect(rule.isWoffFormat, isTrue);
    });

    test('format inferred from data URL mime type — opentype', () {
      const rule = CssFontFaceRule(
        fontFamily: 'X',
        src: 'data:font/opentype;base64,AAAA',
      );
      expect(rule.isSupportedFormat, isTrue);
    });
  });

  group('extractFontFaceRules — single rule', () {
    test('parses a basic @font-face block', () {
      const css = '''
        @font-face {
          font-family: 'Inter';
          font-weight: 400;
          font-style: normal;
          src: url(fonts/Inter.woff2) format('woff2');
        }
      ''';
      final rules = extractFontFaceRules(css);
      expect(rules, hasLength(1));
      final rule = rules.single;
      expect(rule.fontFamily, 'Inter');
      expect(rule.fontWeight, '400');
      expect(rule.fontStyle, 'normal');
      expect(rule.src, 'fonts/Inter.woff2');
      expect(rule.format, 'woff2');
    });

    test('normalises font-weight keywords to numeric strings', () {
      const css = '''
        @font-face {
          font-family: 'Inter';
          font-weight: bold;
          src: url(fonts/Inter-Bold.woff2);
        }
      ''';
      final rule = extractFontFaceRules(css).single;
      expect(rule.fontWeight, '700');
    });

    test('preserves numeric weights inside 100–900', () {
      const css = '''
        @font-face {
          font-family: 'Inter';
          font-weight: 250;
          src: url(fonts/Inter-XLight.woff2);
        }
      ''';
      // 250 isn't a "real" CSS weight but the parser doesn't snap; it
      // only rejects values outside the 100–900 range.
      final rule = extractFontFaceRules(css).single;
      expect(rule.fontWeight, '250');
    });

    test('rejects out-of-range weight and falls back to 400', () {
      const css = '''
        @font-face {
          font-family: 'X';
          font-weight: 50;
          src: url(x.woff2);
        }
      ''';
      expect(extractFontFaceRules(css).single.fontWeight, '400');
    });

    test('strips quotes from font-family', () {
      const css = '''
        @font-face {
          font-family: "My Font";
          src: url(x.woff2);
        }
      ''';
      expect(extractFontFaceRules(css).single.fontFamily, 'My Font');
    });

    test('handles HTML-encoded quotes inside font-family', () {
      const css = '''
        @font-face {
          font-family: &quot;My Font&quot;;
          src: url(x.woff2);
        }
      ''';
      expect(extractFontFaceRules(css).single.fontFamily, 'My Font');
    });

    test('parses a data: URL src that contains semicolons', () {
      const css = '''
        @font-face {
          font-family: 'Inline';
          src: url(data:font/woff2;charset=utf-8;base64,AAA) format('woff2');
        }
      ''';
      final rule = extractFontFaceRules(css).single;
      expect(rule.src, startsWith('data:font/woff2;'));
      expect(rule.format, 'woff2');
      expect(rule.isEmbeddedFont, isTrue);
    });
  });

  group('extractFontFaceRules — multiple rules', () {
    test('parses two @font-face blocks in one stylesheet', () {
      const css = '''
        @font-face {
          font-family: 'Inter';
          font-weight: 400;
          src: url(Inter.woff2);
        }
        @font-face {
          font-family: 'Inter';
          font-weight: 700;
          src: url(Inter-Bold.woff2);
        }
      ''';
      final rules = extractFontFaceRules(css);
      expect(rules, hasLength(2));
      expect(rules.map((r) => r.fontWeight), ['400', '700']);
    });
  });

  group('extractFontFaceRules — broken input', () {
    test('skips a @font-face block missing font-family', () {
      const css = '''
        @font-face {
          src: url(no-family.woff2);
        }
      ''';
      expect(extractFontFaceRules(css), isEmpty);
    });

    test('returns empty list when the CSS has no @font-face at all', () {
      const css = 'body { color: red; }';
      expect(extractFontFaceRules(css), isEmpty);
    });
  });
}
