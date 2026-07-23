import 'dart:typed_data';

import 'package:farvixo_all/features/tools/engine/engines/audio_wav_engines.dart';
import 'package:farvixo_all/features/tools/engine/engines/media_extra_engines.dart';
import 'package:farvixo_all/features/tools/engine/tool_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a tiny mono 16-bit PCM WAV with the given samples.
Uint8List wav(List<int> samples, {int sampleRate = 8000}) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  final body = data.buffer.asUint8List();
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
  h.setUint16(22, 1, Endian.little);
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, sampleRate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  h.setUint32(40, body.length, Endian.little);
  final out = BytesBuilder()
    ..add(h.buffer.asUint8List())
    ..add(body);
  return out.toBytes();
}

/// Reads back the 16-bit samples from a produced WAV (44-byte header).
List<int> samplesOf(Uint8List bytes) {
  final data = ByteData.sublistView(bytes, 44);
  return [
    for (var i = 0; i + 1 < data.lengthInBytes; i += 2)
      data.getInt16(i, Endian.little),
  ];
}

ToolInput fileInput(Uint8List bytes,
        {String name = 'test.wav',
        String? text,
        Map<String, Object?> options = const {}}) =>
    ToolInput(
      files: [ToolFile(name: name, bytes: bytes)],
      text: text,
      options: options,
    );

Future<ToolResult> run(ToolEngine engine, ToolInput input) => engine.run(
      input,
      onProgress: (_, _) {},
      isCanceled: () => false,
    );

void main() {
  group('AudioReverseEngine', () {
    test('reverses sample order', () async {
      final result =
          await run(AudioReverseEngine(), fileInput(wav([10, 20, 30, 40])));
      expect(samplesOf(result.bytes!), [40, 30, 20, 10]);
    });

    test('rejects non-WAV input', () async {
      final junk = Uint8List.fromList(List.filled(64, 7));
      expect(
        () => run(AudioReverseEngine(), fileInput(junk, name: 'x.wav')),
        throwsA(isA<ToolFailure>()),
      );
    });
  });

  group('VolumeBoostEngine', () {
    test('doubles amplitude with clipping', () async {
      final result = await run(
        VolumeBoostEngine(),
        fileInput(wav([100, -200, 30000]), options: {'gain': '2x'}),
      );
      expect(samplesOf(result.bytes!), [200, -400, 32767]);
    });
  });

  group('AudioCutterEngine', () {
    test('cuts the requested range', () async {
      // 8000 Hz → each sample is 1/8000 s; cut 0.000125-0.000375 = samples 1..2.
      final result = await run(
        AudioCutterEngine(),
        fileInput(wav([1, 2, 3, 4]), text: '0.000125-0.000375'),
      );
      expect(samplesOf(result.bytes!), [2, 3]);
    });

    test('rejects a malformed range', () async {
      expect(
        () => run(AudioCutterEngine(), fileInput(wav([1, 2]), text: 'abc')),
        throwsA(isA<ToolFailure>()),
      );
    });
  });

  group('AudioMergerEngine', () {
    test('concatenates matching WAVs', () async {
      final input = ToolInput(files: [
        ToolFile(name: 'a.wav', bytes: wav([1, 2])),
        ToolFile(name: 'b.wav', bytes: wav([3, 4])),
      ]);
      final result = await run(AudioMergerEngine(), input);
      expect(samplesOf(result.bytes!), [1, 2, 3, 4]);
    });

    test('rejects mismatched sample rates', () async {
      final input = ToolInput(files: [
        ToolFile(name: 'a.wav', bytes: wav([1, 2])),
        ToolFile(name: 'b.wav', bytes: wav([3, 4], sampleRate: 44100)),
      ]);
      expect(() => run(AudioMergerEngine(), input),
          throwsA(isA<ToolFailure>()));
    });
  });

  group('AudioNormalizerEngine', () {
    test('scales the peak toward full scale', () async {
      final result =
          await run(AudioNormalizerEngine(), fileInput(wav([1000, -500])));
      final out = samplesOf(result.bytes!);
      expect(out.first, closeTo(31129, 40)); // 32767 * 0.95
      expect(out.last, closeTo(-15564, 40));
    });
  });

  group('SubtitleToolsEngine', () {
    final srt = '1\n00:00:01,000 --> 00:00:02,500\nHello\n';

    test('converts SRT to VTT', () async {
      final result = await run(
        SubtitleToolsEngine(),
        fileInput(Uint8List.fromList(srt.codeUnits),
            name: 'subs.srt', options: {'op': 'Convert SRT → VTT'}),
      );
      final text = String.fromCharCodes(result.bytes!);
      expect(text, startsWith('WEBVTT'));
      expect(text, contains('00:00:01.000 --> 00:00:02.500'));
    });

    test('shifts timestamps forward', () async {
      final result = await run(
        SubtitleToolsEngine(),
        fileInput(Uint8List.fromList(srt.codeUnits),
            name: 'subs.srt',
            text: '1.5',
            options: {'op': 'Shift forward'}),
      );
      final text = String.fromCharCodes(result.bytes!);
      expect(text, contains('00:00:02,500 --> 00:00:04,000'));
    });
  });
}
