import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:farvixo_all/features/tools/engine/engines/image_engines.dart';
import 'package:farvixo_all/features/tools/engine/engines/local_util_engines.dart';
import 'package:farvixo_all/features/tools/engine/engines/text_engines.dart';
import 'package:farvixo_all/features/tools/engine/tool_engine.dart';

/// No-op progress + never-canceled, for driving engines under test.
void _noProgress(double? f, String? s) {}
bool _notCanceled() => false;

Future<ToolResult> _run(ToolEngine engine, ToolInput input) =>
    engine.run(input, onProgress: _noProgress, isCanceled: _notCanceled);

void main() {
  group('Base64', () {
    test('encode + decode round-trip', () async {
      final enc = await _run(Base64Engine(),
          const ToolInput(text: 'Hello', options: {'mode': 'Encode'}));
      expect(enc.text, 'SGVsbG8=');
      final dec = await _run(Base64Engine(),
          ToolInput(text: enc.text!, options: const {'mode': 'Decode'}));
      expect(dec.text, 'Hello');
    });

    test('invalid base64 fails friendly', () async {
      expect(
        () => _run(Base64Engine(),
            const ToolInput(text: '@@@notbase64', options: {'mode': 'Decode'})),
        throwsA(isA<ToolFailure>()),
      );
    });
  });

  group('JSON', () {
    const src = '{"b":2,"a":1}';
    test('pretty print', () async {
      final r = await _run(JsonEngine(),
          const ToolInput(text: src, options: {'operation': 'Pretty Print'}));
      expect(r.text, contains('\n'));
      expect(r.text, contains('  "b": 2'));
    });
    test('minify', () async {
      final r = await _run(JsonEngine(),
          const ToolInput(text: src, options: {'operation': 'Minify'}));
      expect(r.text, '{"b":2,"a":1}');
    });
    test('validate valid', () async {
      final r = await _run(JsonEngine(),
          const ToolInput(text: src, options: {'operation': 'Validate'}));
      expect(r.text, contains('Valid JSON'));
    });
    test('validate invalid returns report (no throw)', () async {
      final r = await _run(JsonEngine(),
          const ToolInput(text: '{bad', options: {'operation': 'Validate'}));
      expect(r.text, contains('Invalid JSON'));
    });
    test('pretty on invalid throws', () async {
      expect(
        () => _run(JsonEngine(),
            const ToolInput(text: '{bad', options: {'operation': 'Pretty Print'})),
        throwsA(isA<ToolFailure>()),
      );
    });
  });

  group('Hash', () {
    test('sha256("abc") known vector', () async {
      final r = await _run(HashEngine(),
          const ToolInput(text: 'abc', options: {'algorithm': 'SHA256'}));
      expect(r.text,
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });
    test('md5("abc") known vector', () async {
      final r = await _run(HashEngine(),
          const ToolInput(text: 'abc', options: {'algorithm': 'MD5'}));
      expect(r.text, '900150983cd24fb0d6963f7d28e17f72');
    });
    test('sha512 length is 128 hex chars', () async {
      final r = await _run(HashEngine(),
          const ToolInput(text: 'abc', options: {'algorithm': 'SHA512'}));
      expect(r.text!.length, 128);
    });
  });

  group('UUID', () {
    test('is a valid v4 UUID and unique', () async {
      final a = await _run(UuidEngine(), const ToolInput());
      final b = await _run(UuidEngine(), const ToolInput());
      final re = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(re.hasMatch(a.text!), isTrue);
      expect(re.hasMatch(b.text!), isTrue);
      expect(a.text, isNot(b.text));
    });
  });

  group('Case converter', () {
    const t = 'hello world. foo bar';
    test('UPPERCASE', () async {
      final r = await _run(CaseConverterEngine(),
          const ToolInput(text: t, options: {'mode': 'UPPERCASE'}));
      expect(r.text, 'HELLO WORLD. FOO BAR');
    });
    test('Title Case', () async {
      final r = await _run(CaseConverterEngine(),
          const ToolInput(text: t, options: {'mode': 'Title Case'}));
      expect(r.text, 'Hello World. Foo Bar');
    });
    test('Sentence case', () async {
      final r = await _run(CaseConverterEngine(),
          const ToolInput(text: t, options: {'mode': 'Sentence case'}));
      expect(r.text, 'Hello world. Foo bar');
    });
  });

  group('Password', () {
    test('Strong is 16 chars', () async {
      final r = await _run(PasswordEngine(),
          const ToolInput(options: {'strength': 'Strong (16)'}));
      expect(r.text!.length, 16);
    });
    test('PIN is 6 digits only', () async {
      final r = await _run(PasswordEngine(),
          const ToolInput(options: {'strength': 'PIN (6 digits)'}));
      expect(r.text!.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(r.text!), isTrue);
    });
  });

  group('Lorem', () {
    test('3 paragraphs → 3 blocks', () async {
      final r = await _run(LoremEngine(),
          const ToolInput(options: {'count': '3 paragraphs'}));
      expect(r.text!.split('\n\n').length, 3);
    });
  });

  group('Text stats', () {
    test('counts words', () async {
      final r = await _run(
          TextStatsEngine(), const ToolInput(text: 'one two three'));
      expect(r.text, contains('Words:                3'));
    });
    test('empty throws', () async {
      expect(() => _run(TextStatsEngine(), const ToolInput(text: '   ')),
          throwsA(isA<ToolFailure>()));
    });
  });

  group('Image (pure-Dart engines)', () {
    // A small synthetic 120x80 PNG to feed the engines.
    Uint8List synthPng() {
      final image = img.Image(width: 120, height: 80);
      img.fill(image, color: img.ColorRgb8(10, 120, 200));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('compress returns JPEG bytes', () async {
      final r = await _run(
        ImageCompressEngine(),
        ToolInput(
          files: [ToolFile(name: 'x.png', bytes: synthPng())],
          options: const {'quality': 60},
        ),
      );
      expect(r.kind, ToolResultKind.file);
      expect(r.mime, 'image/jpeg');
      expect(r.bytes!.isNotEmpty, isTrue);
      expect(img.decodeImage(r.bytes!), isNotNull);
    });

    test('resize sets longest edge to target', () async {
      final r = await _run(
        ImageResizeEngine(),
        ToolInput(
          files: [ToolFile(name: 'x.png', bytes: synthPng())],
          options: const {'maxEdge': 90}, // engine clamps min edge to 64
        ),
      );
      expect(r.kind, ToolResultKind.file);
      final decoded = img.decodeImage(r.bytes!)!;
      expect(decoded.width, 90); // 120 (longest) → 90
    });
  });
}
