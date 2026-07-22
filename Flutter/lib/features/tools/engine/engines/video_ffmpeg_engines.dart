/// FFmpeg-backed media engines — video convert/compress/trim/rotate/speed/
/// mute/merge/gif/thumbnail/watermark, audio extraction & conversion and
/// noise reduction. Runs fully on-device via ffmpeg_kit_flutter_new.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../tool_engine.dart';
import 'engine_util.dart';

const _videoExtensions = ['mp4', 'mov', 'mkv', 'webm', 'avi', '3gp', 'm4v'];
const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

/// Writes inputs to temp files, runs one ffmpeg invocation, returns the
/// output bytes. Cleans up all temp files even on failure.
Future<Uint8List> _runFfmpeg({
  required List<ToolFile> inputs,
  required String outName,
  required List<String> Function(List<String> inPaths, String outPath) args,
  required ToolProgress onProgress,
  required bool Function() isCanceled,
}) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final inPaths = <String>[];
  final outPath = '${dir.path}/fx_$stamp/$outName';
  await Directory('${dir.path}/fx_$stamp').create(recursive: true);

  try {
    onProgress(0.1, 'Preparing');
    for (var i = 0; i < inputs.length; i++) {
      final ext = inputs[i].name.contains('.')
          ? inputs[i].name.split('.').last
          : 'bin';
      final path = '${dir.path}/fx_$stamp/in_$i.$ext';
      await File(path).writeAsBytes(inputs[i].bytes, flush: true);
      inPaths.add(path);
    }
    if (isCanceled()) throw const ToolCanceled();

    onProgress(null, 'Processing with FFmpeg');
    final session = await FFmpegKit.executeWithArguments(
        ['-y', ...args(inPaths, outPath)]);
    if (isCanceled()) throw const ToolCanceled();

    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final log = (await session.getAllLogsAsString()) ?? '';
      final tail = log.length > 300 ? log.substring(log.length - 300) : log;
      throw ToolFailure('FFmpeg failed.\n$tail');
    }

    final outFile = File(outPath);
    if (!await outFile.exists()) {
      throw const ToolFailure('FFmpeg produced no output file.');
    }
    onProgress(0.95, 'Reading result');
    return Uint8List.fromList(await outFile.readAsBytes());
  } finally {
    try {
      await Directory('${dir.path}/fx_$stamp').delete(recursive: true);
    } catch (_) {/* temp cleanup is best-effort */}
  }
}

String _base(ToolInput input) => stripExtension(input.files.first.name);

/// Container/codec conversion with sane defaults.
class VideoConverterEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'target',
          label: 'Target format',
          options: ['mp4', 'mkv', 'mov'],
          defaultValue: 'mp4',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final target = (input.options['target'] as String?) ?? 'mp4';
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.$target',
      args: (ins, out) => ['-i', ins.first, '-preset', 'veryfast', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}.$target',
        mime: 'video/$target',
        summary: 'Converted to ${target.toUpperCase()}');
  }
}

/// H.264 CRF compression.
class VideoCompressorEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Compress Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'quality',
          label: 'Quality',
          options: ['High (larger)', 'Balanced', 'Small (lower)'],
          defaultValue: 'Balanced',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final crf = switch ((input.options['quality'] as String?) ?? 'Balanced') {
      'High (larger)' => '23',
      'Small (lower)' => '33',
      _ => '28',
    };
    final before = input.files.first.bytes.length;
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) => [
        '-i', ins.first,
        '-vcodec', 'libx264', '-crf', crf, '-preset', 'veryfast',
        '-acodec', 'aac', '-movflags', '+faststart',
        out,
      ],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-compressed.mp4',
        mime: 'video/mp4',
        summary: sizeDeltaSummary(before, bytes.length));
  }
}

/// Lossless keyframe trim: `start-end` seconds.
class VideoTrimmerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Trim Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        needsText: true,
        textHint: 'Range in seconds, e.g. 5-20',
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final m = RegExp(r'^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)$')
        .firstMatch((input.text ?? '').trim());
    if (m == null) throw const ToolFailure('Enter a range like 5-20 (seconds).');
    final start = m[1]!;
    final end = m[2]!;
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) =>
          ['-ss', start, '-to', end, '-i', ins.first, '-c', 'copy', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-trimmed.mp4',
        mime: 'video/mp4',
        summary: 'Trimmed ${start}s → ${end}s');
  }
}

/// First 15 s → animated GIF (480 px wide, 12 fps).
class VideoToGifEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Make GIF',
        needsFile: true,
        allowedExtensions: _videoExtensions,
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.gif',
      args: (ins, out) => [
        '-t', '15', '-i', ins.first,
        '-vf', 'fps=12,scale=480:-1:flags=lanczos',
        out,
      ],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}.gif',
        mime: 'image/gif',
        summary: 'GIF · first 15s · 480px @12fps');
  }
}

/// Animated GIF → shareable MP4.
class GifToVideoEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert to Video',
        needsFile: true,
        allowedExtensions: ['gif'],
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) => [
        '-i', ins.first,
        '-movflags', 'faststart', '-pix_fmt', 'yuv420p',
        '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
        out,
      ],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}.mp4',
        mime: 'video/mp4',
        summary: 'GIF converted to MP4');
  }
}

/// Concatenates clips (re-encoded so mixed sources work).
class VideoMergerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Merge Videos',
        needsFile: true,
        multiFile: true,
        allowedExtensions: _videoExtensions,
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    if (input.files.length < 2) {
      throw const ToolFailure('Select two or more videos.');
    }
    final n = input.files.length;
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) {
        final maps = [
          for (var i = 0; i < n; i++) '[$i:v][$i:a]',
        ].join();
        return [
          for (final p in ins) ...['-i', p],
          '-filter_complex', '${maps}concat=n=$n:v=1:a=1[v][a]',
          '-map', '[v]', '-map', '[a]',
          '-preset', 'veryfast',
          out,
        ];
      },
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: 'merged-$n-clips.mp4',
        mime: 'video/mp4',
        summary: '$n clips joined');
  }
}

/// Strips the audio track (stream copy — instant).
class VideoMuteEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Mute Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) => ['-i', ins.first, '-c', 'copy', '-an', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-muted.mp4',
        mime: 'video/mp4',
        summary: 'Audio track removed');
  }
}

/// Speed up / slow down (video + audio kept in sync).
class VideoSpeedEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Change Speed',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'speed',
          label: 'Speed',
          options: ['0.5x', '1.5x', '2x'],
          defaultValue: '1.5x',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final f = double.parse(
        ((input.options['speed'] as String?) ?? '1.5x').replaceAll('x', ''));
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) => [
        '-i', ins.first,
        '-filter_complex',
        '[0:v]setpts=PTS/$f[v];[0:a]atempo=$f[a]',
        '-map', '[v]', '-map', '[a]',
        '-preset', 'veryfast',
        out,
      ],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-${f}x.mp4',
        mime: 'video/mp4',
        summary: 'Speed ×$f');
  }
}

/// Rotates by 90° steps.
class VideoRotateEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Rotate Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'angle',
          label: 'Rotation',
          options: ['90° right', '90° left', '180°'],
          defaultValue: '90° right',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final angle = (input.options['angle'] as String?) ?? '90° right';
    final vf = switch (angle) {
      '90° left' => 'transpose=2',
      '180°' => 'transpose=1,transpose=1',
      _ => 'transpose=1',
    };
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.mp4',
      args: (ins, out) =>
          ['-i', ins.first, '-vf', vf, '-preset', 'veryfast', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-rotated.mp4',
        mime: 'video/mp4',
        summary: 'Rotated $angle');
  }
}

/// Pulls the audio track out of a video as M4A (AAC).
class AudioExtractorEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Extract Audio',
        needsFile: true,
        allowedExtensions: _videoExtensions,
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.m4a',
      args: (ins, out) => ['-i', ins.first, '-vn', '-c:a', 'aac', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}.m4a',
        mime: 'audio/mp4',
        summary: 'Audio extracted (AAC)');
  }
}

/// Grabs one frame as PNG at the requested second.
class VideoThumbnailEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Grab Thumbnail',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        needsText: true,
        textHint: 'Second to capture, e.g. 3',
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final at = (input.text ?? '').trim().isEmpty ? '1' : (input.text ?? '').trim();
    if (double.tryParse(at) == null) {
      throw const ToolFailure('Enter the capture time in seconds, e.g. 3');
    }
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.png',
      args: (ins, out) =>
          ['-ss', at, '-i', ins.first, '-frames:v', '1', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-thumb.png',
        mime: 'image/png',
        summary: 'Frame captured at ${at}s');
  }
}

/// Overlays a text watermark (rendered as PNG, no fontfile dependency).
class VideoWatermarkEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Watermark Video',
        needsFile: true,
        allowedExtensions: _videoExtensions,
        needsText: true,
        textHint: 'Watermark text, e.g. © Farvixo',
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final text = (input.text ?? '').trim();
    if (text.isEmpty) throw const ToolFailure('Enter the watermark text.');

    // Render the caption to a transparent PNG with the pure-Dart image pkg,
    // then let ffmpeg overlay it — avoids needing a bundled ttf for drawtext.
    final font = img.arial24;
    final w = (text.length * font.size * 0.6).round() + 16;
    final canvas = img.Image(width: w, height: font.size + 12, numChannels: 4);
    img.drawString(canvas, text,
        font: font, x: 9, y: 7, color: img.ColorRgba8(0, 0, 0, 160));
    img.drawString(canvas, text,
        font: font, x: 8, y: 6, color: img.ColorRgba8(255, 255, 255, 230));
    final wmBytes = Uint8List.fromList(img.encodePng(canvas));

    final bytes = await _runFfmpeg(
      inputs: [
        input.files.first,
        ToolFile(name: 'wm.png', bytes: wmBytes),
      ],
      outName: 'out.mp4',
      args: (ins, out) => [
        '-i', ins[0], '-i', ins[1],
        '-filter_complex', 'overlay=W-w-20:H-h-20',
        '-preset', 'veryfast',
        out,
      ],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-watermarked.mp4',
        mime: 'video/mp4',
        summary: 'Watermark overlaid');
  }
}

/// Any-to-any audio conversion (codecs bundled with ffmpeg core).
class AudioConverterEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert Audio',
        needsFile: true,
        allowedExtensions: _audioExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'target',
          label: 'Target format',
          options: ['m4a (AAC)', 'wav', 'flac'],
          defaultValue: 'm4a (AAC)',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final choice = (input.options['target'] as String?) ?? 'm4a (AAC)';
    final ext = choice.startsWith('m4a') ? 'm4a' : choice;
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.$ext',
      args: (ins, out) => ['-i', ins.first, out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}.$ext',
        mime: 'audio/$ext',
        summary: 'Converted to ${ext.toUpperCase()}');
  }
}

/// FFT denoise filter for voice recordings.
class NoiseReducerEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Reduce Noise',
        needsFile: true,
        allowedExtensions: _audioExtensions,
        choice: ToolChoiceSpec(
          optionKey: 'strength',
          label: 'Strength',
          options: ['Gentle', 'Standard', 'Strong'],
          defaultValue: 'Standard',
        ),
      );

  @override
  Future<ToolResult> run(ToolInput input,
      {required ToolProgress onProgress,
      required bool Function() isCanceled}) async {
    final nf = switch ((input.options['strength'] as String?) ?? 'Standard') {
      'Gentle' => '-20',
      'Strong' => '-30',
      _ => '-25',
    };
    final bytes = await _runFfmpeg(
      inputs: input.files,
      outName: 'out.m4a',
      args: (ins, out) =>
          ['-i', ins.first, '-af', 'afftdn=nf=$nf', '-c:a', 'aac', out],
      onProgress: onProgress,
      isCanceled: isCanceled,
    );
    return ToolResult.file(bytes,
        fileName: '${_base(input)}-denoised.m4a',
        mime: 'audio/mp4',
        summary: 'Noise reduced ($nf dB floor)');
  }
}
