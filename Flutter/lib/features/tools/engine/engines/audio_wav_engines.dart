/// On-device WAV audio engines — reverse, volume, speed, cut, ringtone,
/// merge, normalize and metadata. Pure Dart RIFF/PCM processing, no codecs.
///
/// Compressed formats (MP3/AAC/OGG) need a codec dependency (ffmpeg); these
/// engines accept WAV and fail honestly for anything else, so no tool ever
/// fakes output.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../tool_engine.dart';
import 'engine_util.dart';

/// Minimal PCM WAV container: parsed header + raw sample bytes.
class _Wav {
  _Wav({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.data,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final Uint8List data;

  int get blockAlign => channels * (bitsPerSample ~/ 8);
  int get frameCount => blockAlign == 0 ? 0 : data.length ~/ blockAlign;
  double get seconds => sampleRate == 0 ? 0 : frameCount / sampleRate;

  static _Wav parse(Uint8List bytes) {
    if (bytes.length < 44 ||
        latin1.decode(bytes.sublist(0, 4)) != 'RIFF' ||
        latin1.decode(bytes.sublist(8, 12)) != 'WAVE') {
      throw const ToolFailure(
          'Only WAV files are supported on-device. Convert MP3/AAC first.');
    }
    final view = ByteData.sublistView(bytes);
    int? channels;
    int? sampleRate;
    int? bits;
    Uint8List? data;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = latin1.decode(bytes.sublist(offset, offset + 4));
      final size = view.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ') {
        final format = view.getUint16(body, Endian.little);
        if (format != 1) {
          throw const ToolFailure(
              'Compressed WAV (non-PCM) is not supported yet.');
        }
        channels = view.getUint16(body + 2, Endian.little);
        sampleRate = view.getUint32(body + 4, Endian.little);
        bits = view.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        final end = (body + size).clamp(0, bytes.length).toInt();
        data = Uint8List.sublistView(bytes, body, end);
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }

    if (channels == null || sampleRate == null || bits == null || data == null) {
      throw const ToolFailure('Corrupt WAV file: missing fmt/data chunk.');
    }
    if (bits != 8 && bits != 16) {
      throw ToolFailure('$bits-bit WAV is not supported (use 8 or 16 bit).');
    }
    return _Wav(
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bits,
      data: data,
    );
  }

  /// Serializes a standard 44-byte-header PCM WAV.
  Uint8List encode({int? sampleRateOverride, Uint8List? dataOverride}) {
    final rate = sampleRateOverride ?? sampleRate;
    final body = dataOverride ?? data;
    final byteRate = rate * blockAlign;
    final out = BytesBuilder();
    final h = ByteData(44);

    void ascii(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        h.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    h.setUint32(4, 36 + body.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    h.setUint32(40, body.length, Endian.little);
    out.add(h.buffer.asUint8List());
    out.add(body);
    return out.toBytes();
  }
}

_Wav _wavInput(ToolInput input) {
  if (input.files.isEmpty) throw const ToolFailure('Select a WAV file.');
  return _Wav.parse(input.files.first.bytes);
}

String _wavName(ToolInput input, String suffix) =>
    '${stripExtension(input.files.first.name)}-$suffix.wav';

ToolResult _wavResult(Uint8List bytes, String fileName, String summary) =>
    ToolResult.file(bytes, fileName: fileName, mime: 'audio/wav',
        summary: summary);

const _wavSpecBase = ['wav'];

/// Plays the audio backwards.
class AudioReverseEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Reverse Audio',
        needsFile: true,
        allowedExtensions: _wavSpecBase,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(0.2, 'Parsing WAV');
    final wav = _wavInput(input);
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.6, 'Reversing frames');
    final block = wav.blockAlign;
    final frames = wav.frameCount;
    final out = Uint8List(frames * block);
    for (var i = 0; i < frames; i++) {
      final src = (frames - 1 - i) * block;
      out.setRange(i * block, (i + 1) * block, wav.data, src);
    }
    await yieldFrame();

    onProgress(0.9, 'Encoding');
    return _wavResult(
      wav.encode(dataOverride: out),
      _wavName(input, 'reversed'),
      'Reversed · ${wav.seconds.toStringAsFixed(1)}s',
    );
  }
}

/// Multiplies sample amplitude with clipping protection.
class VolumeBoostEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Boost Volume',
        needsFile: true,
        allowedExtensions: _wavSpecBase,
        choice: ToolChoiceSpec(
          optionKey: 'gain',
          label: 'Boost',
          options: ['1.5x', '2x', '3x'],
          defaultValue: '2x',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(0.2, 'Parsing WAV');
    final wav = _wavInput(input);
    final gain =
        double.parse(((input.options['gain'] as String?) ?? '2x')
            .replaceAll('x', ''));
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.6, 'Applying gain');
    final out = Uint8List.fromList(wav.data);
    if (wav.bitsPerSample == 16) {
      final view = ByteData.sublistView(out);
      for (var i = 0; i + 1 < out.length; i += 2) {
        final s = (view.getInt16(i, Endian.little) * gain)
            .round()
            .clamp(-32768, 32767)
            .toInt();
        view.setInt16(i, s, Endian.little);
      }
    } else {
      for (var i = 0; i < out.length; i++) {
        final s = (((out[i] - 128) * gain).round() + 128).clamp(0, 255).toInt();
        out[i] = s;
      }
    }
    await yieldFrame();

    onProgress(0.9, 'Encoding');
    return _wavResult(
      wav.encode(dataOverride: out),
      _wavName(input, 'boosted'),
      'Volume ×$gain (clipped safely)',
    );
  }
}

/// Changes playback speed by rewriting the sample rate (no pitch correction).
class AudioSpeedEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Change Speed',
        needsFile: true,
        allowedExtensions: _wavSpecBase,
        choice: ToolChoiceSpec(
          optionKey: 'speed',
          label: 'Speed',
          options: ['0.5x', '0.75x', '1.25x', '1.5x', '2x'],
          defaultValue: '1.5x',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(0.3, 'Parsing WAV');
    final wav = _wavInput(input);
    final factor = double.parse(
        ((input.options['speed'] as String?) ?? '1.5x').replaceAll('x', ''));
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.8, 'Retiming');
    final newRate = (wav.sampleRate * factor).round();
    return _wavResult(
      wav.encode(sampleRateOverride: newRate),
      _wavName(input, '${factor}x'),
      'Speed ×$factor · pitch shifts with speed',
    );
  }
}

/// Cuts a `start-end` range (seconds), e.g. "5-20".
class AudioCutterEngine extends LocalToolEngine {
  AudioCutterEngine({this.maxSeconds, this.suffix = 'cut'});

  /// When set, the cut is capped to this length (ringtone mode).
  final double? maxSeconds;
  final String suffix;

  @override
  ToolSpec get spec => ToolSpec(
        actionLabel: maxSeconds == null ? 'Cut Audio' : 'Make Ringtone',
        needsFile: true,
        needsText: true,
        allowedExtensions: _wavSpecBase,
        textHint: maxSeconds == null
            ? 'Range in seconds, e.g. 5-20'
            : 'Start second, e.g. 12 (max ${maxSeconds!.round()}s)',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(0.2, 'Parsing WAV');
    final wav = _wavInput(input);
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    double start;
    double end;
    final raw = (input.text ?? '').trim();
    if (maxSeconds != null) {
      start = double.tryParse(raw.isEmpty ? '0' : raw) ?? 0;
      end = start + maxSeconds!;
    } else {
      final m = RegExp(r'^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)$')
          .firstMatch(raw);
      if (m == null) {
        throw const ToolFailure('Enter a range like 5-20 (seconds).');
      }
      start = double.parse(m[1]!);
      end = double.parse(m[2]!);
    }
    if (end <= start) throw const ToolFailure('End must be after start.');
    if (start >= wav.seconds) {
      throw ToolFailure(
          'Start is past the end of the file (${wav.seconds.toStringAsFixed(1)}s).');
    }

    onProgress(0.7, 'Cutting');
    final block = wav.blockAlign;
    final startByte =
        ((start * wav.sampleRate).round() * block).clamp(0, wav.data.length).toInt();
    final endByte =
        ((end * wav.sampleRate).round() * block).clamp(0, wav.data.length).toInt();
    final cut = Uint8List.sublistView(wav.data, startByte, endByte);
    await yieldFrame();

    onProgress(0.9, 'Encoding');
    return _wavResult(
      wav.encode(dataOverride: Uint8List.fromList(cut)),
      _wavName(input, suffix),
      '${(endByte - startByte) ~/ (block * wav.sampleRate)}s clip · '
      '${start.toStringAsFixed(1)}s → ${(endByte / (block * wav.sampleRate)).toStringAsFixed(1)}s',
    );
  }
}

/// Concatenates WAV files that share one format.
class AudioMergerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Merge Audio',
        needsFile: true,
        multiFile: true,
        allowedExtensions: _wavSpecBase,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.length < 2) {
      throw const ToolFailure('Select two or more WAV files.');
    }
    onProgress(0.2, 'Parsing WAVs');
    final parsed = input.files.map((f) => _Wav.parse(f.bytes)).toList();
    final first = parsed.first;
    for (final w in parsed.skip(1)) {
      if (w.channels != first.channels ||
          w.sampleRate != first.sampleRate ||
          w.bitsPerSample != first.bitsPerSample) {
        throw const ToolFailure(
            'All files must share the same channels, sample rate and bit depth.');
      }
    }
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.7, 'Joining');
    final joined = BytesBuilder();
    for (final w in parsed) {
      joined.add(w.data);
    }
    await yieldFrame();

    onProgress(0.9, 'Encoding');
    return _wavResult(
      first.encode(dataOverride: joined.toBytes()),
      'merged-${input.files.length}-tracks.wav',
      '${input.files.length} tracks joined',
    );
  }
}

/// Scales the loudest peak to ~95% full scale.
class AudioNormalizerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Normalize',
        needsFile: true,
        allowedExtensions: _wavSpecBase,
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(0.2, 'Parsing WAV');
    final wav = _wavInput(input);
    if (wav.bitsPerSample != 16) {
      throw const ToolFailure('Normalize supports 16-bit WAV.');
    }
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.5, 'Scanning peak');
    final view = ByteData.sublistView(wav.data);
    var peak = 1;
    for (var i = 0; i + 1 < wav.data.length; i += 2) {
      final v = view.getInt16(i, Endian.little).abs();
      if (v > peak) peak = v;
    }
    final gain = (32767 * 0.95) / peak;
    await yieldFrame();
    if (isCanceled()) throw const ToolCanceled();

    onProgress(0.8, 'Applying gain');
    final out = Uint8List.fromList(wav.data);
    final outView = ByteData.sublistView(out);
    for (var i = 0; i + 1 < out.length; i += 2) {
      final s = (outView.getInt16(i, Endian.little) * gain)
          .round()
          .clamp(-32768, 32767)
          .toInt();
      outView.setInt16(i, s, Endian.little);
    }
    await yieldFrame();

    return _wavResult(
      wav.encode(dataOverride: out),
      _wavName(input, 'normalized'),
      'Peak normalized · gain ×${gain.toStringAsFixed(2)}',
    );
  }
}

/// Reads WAV header info, or ID3v2 tags from an MP3 — text report, no output file.
class AudioMetadataEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Read Metadata',
        needsFile: true,
        allowedExtensions: ['wav', 'mp3'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select an audio file.');
    final f = input.files.first;
    onProgress(0.4, 'Reading header');
    await yieldFrame();

    final name = f.name.toLowerCase();
    if (name.endsWith('.wav')) {
      final wav = _Wav.parse(f.bytes);
      final report = [
        'File: ${f.name}',
        'Format: PCM WAV',
        'Channels: ${wav.channels == 1 ? 'Mono' : '${wav.channels} (Stereo)'}',
        'Sample rate: ${wav.sampleRate} Hz',
        'Bit depth: ${wav.bitsPerSample}-bit',
        'Duration: ${wav.seconds.toStringAsFixed(2)} s',
        'Size: ${formatBytes(f.bytes.length)}',
      ].join('\n');
      return ToolResult.text(report, summary: 'WAV header parsed');
    }

    // MP3: ID3v2 text frames.
    final tags = _readId3v2(f.bytes);
    final report = [
      'File: ${f.name}',
      'Format: MP3',
      'Size: ${formatBytes(f.bytes.length)}',
      if (tags.isEmpty) 'No ID3v2 tags found.',
      for (final e in tags.entries) '${e.key}: ${e.value}',
    ].join('\n');
    return ToolResult.text(report,
        summary: tags.isEmpty ? 'No tags' : '${tags.length} tags found');
  }

  static const _frameNames = {
    'TIT2': 'Title',
    'TPE1': 'Artist',
    'TALB': 'Album',
    'TYER': 'Year',
    'TDRC': 'Year',
    'TCON': 'Genre',
    'TRCK': 'Track',
  };

  Map<String, String> _readId3v2(Uint8List bytes) {
    final tags = <String, String>{};
    if (bytes.length < 10 ||
        latin1.decode(bytes.sublist(0, 3)) != 'ID3') {
      return tags;
    }
    // Syncsafe tag size.
    final size = (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
    final end = (10 + size).clamp(0, bytes.length).toInt();
    var offset = 10;
    while (offset + 10 <= end) {
      final id = latin1.decode(bytes.sublist(offset, offset + 4));
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) break;
      final frameSize = (bytes[offset + 4] << 24) |
          (bytes[offset + 5] << 16) |
          (bytes[offset + 6] << 8) |
          bytes[offset + 7];
      if (frameSize <= 0 || offset + 10 + frameSize > end) break;
      final label = _frameNames[id];
      if (label != null && frameSize > 1) {
        final body = bytes.sublist(offset + 11, offset + 10 + frameSize);
        final value = utf8
            .decode(body.where((b) => b != 0).toList(), allowMalformed: true)
            .trim();
        if (value.isNotEmpty) tags[label] = value;
      }
      offset += 10 + frameSize;
    }
    return tags;
  }
}
