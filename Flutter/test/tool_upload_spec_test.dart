import 'package:farvixo_all/data/tools_data.dart';
import 'package:farvixo_all/features/upload/domain/tool_upload_spec.dart';
import 'package:farvixo_all/features/upload/domain/upload_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the upload registry against catalog drift.
///
/// Without these, renaming a tool in `tools_data.dart` silently orphans its
/// upload spec: the tool keeps working but stops accepting files, and nothing
/// fails until a user reports it.
void main() {
  final catalogIds = ToolsData.tools.map((t) => t.id).toSet();

  group('ToolUploadSpecs', () {
    test('covers exactly 71 tools', () {
      expect(ToolUploadSpecs.count, 71);
    });

    test('every spec points at a real catalog tool', () {
      final orphans = ToolUploadSpecs.byToolId.keys
          .where((id) => !catalogIds.contains(id))
          .toList();
      expect(orphans, isEmpty, reason: 'specs with no catalog tool: $orphans');
    });

    test('no file-consuming category is left uncovered', () {
      // Every PDF, Image, Video and Audio tool takes a file, with two
      // documented exceptions that capture their own input.
      const capturesOwnInput = {'screen-recorder', 'audio-recorder'};
      const producesFromText = {'text-to-speech'};

      final missing = ToolsData.tools
          .where((t) => const {'pdf', 'image', 'video', 'audio'}
              .contains(t.categoryId))
          .where((t) => !capturesOwnInput.contains(t.id))
          .where((t) => !producesFromText.contains(t.id))
          .where((t) => !ToolUploadSpecs.needsUpload(t.id))
          .map((t) => t.id)
          .toList();

      expect(missing, isEmpty, reason: 'file tools with no spec: $missing');
    });

    test('tools that take typed input have no spec', () {
      const typedInput = [
        'ai-chat',
        'uuid-generator',
        'password-generator',
        'case-converter',
        'bmi-calculator',
        'json-formatter',
      ];
      for (final id in typedInput) {
        expect(
          ToolUploadSpecs.needsUpload(id),
          isFalse,
          reason: '$id should not open the upload surface',
        );
      }
    });

    test('accept lists are lowercase and dotless', () {
      for (final entry in ToolUploadSpecs.byToolId.entries) {
        for (final ext in entry.value.accept) {
          expect(ext, ext.toLowerCase(), reason: '${entry.key}: $ext');
          expect(ext.startsWith('.'), isFalse, reason: '${entry.key}: $ext');
        }
      }
    });

    test('multiFile specs allow more than one file', () {
      for (final id in ToolUploadSpecs.multiFileTools) {
        expect(
          ToolUploadSpecs.of(id)!.maxFiles,
          greaterThan(1),
          reason: '$id is multiFile but caps at 1',
        );
      }
    });

    test('merge tools accept batches', () {
      for (final id in ['merge-pdf', 'video-merger', 'audio-merger']) {
        final spec = ToolUploadSpecs.of(id);
        expect(spec, isNotNull, reason: '$id has no spec');
        expect(spec!.multiFile, isTrue, reason: '$id must accept a batch');
      }
    });

    test('allows() honours the accept list', () {
      final pdf = ToolUploadSpecs.of('compress-pdf')!;
      expect(pdf.allows('pdf'), isTrue);
      expect(pdf.allows('PDF'), isTrue);
      expect(pdf.allows('docx'), isFalse);

      final any = ToolUploadSpecs.of('file-to-base64')!;
      expect(any.allows('zip'), isTrue, reason: 'empty accept means any file');
    });

    test('document tools hide camera and gallery sources', () {
      final pdf = ToolUploadSpecs.of('merge-pdf')!;
      final sources = pdf.sourcesFor(UploadPlatform.android);
      expect(sources, isNot(contains(UploadSource.camera)));
      expect(sources, isNot(contains(UploadSource.gallery)));
      expect(sources, contains(UploadSource.files));
    });

    test('image tools offer camera and gallery on mobile', () {
      final image = ToolUploadSpecs.of('background-remover')!;
      final sources = image.sourcesFor(UploadPlatform.android);
      expect(sources, contains(UploadSource.camera));
      expect(sources, contains(UploadSource.gallery));
    });

    test('desktop never offers camera', () {
      final image = ToolUploadSpecs.of('background-remover')!;
      final sources = image.sourcesFor(UploadPlatform.windows);
      expect(sources, isNot(contains(UploadSource.camera)));
    });
  });

  group('UploadSource platform matrix', () {
    test('drag & drop is unavailable on iOS', () {
      expect(
        UploadSource.dragDrop.availableOn(UploadPlatform.ios),
        isFalse,
        reason: 'no iOS drop implementation yet',
      );
    });

    test('folder upload is desktop-only', () {
      expect(UploadSource.folder.availableOn(UploadPlatform.windows), isTrue);
      expect(UploadSource.folder.availableOn(UploadPlatform.android), isFalse);
      expect(UploadSource.folder.availableOn(UploadPlatform.web), isFalse);
    });

    test('cloud sources are declared on every platform', () {
      for (final p in UploadPlatform.values) {
        expect(UploadSource.googleDrive.availableOn(p), isTrue);
      }
    });
  });
}
