import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/scan_history_repository.dart';
import 'qr_export.dart';

/// File-backed export/import actions (share sheet + file picker). Thin plugin
/// wrapper over the pure [QrExport] serializer.
class QrExportIo {
  const QrExportIo._();

  /// Write [content] to a temp file and open the share sheet.
  static Future<void> _shareText(
    String content,
    String filename,
    String mime,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime)],
      subject: filename,
    );
  }

  /// Export the live history as a CSV file.
  static Future<void> exportCsv(ScanHistoryRepository repo) async {
    final entries = repo.query(const HistoryQuery(), pageSize: 0);
    final stamp = DateTime.now().toIso8601String().split('T').first;
    await _shareText(
      QrExport.toCsv(entries),
      'farvixo-scans-$stamp.csv',
      'text/csv',
    );
  }

  /// Export a full JSON backup (live + trashed, with flags).
  static Future<void> exportJsonBackup(ScanHistoryRepository repo) async {
    final all = [
      ...repo.query(const HistoryQuery(), pageSize: 0),
      ...repo.query(const HistoryQuery(includeDeleted: true), pageSize: 0),
    ];
    final stamp = DateTime.now().toIso8601String().split('T').first;
    await _shareText(
      QrExport.toJson(all),
      'farvixo-backup-$stamp.json',
      'application/json',
    );
  }

  /// Pick a JSON backup and merge it in. Returns the number imported, or null
  /// if the user cancelled.
  static Future<int?> importJsonBackup(ScanHistoryRepository repo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final content = file.bytes != null
        ? String.fromCharCodes(file.bytes!)
        : (file.path != null ? await File(file.path!).readAsString() : null);
    if (content == null) return null;
    final entries = QrExport.fromJson(content);
    return repo.importEntries(entries);
  }
}
