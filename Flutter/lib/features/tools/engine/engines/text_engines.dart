import 'dart:convert';
import 'dart:math';

import '../tool_engine.dart';

// ---------------------------------------------------------------------------
// Base64 — encode / decode
// ---------------------------------------------------------------------------
class Base64Engine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Enter text or Base64…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Mode',
          options: ['Encode', 'Decode'],
          defaultValue: 'Encode',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter some text first.');
    final decode = (input.option<String>('mode') ?? 'Encode') == 'Decode';

    if (decode) {
      try {
        final out = utf8.decode(base64.decode(raw.trim()));
        return ToolResult.text(out, summary: 'Base64 decoded');
      } catch (_) {
        throw const ToolFailure('That is not valid Base64 text.');
      }
    }
    return ToolResult.text(
      base64.encode(utf8.encode(raw)),
      summary: 'Base64 encoded',
    );
  }
}

// ---------------------------------------------------------------------------
// JSON — pretty / minify / validate (single decode, no duplicated parsing)
// ---------------------------------------------------------------------------
class JsonEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Format',
        needsText: true,
        textHint: 'Paste JSON…',
        choice: ToolChoiceSpec(
          optionKey: 'operation',
          label: 'Operation',
          options: ['Pretty Print', 'Minify', 'Validate'],
          defaultValue: 'Pretty Print',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Paste some JSON first.');
    final operation = input.option<String>('operation') ?? 'Pretty Print';

    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (e) {
      if (operation == 'Validate') {
        return ToolResult.text('✗ Invalid JSON\n\n${e.message}',
            summary: 'Validation failed');
      }
      throw ToolFailure('Invalid JSON: ${e.message}');
    }

    return switch (operation) {
      'Minify' => ToolResult.text(jsonEncode(parsed), summary: 'Minified'),
      'Validate' => ToolResult.text(
          '✓ Valid JSON (${parsed is List ? 'array' : parsed is Map ? 'object' : 'value'})',
          summary: 'Valid',
        ),
      _ => ToolResult.text(
          const JsonEncoder.withIndent('  ').convert(parsed),
          summary: 'Pretty printed',
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Text stats — words / characters / lines / paragraphs / reading time
// (one engine registered under the word- and character-counter slugs)
// ---------------------------------------------------------------------------
class TextStatsEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Analyze',
        needsText: true,
        textHint: 'Paste your text…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final text = input.text ?? '';
    if (text.trim().isEmpty) throw const ToolFailure('Enter some text first.');

    final words =
        text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final characters = text.length;
    final charactersNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    final lines = const LineSplitter().convert(text).length;
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length;
    final minutes = max(1, (words / 200).ceil());

    final report = StringBuffer()
      ..writeln('Words:                $words')
      ..writeln('Characters:           $characters')
      ..writeln('Characters (no space): $charactersNoSpaces')
      ..writeln('Lines:                $lines')
      ..writeln('Paragraphs:           $paragraphs')
      ..write('Reading time:         ~$minutes min');

    return ToolResult.text(report.toString(), summary: '$words words');
  }
}

// ---------------------------------------------------------------------------
// Case converter — UPPER / lower / Title / Sentence
// ---------------------------------------------------------------------------
class CaseConverterEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Enter text…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Case',
          options: ['UPPERCASE', 'lowercase', 'Title Case', 'Sentence case'],
          defaultValue: 'UPPERCASE',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final text = input.text ?? '';
    if (text.trim().isEmpty) throw const ToolFailure('Enter some text first.');
    final mode = input.option<String>('mode') ?? 'UPPERCASE';

    final out = switch (mode) {
      'lowercase' => text.toLowerCase(),
      'Title Case' => _titleCase(text),
      'Sentence case' => _sentenceCase(text),
      _ => text.toUpperCase(),
    };
    return ToolResult.text(out, summary: mode);
  }

  /// Capitalise the first letter of each word in place, preserving all
  /// whitespace and punctuation (Dart's split() drops separators).
  static String _titleCase(String text) => text.toLowerCase().replaceAllMapped(
        RegExp(r'(\w)(\w*)'),
        (m) => '${m[1]!.toUpperCase()}${m[2]}',
      );

  static String _sentenceCase(String text) {
    final lower = text.toLowerCase();
    return lower.replaceAllMapped(
      RegExp(r'(^\s*|[.!?]\s+)([a-z])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }
}

// ---------------------------------------------------------------------------
// Password generator — strength presets (length + charset), regenerable
// ---------------------------------------------------------------------------
class PasswordEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'strength',
          label: 'Strength',
          options: [
            'Strong (16)',
            'Max (24)',
            'Medium (12)',
            'PIN (6 digits)',
          ],
          defaultValue: 'Strong (16)',
        ),
      );

  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#\$%^&*()-_=+[]{}';

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final strength = input.option<String>('strength') ?? 'Strong (16)';
    final (int length, String pool) = switch (strength) {
      'Max (24)' => (24, _lower + _upper + _digits + _symbols),
      'Medium (12)' => (12, _lower + _upper + _digits),
      'PIN (6 digits)' => (6, _digits),
      _ => (16, _lower + _upper + _digits + _symbols),
    };

    final r = Random.secure();
    final password =
        List.generate(length, (_) => pool[r.nextInt(pool.length)]).join();
    return ToolResult.text(password, summary: '$length characters');
  }
}

// ---------------------------------------------------------------------------
// Lorem Ipsum generator — N random paragraphs, regenerable
// ---------------------------------------------------------------------------
class LoremEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'count',
          label: 'Length',
          options: ['1 paragraph', '3 paragraphs', '5 paragraphs', '10 paragraphs'],
          defaultValue: '3 paragraphs',
        ),
      );

  static const _words = [
    'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing',
    'elit', 'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore',
    'et', 'dolore', 'magna', 'aliqua', 'enim', 'ad', 'minim', 'veniam',
    'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi',
    'aliquip', 'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure',
    'in', 'reprehenderit', 'voluptate', 'velit', 'esse', 'cillum', 'fugiat',
    'nulla', 'pariatur', 'excepteur', 'sint', 'occaecat', 'cupidatat',
  ];

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final count =
        int.tryParse((input.option<String>('count') ?? '3 paragraphs').split(' ').first) ?? 3;
    final r = Random();

    String sentence() {
      final len = 8 + r.nextInt(8);
      final w = List.generate(len, (_) => _words[r.nextInt(_words.length)]);
      final s = w.join(' ');
      return '${s[0].toUpperCase()}${s.substring(1)}.';
    }

    String paragraph() =>
        List.generate(4 + r.nextInt(3), (_) => sentence()).join(' ');

    final text = List.generate(count, (_) => paragraph()).join('\n\n');
    return ToolResult.text(text, summary: '$count paragraph(s)');
  }
}
