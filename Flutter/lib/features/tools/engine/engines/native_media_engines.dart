/// Native-capability engines: text-to-speech, speech-to-text, microphone
/// recording, on-device OCR and background removal (ML Kit).
///
/// All of these need a real device capability, so each guards the platform
/// and fails honestly where the capability does not exist (desktop/web).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Never _mobileOnly(String what) => throw ToolFailure(
    '$what runs on Android and iOS. On desktop/web use tools.farvixo.com.');

Future<String> _tempPath(String name) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name';
}

/// Speaks the entered text aloud with the platform voice.
class TextToSpeechEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Speak',
        needsText: true,
        textHint: 'Text to speak aloud',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'rate',
          label: 'Speed',
          options: ['Slow', 'Normal', 'Fast'],
          defaultValue: 'Normal',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final text = (input.text ?? '').trim();
    if (text.isEmpty) throw const ToolFailure('Enter the text to speak.');
    if (!_isMobile) _mobileOnly('Text-to-speech');

    final rate = switch ((input.options['rate'] as String?) ?? 'Normal') {
      'Slow' => 0.35,
      'Fast' => 0.65,
      _ => 0.5,
    };

    onProgress(null, 'Speaking');
    final tts = FlutterTts();
    try {
      await tts.setSpeechRate(rate);
      await tts.awaitSpeakCompletion(true);
      final result = await tts.speak(text);
      if (isCanceled()) {
        await tts.stop();
        throw const ToolCanceled();
      }
      if (result != 1) {
        throw const ToolFailure(
            'The platform voice engine refused to speak. Check the device TTS settings.');
      }
    } finally {
      // Leave the engine ready for the next run.
    }
    return ToolResult.text(text, summary: 'Spoken aloud · rate $rate');
  }
}

/// Live microphone transcription (on-device speech recognition).
class SpeechToTextEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Start Listening',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'window',
          label: 'Listen for',
          options: ['10 seconds', '20 seconds', '30 seconds'],
          defaultValue: '10 seconds',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (!_isMobile) _mobileOnly('Speech recognition');

    final secs = int.parse(
        ((input.options['window'] as String?) ?? '10 seconds').split(' ').first);

    final stt = SpeechToText();
    final ready = await stt.initialize();
    if (!ready) {
      throw const ToolFailure(
          'Speech recognition is unavailable — check microphone permission and '
          'that the device has a speech service installed.');
    }

    var transcript = '';
    onProgress(0.0, 'Listening… speak now');
    await stt.listen(
      onResult: (r) => transcript = r.recognizedWords,
      listenOptions: SpeechListenOptions(
        listenFor: Duration(seconds: secs),
        pauseFor: const Duration(seconds: 4),
      ),
    );

    // Poll until the listen window closes, keeping progress + cancel live.
    final steps = secs * 4;
    for (var i = 0; i < steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      onProgress((i + 1) / steps, 'Listening… speak now');
      if (isCanceled()) {
        await stt.cancel();
        throw const ToolCanceled();
      }
      if (!stt.isListening && i > 4) break;
    }
    await stt.stop();

    if (transcript.trim().isEmpty) {
      throw const ToolFailure(
          'Nothing was recognized. Try again closer to the microphone.');
    }
    return ToolResult.text(transcript,
        summary: '${transcript.trim().split(RegExp(r'\s+')).length} words');
  }
}

/// Records the microphone to an M4A (AAC) clip.
class AudioRecorderEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Record',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'length',
          label: 'Duration',
          options: ['10 seconds', '30 seconds', '60 seconds'],
          defaultValue: '10 seconds',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (!_isMobile) _mobileOnly('Microphone recording');

    final secs = int.parse(
        ((input.options['length'] as String?) ?? '10 seconds').split(' ').first);

    final rec = AudioRecorder();
    try {
      if (!await rec.hasPermission()) {
        throw const ToolFailure('Microphone permission was denied.');
      }
      final path = await _tempPath('recording.m4a');
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);

      final steps = secs * 4;
      for (var i = 0; i < steps; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        onProgress((i + 1) / steps, 'Recording…');
        if (isCanceled()) {
          await rec.stop();
          throw const ToolCanceled();
        }
      }
      final outPath = await rec.stop();
      if (outPath == null) {
        throw const ToolFailure('The recorder returned no file.');
      }
      final bytes = Uint8List.fromList(await File(outPath).readAsBytes());
      try {
        await File(outPath).delete();
      } catch (_) {/* best-effort cleanup */}
      return ToolResult.file(bytes,
          fileName:
              'recording-${DateTime.now().millisecondsSinceEpoch}.m4a',
          mime: 'audio/mp4',
          summary: '${secs}s · ${formatBytes(bytes.length)}');
    } finally {
      rec.dispose();
    }
  }
}

/// Extracts text from a photo with ML Kit (fully on-device).
class ImageOcrEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Text',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select an image.');
    if (!_isMobile) _mobileOnly('Image OCR');

    onProgress(0.2, 'Preparing image');
    final path = await _tempPath(input.files.first.name);
    await File(path).writeAsBytes(input.files.first.bytes, flush: true);
    if (isCanceled()) throw const ToolCanceled();

    onProgress(null, 'Recognizing text');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      final text = result.text.trim();
      if (text.isEmpty) {
        throw const ToolFailure(
            'No readable text found. Try a sharper, better-lit photo.');
      }
      return ToolResult.text(text,
          summary: '${result.blocks.length} text blocks recognized');
    } finally {
      await recognizer.close();
      try {
        await File(path).delete();
      } catch (_) {/* best-effort cleanup */}
    }
  }
}

/// Removes the background around people with ML Kit selfie segmentation.
class BackgroundRemoverEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Remove Background',
        needsFile: true,
        pickFromGallery: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    if (input.files.isEmpty) throw const ToolFailure('Select a photo.');
    if (!_isMobile) _mobileOnly('Background removal');

    onProgress(0.15, 'Preparing image');
    final decoded = img.decodeImage(input.files.first.bytes);
    if (decoded == null) {
      throw const ToolFailure('Unsupported or corrupt image file.');
    }
    final path = await _tempPath(input.files.first.name);
    await File(path).writeAsBytes(input.files.first.bytes, flush: true);
    if (isCanceled()) throw const ToolCanceled();

    onProgress(null, 'Segmenting (on-device model)');
    final segmenter = SelfieSegmenter(mode: SegmenterMode.single);
    try {
      final mask =
          await segmenter.processImage(InputImage.fromFilePath(path));
      if (mask == null) {
        throw const ToolFailure(
            'No person detected. This on-device model removes backgrounds '
            'around people; for objects use the web AI tools.');
      }
      if (isCanceled()) throw const ToolCanceled();

      onProgress(0.7, 'Applying mask');
      final out = img.Image(
          width: decoded.width, height: decoded.height, numChannels: 4);
      final mw = mask.width;
      final mh = mask.height;
      for (var y = 0; y < decoded.height; y++) {
        final my = (y * mh / decoded.height).floor().clamp(0, mh - 1);
        for (var x = 0; x < decoded.width; x++) {
          final mx = (x * mw / decoded.width).floor().clamp(0, mw - 1);
          final conf = mask.confidences[my * mw + mx];
          final src = decoded.getPixel(x, y);
          out.setPixelRgba(x, y, src.r.toInt(), src.g.toInt(), src.b.toInt(),
              (conf * 255).round().clamp(0, 255));
        }
      }

      onProgress(0.92, 'Encoding PNG');
      final bytes = Uint8List.fromList(img.encodePng(out));
      return ToolResult.file(bytes,
          fileName:
              '${stripExtension(input.files.first.name)}-transparent.png',
          mime: 'image/png',
          summary: 'Background removed (person segmentation)');
    } finally {
      segmenter.close();
      try {
        await File(path).delete();
      } catch (_) {/* best-effort cleanup */}
    }
  }
}
