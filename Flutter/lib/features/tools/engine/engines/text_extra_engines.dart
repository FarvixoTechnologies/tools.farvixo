import 'dart:math';

import '../tool_engine.dart';
import 'engine_util.dart';

/// ============================================================================
/// TEXT TOOL ENGINES — pure Dart, fully offline.
/// ============================================================================

/// Compare two texts separated by a `---` line; reports added/removed lines.
class TextCompareEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Compare',
        needsText: true,
        textHint: 'Paste text A, then a line with ---, then text B',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    final parts = raw.split(RegExp(r'^\s*---\s*$', multiLine: true));
    if (parts.length < 2) {
      throw const ToolFailure(
          'Separate the two texts with a line containing only ---');
    }
    onProgress(null, 'Comparing');
    await yieldFrame();
    final a = parts[0].trim().split('\n');
    final b = parts.sublist(1).join('---').trim().split('\n');
    final setA = a.toSet();
    final setB = b.toSet();
    final removed = a.where((l) => !setB.contains(l)).toList();
    final added = b.where((l) => !setA.contains(l)).toList();

    if (removed.isEmpty && added.isEmpty) {
      return ToolResult.text('✓ The two texts have identical lines.',
          summary: 'No differences');
    }
    final buf = StringBuffer();
    for (final l in removed) {
      buf.writeln('− $l');
    }
    for (final l in added) {
      buf.writeln('+ $l');
    }
    return ToolResult.text(buf.toString().trimRight(),
        summary:
            '${removed.length} removed line(s), ${added.length} added line(s)');
  }
}

/// Reverse text by characters, words or lines.
class ReverseTextEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Reverse',
        needsText: true,
        textHint: 'Enter text to reverse…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Reverse',
          options: ['Characters', 'Words', 'Lines'],
          defaultValue: 'Characters',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter text to reverse.');
    onProgress(null, 'Reversing');
    final mode = input.option<String>('mode') ?? 'Characters';
    final out = switch (mode) {
      'Words' => raw.split(RegExp(r'\s+')).reversed.join(' '),
      'Lines' => raw.split('\n').reversed.join('\n'),
      _ => String.fromCharCodes(raw.runes.toList().reversed),
    };
    return ToolResult.text(out, summary: 'Reversed by ${mode.toLowerCase()}');
  }
}

/// Sort lines A→Z, Z→A, by length, or shuffle.
class SortLinesEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Sort',
        needsText: true,
        textHint: 'Paste lines to sort…',
        choice: ToolChoiceSpec(
          optionKey: 'order',
          label: 'Order',
          options: ['A → Z', 'Z → A', 'Shortest first', 'Longest first', 'Shuffle'],
          defaultValue: 'A → Z',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste lines to sort.');
    onProgress(null, 'Sorting');
    final lines = raw.split('\n');
    final order = input.option<String>('order') ?? 'A → Z';
    switch (order) {
      case 'Z → A':
        lines.sort((x, y) => y.toLowerCase().compareTo(x.toLowerCase()));
      case 'Shortest first':
        lines.sort((x, y) => x.length.compareTo(y.length));
      case 'Longest first':
        lines.sort((x, y) => y.length.compareTo(x.length));
      case 'Shuffle':
        lines.shuffle(Random());
      default:
        lines.sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
    }
    return ToolResult.text(lines.join('\n'),
        summary: '${lines.length} lines • $order');
  }
}

/// Remove duplicate lines while preserving first-seen order.
class DedupeLinesEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Remove Duplicates',
        needsText: true,
        textHint: 'Paste lines — duplicates will be removed…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste lines first.');
    onProgress(null, 'Scanning');
    final seen = <String>{};
    final out = <String>[];
    for (final l in raw.split('\n')) {
      if (seen.add(l)) out.add(l);
    }
    final removed = raw.split('\n').length - out.length;
    return ToolResult.text(out.join('\n'),
        summary: removed == 0
            ? 'No duplicates found'
            : '$removed duplicate line(s) removed');
  }
}

/// Clean text: collapse spaces, strip blank lines, or both.
class CleanTextEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Clean',
        needsText: true,
        textHint: 'Paste messy text…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Clean',
          options: ['Extra spaces', 'Blank lines', 'Both'],
          defaultValue: 'Both',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    var text = input.text ?? '';
    if (text.isEmpty) throw const ToolFailure('Paste text to clean.');
    onProgress(null, 'Cleaning');
    final before = text.length;
    final mode = input.option<String>('mode') ?? 'Both';
    if (mode != 'Blank lines') {
      text = text
          .split('\n')
          .map((l) => l.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
          .join('\n');
    }
    if (mode != 'Extra spaces') {
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    }
    return ToolResult.text(text,
        summary: '${before - text.length} characters removed');
  }
}

/// URL-friendly slug from any text.
class SlugifyEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Slugify',
        needsText: true,
        textHint: 'e.g. My Awesome Blog Post!',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter text to slugify.');
    onProgress(null, 'Slugifying');
    final slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.isEmpty) throw const ToolFailure('No usable characters for a slug.');
    return ToolResult.text(slug, summary: '${slug.length} characters');
  }
}

/// Join wrapped lines into a paragraph (space / nothing / comma separated).
class LineBreakRemoverEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Remove Breaks',
        needsText: true,
        textHint: 'Paste text with line breaks…',
        choice: ToolChoiceSpec(
          optionKey: 'sep',
          label: 'Join with',
          options: ['Space', 'Nothing', 'Comma'],
          defaultValue: 'Space',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste text first.');
    onProgress(null, 'Joining');
    final sep = switch (input.option<String>('sep')) {
      'Nothing' => '',
      'Comma' => ', ',
      _ => ' ',
    };
    final joined = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join(sep);
    return ToolResult.text(joined, summary: 'Line breaks removed');
  }
}

/// Text ↔ binary (UTF-8, space-separated bytes).
class BinaryTextEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Text, or binary like 01001000 01101001…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Direction',
          options: ['Text → Binary', 'Binary → Text'],
          defaultValue: 'Text → Binary',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter something to convert.');
    onProgress(null, 'Converting');
    final mode = input.option<String>('mode') ?? 'Text → Binary';
    if (mode == 'Binary → Text') {
      final groups = raw.split(RegExp(r'\s+'));
      final codes = <int>[];
      for (final g in groups) {
        final v = int.tryParse(g, radix: 2);
        if (v == null || v > 255) {
          throw ToolFailure('"$g" is not valid 8-bit binary.');
        }
        codes.add(v);
      }
      return ToolResult.text(String.fromCharCodes(codes),
          summary: '${codes.length} bytes decoded');
    }
    final bin = raw.runes
        .map((c) => c.toRadixString(2).padLeft(8, '0'))
        .join(' ');
    return ToolResult.text(bin, summary: '${raw.runes.length} characters encoded');
  }
}

const _morseTable = {
  'a': '.-', 'b': '-...', 'c': '-.-.', 'd': '-..', 'e': '.', 'f': '..-.',
  'g': '--.', 'h': '....', 'i': '..', 'j': '.---', 'k': '-.-', 'l': '.-..',
  'm': '--', 'n': '-.', 'o': '---', 'p': '.--.', 'q': '--.-', 'r': '.-.',
  's': '...', 't': '-', 'u': '..-', 'v': '...-', 'w': '.--', 'x': '-..-',
  'y': '-.--', 'z': '--..', '0': '-----', '1': '.----', '2': '..---',
  '3': '...--', '4': '....-', '5': '.....', '6': '-....', '7': '--...',
  '8': '---..', '9': '----.', '.': '.-.-.-', ',': '--..--', '?': '..--..',
  '!': '-.-.--', '/': '-..-.', '@': '.--.-.', '-': '-....-', '=': '-...-',
};

/// Morse code encoder / decoder.
class MorseEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Text, or morse like .... ..',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Direction',
          options: ['Text → Morse', 'Morse → Text'],
          defaultValue: 'Text → Morse',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter something to convert.');
    onProgress(null, 'Converting');
    final mode = input.option<String>('mode') ?? 'Text → Morse';
    if (mode == 'Morse → Text') {
      final reverse = {for (final e in _morseTable.entries) e.value: e.key};
      final words = raw.split(RegExp(r'\s{3,}|\s/\s|/'));
      final out = words.map((w) {
        return w
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => reverse[s] ?? '□')
            .join();
      }).join(' ');
      return ToolResult.text(out, summary: 'Morse decoded');
    }
    final out = raw.toLowerCase().split('').map((c) {
      if (c == ' ') return '/';
      return _morseTable[c] ?? '';
    }).where((s) => s.isNotEmpty).join(' ');
    if (out.isEmpty) throw const ToolFailure('No encodable characters found.');
    return ToolResult.text(out, summary: 'Morse encoded');
  }
}

/// ROT13 / Caesar cipher.
class CipherEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Apply Cipher',
        needsText: true,
        textHint: 'Enter text…',
        choice: ToolChoiceSpec(
          optionKey: 'shift',
          label: 'Cipher',
          options: ['ROT13', 'Caesar +3', 'Caesar −3'],
          defaultValue: 'ROT13',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter text first.');
    onProgress(null, 'Ciphering');
    final label = input.option<String>('shift') ?? 'ROT13';
    final shift = switch (label) {
      'Caesar +3' => 3,
      'Caesar −3' => -3,
      _ => 13,
    };
    final out = String.fromCharCodes(raw.runes.map((c) {
      if (c >= 65 && c <= 90) return 65 + ((c - 65 + shift) % 26 + 26) % 26;
      if (c >= 97 && c <= 122) return 97 + ((c - 97 + shift) % 26 + 26) % 26;
      return c;
    }));
    return ToolResult.text(out, summary: label);
  }
}

/// Extract emails, URLs, phone numbers or hashtags from any text.
class ExtractorEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract',
        needsText: true,
        textHint: 'Paste text to scan…',
        choice: ToolChoiceSpec(
          optionKey: 'what',
          label: 'Extract',
          options: ['Emails', 'URLs', 'Phone numbers', 'Hashtags'],
          defaultValue: 'Emails',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste text to scan.');
    onProgress(null, 'Scanning');
    final what = input.option<String>('what') ?? 'Emails';
    final regex = switch (what) {
      'URLs' => RegExp(r'https?://[^\s<>"]+'),
      'Phone numbers' => RegExp(r'(?:\+\d{1,3}[\s-]?)?(?:\(?\d{2,5}\)?[\s-]?)?\d{5,10}'),
      'Hashtags' => RegExp(r'#[A-Za-z0-9_]+'),
      _ => RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    };
    final found = regex
        .allMatches(raw)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.length > 3 || what == 'Hashtags')
        .toSet()
        .toList();
    if (found.isEmpty) {
      return ToolResult.text('Nothing found.',
          summary: '0 ${what.toLowerCase()}');
    }
    return ToolResult.text(found.join('\n'),
        summary: '${found.length} ${what.toLowerCase()} found');
  }
}

/// Word frequency — top 20 most used words.
class WordFrequencyEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Analyze',
        needsText: true,
        textHint: 'Paste text to analyze…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste text to analyze.');
    onProgress(null, 'Counting');
    await yieldFrame();
    final counts = <String, int>{};
    for (final m in RegExp(r"[A-Za-z0-9']+").allMatches(raw.toLowerCase())) {
      final w = m.group(0)!;
      counts[w] = (counts[w] ?? 0) + 1;
    }
    if (counts.isEmpty) throw const ToolFailure('No words found.');
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);
    final width = top.first.value.toString().length;
    final buf = StringBuffer();
    for (final e in top) {
      buf.writeln('${e.value.toString().padLeft(width)}×  ${e.key}');
    }
    return ToolResult.text(buf.toString().trimRight(),
        summary: '${counts.length} unique words');
  }
}

/// Find & replace: line 1 = find, line 2 = replace, rest = the text.
class FindReplaceEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Replace',
        needsText: true,
        textHint: 'Line 1: find • Line 2: replace • Line 3+: your text',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Match',
          options: ['Case sensitive', 'Ignore case'],
          defaultValue: 'Case sensitive',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final lines = (input.text ?? '').split('\n');
    if (lines.length < 3) {
      throw const ToolFailure(
          'Use 3+ lines: find text, replacement, then your content.');
    }
    final find = lines[0];
    if (find.isEmpty) throw const ToolFailure('Line 1 (find) is empty.');
    final replace = lines[1];
    final body = lines.sublist(2).join('\n');
    onProgress(null, 'Replacing');
    final ignoreCase =
        (input.option<String>('mode') ?? 'Case sensitive') == 'Ignore case';
    final pattern = RegExp(RegExp.escape(find), caseSensitive: !ignoreCase);
    final count = pattern.allMatches(body).length;
    return ToolResult.text(body.replaceAll(pattern, replace),
        summary: '$count replacement(s)');
  }
}

/// Repeat text N times.
class TextRepeaterEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Repeat',
        needsText: true,
        textHint: 'Text to repeat…',
        choice: ToolChoiceSpec(
          optionKey: 'times',
          label: 'Times',
          options: ['2×', '5×', '10×', '25×', '100×'],
          defaultValue: '5×',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter text to repeat.');
    onProgress(null, 'Repeating');
    final times =
        int.parse((input.option<String>('times') ?? '5×').replaceAll('×', ''));
    if (raw.length * times > 200000) {
      throw const ToolFailure('Result would be too large.');
    }
    return ToolResult.text(List.filled(times, raw).join('\n'),
        summary: '$times copies');
  }
}

const _ones = [
  '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
  'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
  'seventeen', 'eighteen', 'nineteen',
];
const _tens = [
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty',
  'ninety',
];

/// Number → words in both International and Indian numbering systems.
class NumberToWordsEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'e.g. 1250000',
        choice: ToolChoiceSpec(
          optionKey: 'system',
          label: 'System',
          options: ['International', 'Indian'],
          defaultValue: 'International',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = (input.text ?? '').replaceAll(',', '').trim();
    final n = int.tryParse(raw);
    if (n == null) throw const ToolFailure('Enter a whole number.');
    if (n.abs() > 999999999999999) {
      throw const ToolFailure('Number is too large (max 15 digits).');
    }
    onProgress(null, 'Converting');
    final system = input.option<String>('system') ?? 'International';
    final words = n == 0
        ? 'zero'
        : (n < 0 ? 'minus ' : '') +
            (system == 'Indian' ? _indian(n.abs()) : _intl(n.abs())).trim();
    return ToolResult.text(words, summary: '$system system');
  }

  static String _below1000(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) {
      return '${_tens[n ~/ 10]}${n % 10 != 0 ? '-${_ones[n % 10]}' : ''}';
    }
    return '${_ones[n ~/ 100]} hundred'
        '${n % 100 != 0 ? ' ${_below1000(n % 100)}' : ''}';
  }

  static String _intl(int n) {
    const units = [
      (1000000000000, 'trillion'),
      (1000000000, 'billion'),
      (1000000, 'million'),
      (1000, 'thousand'),
    ];
    var rest = n;
    final parts = <String>[];
    for (final (value, name) in units) {
      if (rest >= value) {
        parts.add('${_below1000(rest ~/ value)} $name');
        rest %= value;
      }
    }
    if (rest > 0) parts.add(_below1000(rest));
    return parts.join(' ');
  }

  static String _indian(int n) {
    const units = [
      (10000000000000, 'crore crore'), // guard for very large values
      (100000000000, 'kharab'),
      (1000000000, 'arab'),
      (10000000, 'crore'),
      (100000, 'lakh'),
      (1000, 'thousand'),
    ];
    var rest = n;
    final parts = <String>[];
    for (final (value, name) in units) {
      if (rest >= value) {
        final chunk = rest ~/ value;
        parts.add('${chunk < 100 ? _below1000(chunk) : _intl(chunk)} $name');
        rest %= value;
      }
    }
    if (rest > 0) parts.add(_below1000(rest));
    return parts.join(' ');
  }
}
