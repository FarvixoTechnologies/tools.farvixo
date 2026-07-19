import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveSettingsExportFile(String json, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(json);
  return 'Saved to ${file.path}';
}
