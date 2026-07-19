import 'package:flutter/services.dart';

Future<String> saveSettingsExportFile(String json, String filename) async {
  await Clipboard.setData(ClipboardData(text: json));
  return 'Export copied to clipboard ($filename)';
}
