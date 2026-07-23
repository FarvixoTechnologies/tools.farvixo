/// Per-tool draft persistence — the text input and option choice survive
/// leaving the screen, killing the app, or an accidental back press.
///
/// Deliberately tiny: text + choice only (file bytes are too heavy to
/// persist here and are re-pickable in seconds). Local-only via
/// SharedPreferences; cloud draft sync can layer on top later.
library;

import 'package:shared_preferences/shared_preferences.dart';

class ToolDraft {
  const ToolDraft({this.text, this.choice});

  final String? text;
  final String? choice;

  bool get isEmpty => (text == null || text!.isEmpty) && choice == null;
}

class ToolDraftStore {
  ToolDraftStore._();
  static final instance = ToolDraftStore._();

  static String _textKey(String toolId) => 'tool_draft_text_$toolId';
  static String _choiceKey(String toolId) => 'tool_draft_choice_$toolId';

  Future<ToolDraft> load(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    return ToolDraft(
      text: prefs.getString(_textKey(toolId)),
      choice: prefs.getString(_choiceKey(toolId)),
    );
  }

  Future<void> save(String toolId, {String? text, String? choice}) async {
    final prefs = await SharedPreferences.getInstance();
    if (text == null || text.isEmpty) {
      await prefs.remove(_textKey(toolId));
    } else {
      await prefs.setString(_textKey(toolId), text);
    }
    if (choice == null) {
      await prefs.remove(_choiceKey(toolId));
    } else {
      await prefs.setString(_choiceKey(toolId), choice);
    }
  }

  Future<void> clear(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_textKey(toolId));
    await prefs.remove(_choiceKey(toolId));
  }
}
