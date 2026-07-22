import 'dart:convert';
import 'dart:math';

import '../tool_engine.dart';
import 'engine_util.dart';

/// ============================================================================
/// DEVELOPER TOOL ENGINES — pure Dart, fully offline.
/// ============================================================================

/// URL percent-encoding encoder / decoder.
class UrlCodecEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Text or URL component…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Direction',
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
    if (raw.isEmpty) throw const ToolFailure('Enter something to convert.');
    onProgress(null, 'Converting');
    try {
      final out = (input.option<String>('mode') ?? 'Encode') == 'Decode'
          ? Uri.decodeComponent(raw)
          : Uri.encodeComponent(raw);
      return ToolResult.text(out, summary: 'URL ${input.option<String>('mode')?.toLowerCase() ?? 'encode'}d');
    } on FormatException {
      throw const ToolFailure('That is not valid percent-encoded text.');
    }
  }
}

const _htmlEscapes = {
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
};

/// HTML entity encoder / decoder.
class HtmlEntityEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'HTML or plain text…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Direction',
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
    if (raw.isEmpty) throw const ToolFailure('Enter something to convert.');
    onProgress(null, 'Converting');
    if ((input.option<String>('mode') ?? 'Encode') == 'Decode') {
      var out = raw;
      _htmlEscapes.forEach((k, v) => out = out.replaceAll(v, k));
      out = out
          .replaceAllMapped(RegExp(r'&#(\d+);'),
              (m) => String.fromCharCode(int.parse(m.group(1)!)))
          .replaceAll('&nbsp;', ' ');
      return ToolResult.text(out, summary: 'Entities decoded');
    }
    var out = raw;
    _htmlEscapes.forEach((k, v) => out = out.replaceAll(k, v));
    return ToolResult.text(out, summary: 'Entities encoded');
  }
}

/// Decode a JWT (header + payload, no signature verification).
class JwtDecodeEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Decode JWT',
        needsText: true,
        textHint: 'Paste a JWT (xxx.yyy.zzz)…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    final parts = raw.split('.');
    if (parts.length < 2) {
      throw const ToolFailure('Not a JWT — expected header.payload.signature.');
    }
    onProgress(null, 'Decoding');
    String decodePart(String part) {
      final normalized = base64Url.normalize(part);
      return utf8.decode(base64Url.decode(normalized));
    }

    try {
      const enc = JsonEncoder.withIndent('  ');
      final header = enc.convert(jsonDecode(decodePart(parts[0])));
      final payload = enc.convert(jsonDecode(decodePart(parts[1])));
      String expNote = '';
      final map = jsonDecode(decodePart(parts[1]));
      if (map is Map && map['exp'] is num) {
        final exp = DateTime.fromMillisecondsSinceEpoch(
            (map['exp'] as num).toInt() * 1000);
        expNote = exp.isBefore(DateTime.now()) ? ' • token EXPIRED' : ' • valid until $exp';
      }
      return ToolResult.text('HEADER\n$header\n\nPAYLOAD\n$payload',
          summary: 'Decoded (signature not verified)$expNote');
    } catch (_) {
      throw const ToolFailure('Could not decode — is this a valid JWT?');
    }
  }
}

/// Colour converter: HEX or rgb() input → HEX / RGB / HSL.
class ColorConvertEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: '#7C3AED or rgb(124, 58, 237)…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter a colour.');
    onProgress(null, 'Converting');
    final (r, g, b) = _parse(raw);
    final hex =
        '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
    final (h, s, l) = _rgbToHsl(r, g, b);
    return ToolResult.text(
      'HEX  $hex\nRGB  rgb($r, $g, $b)\nHSL  hsl($h, $s%, $l%)',
      summary: hex,
    );
  }

  (int, int, int) _parse(String raw) {
    final hexMatch = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$')
        .firstMatch(raw.replaceAll(' ', ''));
    if (hexMatch != null) {
      var h = hexMatch.group(1)!;
      if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
      final v = int.parse(h, radix: 16);
      return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
    }
    final rgbMatch =
        RegExp(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(raw);
    if (rgbMatch != null) {
      int c(int i) => int.parse(rgbMatch.group(i)!).clamp(0, 255);
      return (c(1), c(2), c(3));
    }
    throw const ToolFailure('Use #RRGGBB or rgb(r, g, b) format.');
  }

  (int, int, int) _rgbToHsl(int r8, int g8, int b8) {
    final r = r8 / 255, g = g8 / 255, b = b8 / 255;
    final maxC = [r, g, b].reduce(max), minC = [r, g, b].reduce(min);
    final l = (maxC + minC) / 2;
    double h = 0, s = 0;
    if (maxC != minC) {
      final d = maxC - minC;
      s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC);
      if (maxC == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (maxC == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h /= 6;
    }
    return ((h * 360).round(), (s * 100).round(), (l * 100).round());
  }
}

/// Unix timestamp ↔ human date (auto-detects direction).
class TimestampEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: '1720000000 or 2026-07-20 14:30…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter a timestamp or a date.');
    onProgress(null, 'Converting');

    final digits = int.tryParse(raw);
    if (digits != null) {
      // Seconds vs milliseconds heuristic.
      final ms = raw.length >= 13 ? digits : digits * 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return ToolResult.text(
        'Local   $dt\nUTC     ${dt.toUtc()}\nISO     ${dt.toUtc().toIso8601String()}',
        summary: 'Epoch → date',
      );
    }
    final dt = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (dt == null) {
      throw const ToolFailure(
          'Could not parse. Use an epoch number or YYYY-MM-DD [HH:MM].');
    }
    final secs = dt.millisecondsSinceEpoch ~/ 1000;
    return ToolResult.text(
      'Seconds       $secs\nMilliseconds  ${dt.millisecondsSinceEpoch}',
      summary: 'Date → epoch',
    );
  }
}

/// Number base converter (binary / octal / decimal / hex → all).
class NumberBaseEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'e.g. 255 or FF or 11111111…',
        choice: ToolChoiceSpec(
          optionKey: 'from',
          label: 'Input base',
          options: ['Decimal', 'Hex', 'Binary', 'Octal'],
          defaultValue: 'Decimal',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = (input.text ?? '').trim().replaceAll(RegExp(r'^0[xXbBoO]'), '');
    if (raw.isEmpty) throw const ToolFailure('Enter a number.');
    onProgress(null, 'Converting');
    final radix = switch (input.option<String>('from')) {
      'Hex' => 16,
      'Binary' => 2,
      'Octal' => 8,
      _ => 10,
    };
    final value = int.tryParse(raw, radix: radix);
    if (value == null) {
      throw ToolFailure('"$raw" is not valid for that base.');
    }
    return ToolResult.text(
      'Decimal  $value\n'
      'Hex      0x${value.toRadixString(16).toUpperCase()}\n'
      'Binary   ${value.toRadixString(2)}\n'
      'Octal    ${value.toRadixString(8)}',
      summary: 'Base conversion',
    );
  }
}

/// Roman numerals ↔ numbers (auto-detects direction).
class RomanEngine extends LocalToolEngine {
  static const _pairs = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'),
    (90, 'XC'), (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'),
    (4, 'IV'), (1, 'I'),
  ];

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'e.g. 2026 or MMXXVI…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim().toUpperCase() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter a number or Roman numeral.');
    onProgress(null, 'Converting');

    final n = int.tryParse(raw);
    if (n != null) {
      if (n < 1 || n > 3999) {
        throw const ToolFailure('Roman numerals cover 1 – 3999.');
      }
      var rest = n;
      final buf = StringBuffer();
      for (final (v, sym) in _pairs) {
        while (rest >= v) {
          buf.write(sym);
          rest -= v;
        }
      }
      return ToolResult.text(buf.toString(), summary: '$n in Roman numerals');
    }

    if (!RegExp(r'^[MDCLXVI]+$').hasMatch(raw)) {
      throw const ToolFailure('Enter digits or Roman letters (MDCLXVI).');
    }
    const values = {'M': 1000, 'D': 500, 'C': 100, 'L': 50, 'X': 10, 'V': 5, 'I': 1};
    var total = 0;
    for (var i = 0; i < raw.length; i++) {
      final v = values[raw[i]]!;
      final next = i + 1 < raw.length ? values[raw[i + 1]]! : 0;
      total += v < next ? -v : v;
    }
    return ToolResult.text('$total', summary: '$raw as a number');
  }
}

/// CSV → JSON (first row is treated as headers).
class CsvToJsonEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Paste CSV (first row = headers)…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Paste CSV data.');
    onProgress(null, 'Parsing CSV');
    await yieldFrame();
    final lines =
        raw.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) {
      throw const ToolFailure('Need a header row plus at least one data row.');
    }
    final headers = _splitCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cells = _splitCsvLine(line);
      rows.add({
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < cells.length ? cells[i] : '',
      });
    }
    const enc = JsonEncoder.withIndent('  ');
    return ToolResult.text(enc.convert(rows),
        summary: '${rows.length} rows × ${headers.length} columns');
  }

  static List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }
}

/// JSON array of objects → CSV.
class JsonToCsvEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Paste a JSON array of objects…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    if (raw.isEmpty) throw const ToolFailure('Paste JSON data.');
    onProgress(null, 'Converting');
    await yieldFrame();
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      throw const ToolFailure('That is not valid JSON.');
    }
    if (data is! List || data.isEmpty || data.any((e) => e is! Map)) {
      throw const ToolFailure('Expected a JSON array of objects.');
    }
    final headers = <String>{};
    for (final row in data) {
      headers.addAll((row as Map).keys.map((k) => k.toString()));
    }
    String cell(Object? v) {
      final s = v == null ? '' : v.toString();
      return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final buf = StringBuffer()..writeln(headers.map(cell).join(','));
    for (final row in data) {
      buf.writeln(headers.map((h) => cell((row as Map)[h])).join(','));
    }
    return ToolResult.text(buf.toString().trimRight(),
        summary: '${data.length} rows × ${headers.length} columns');
  }
}

/// Minimal Markdown → HTML (headings, bold, italic, code, links, lists).
class MarkdownHtmlEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Paste Markdown…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste Markdown text.');
    onProgress(null, 'Converting');
    await yieldFrame();

    String inline(String s) => s
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>')
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>')
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => '<a href="${m[2]}">${m[1]}</a>');

    final out = <String>[];
    var inList = false;
    for (final line in raw.split('\n')) {
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      final li = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (li != null) {
        if (!inList) {
          out.add('<ul>');
          inList = true;
        }
        out.add('  <li>${inline(li[1]!)}</li>');
        continue;
      }
      if (inList) {
        out.add('</ul>');
        inList = false;
      }
      if (h != null) {
        final level = h[1]!.length;
        out.add('<h$level>${inline(h[2]!)}</h$level>');
      } else if (line.trim().isEmpty) {
        out.add('');
      } else {
        out.add('<p>${inline(line)}</p>');
      }
    }
    if (inList) out.add('</ul>');
    return ToolResult.text(out.join('\n'), summary: 'Markdown → HTML');
  }
}

/// CSS minifier — strips comments and collapses whitespace.
class CssMinifyEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Minify',
        needsText: true,
        textHint: 'Paste CSS…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste CSS to minify.');
    onProgress(null, 'Minifying');
    final out = raw
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s*([{}:;,>])\s*'), (m) => m.group(1)!)
        .replaceAll(';}', '}')
        .trim();
    return ToolResult.text(out, summary: sizeDeltaSummary(raw.length, out.length));
  }
}

/// Strip HTML tags → plain readable text.
class HtmlStripEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Text',
        needsText: true,
        textHint: 'Paste HTML…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.trim().isEmpty) throw const ToolFailure('Paste HTML first.');
    onProgress(null, 'Stripping tags');
    var out = raw
        .replaceAll(RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    _htmlEscapes.forEach((k, v) => out = out.replaceAll(v, k));
    out = out.replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (out.isEmpty) throw const ToolFailure('No text content found.');
    return ToolResult.text(out, summary: 'Tags removed');
  }
}

/// Secure random token generator (hex / base64 / alphanumeric).
class TokenGeneratorEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'format',
          label: 'Format',
          options: ['Hex (32)', 'Hex (64)', 'Base64 (32)', 'Alphanumeric (24)'],
          defaultValue: 'Hex (32)',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Generating');
    final r = Random.secure();
    final format = input.option<String>('format') ?? 'Hex (32)';
    List<int> bytes(int n) => List<int>.generate(n, (_) => r.nextInt(256));
    final out = switch (format) {
      'Hex (64)' =>
        bytes(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'Base64 (32)' => base64Url.encode(bytes(24)),
      'Alphanumeric (24)' => () {
          const chars =
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
          return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
        }(),
      _ => bytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    };
    return ToolResult.text(out, summary: '$format token');
  }
}

/// Escape / unescape a JSON string literal.
class JsonEscapeEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'Text or an escaped JSON string…',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Direction',
          options: ['Escape', 'Unescape'],
          defaultValue: 'Escape',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text ?? '';
    if (raw.isEmpty) throw const ToolFailure('Enter something to convert.');
    onProgress(null, 'Converting');
    if ((input.option<String>('mode') ?? 'Escape') == 'Unescape') {
      try {
        final wrapped = raw.startsWith('"') ? raw : '"$raw"';
        return ToolResult.text(jsonDecode(wrapped) as String,
            summary: 'Unescaped');
      } catch (_) {
        throw const ToolFailure('Not a valid escaped JSON string.');
      }
    }
    final escaped = jsonEncode(raw);
    return ToolResult.text(escaped.substring(1, escaped.length - 1),
        summary: 'Escaped for JSON');
  }
}

/// Any small file → Base64 (for data URIs / embedding).
class FileToBase64Engine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Encode File',
        needsFile: true,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a file.');
    final file = input.files.first;
    if (file.sizeBytes > 2 * 1024 * 1024) {
      throw const ToolFailure('File is too large for Base64 (max 2 MB).');
    }
    onProgress(null, 'Encoding');
    await yieldFrame();
    return ToolResult.text(base64Encode(file.bytes),
        summary: '${file.name} • ${file.sizeBytes} bytes encoded');
  }
}

const _httpStatuses = {
  100: 'Continue', 101: 'Switching Protocols', 200: 'OK', 201: 'Created',
  202: 'Accepted', 204: 'No Content', 206: 'Partial Content',
  301: 'Moved Permanently', 302: 'Found', 304: 'Not Modified',
  307: 'Temporary Redirect', 308: 'Permanent Redirect',
  400: 'Bad Request — the server could not understand the request',
  401: 'Unauthorized — authentication is required',
  403: 'Forbidden — you do not have permission',
  404: 'Not Found — the resource does not exist',
  405: 'Method Not Allowed', 408: 'Request Timeout',
  409: 'Conflict', 410: 'Gone', 413: 'Payload Too Large',
  415: 'Unsupported Media Type',
  418: "I'm a teapot — an April Fools' joke from RFC 2324",
  422: 'Unprocessable Entity', 429: 'Too Many Requests — slow down',
  500: 'Internal Server Error — something broke on the server',
  501: 'Not Implemented', 502: 'Bad Gateway',
  503: 'Service Unavailable — server overloaded or down for maintenance',
  504: 'Gateway Timeout',
};

/// HTTP status code lookup (offline reference).
class HttpStatusEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Look Up',
        needsText: true,
        textHint: 'e.g. 404',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final code = int.tryParse(input.text?.trim() ?? '');
    if (code == null) throw const ToolFailure('Enter a status code like 404.');
    onProgress(null, 'Looking up');
    final meaning = _httpStatuses[code];
    final klass = switch (code ~/ 100) {
      1 => 'Informational',
      2 => 'Success',
      3 => 'Redirection',
      4 => 'Client error',
      5 => 'Server error',
      _ => 'Unknown class',
    };
    if (meaning == null) {
      return ToolResult.text('$code — $klass (uncommon / unofficial code)',
          summary: klass);
    }
    return ToolResult.text('$code $meaning', summary: klass);
  }
}

/// IPv4 subnet calculator (CIDR → network / broadcast / host range).
class IpSubnetEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'e.g. 192.168.1.10/24',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = input.text?.trim() ?? '';
    final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$')
        .firstMatch(raw);
    if (m == null) {
      throw const ToolFailure('Use CIDR notation, e.g. 192.168.1.10/24');
    }
    onProgress(null, 'Calculating');
    final octets = [1, 2, 3, 4].map((i) => int.parse(m.group(i)!)).toList();
    final prefix = int.parse(m.group(5)!);
    if (octets.any((o) => o > 255) || prefix > 32) {
      throw const ToolFailure('Octets must be ≤ 255 and prefix ≤ 32.');
    }
    final ip =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    final network = ip & mask;
    final broadcast = network | (~mask & 0xFFFFFFFF);
    final hosts = prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2;
    String dot(int v) =>
        '${(v >> 24) & 255}.${(v >> 16) & 255}.${(v >> 8) & 255}.${v & 255}';
    return ToolResult.text(
      'Network     ${dot(network)}\n'
      'Broadcast   ${dot(broadcast)}\n'
      'Netmask     ${dot(mask)}\n'
      'First host  ${dot(prefix >= 31 ? network : network + 1)}\n'
      'Last host   ${dot(prefix >= 31 ? broadcast : broadcast - 1)}\n'
      'Usable hosts $hosts',
      summary: '/$prefix • $hosts usable hosts',
    );
  }
}
