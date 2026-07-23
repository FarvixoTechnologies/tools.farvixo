import 'package:farvixo_all/features/tools/tool_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and reloads a draft', () async {
    await ToolDraftStore.instance
        .save('json-formatter', text: '{"a":1}', choice: '2 spaces');
    final draft = await ToolDraftStore.instance.load('json-formatter');
    expect(draft.text, '{"a":1}');
    expect(draft.choice, '2 spaces');
    expect(draft.isEmpty, isFalse);
  });

  test('drafts are isolated per tool', () async {
    await ToolDraftStore.instance.save('hash-generator', text: 'abc');
    final other = await ToolDraftStore.instance.load('base64');
    expect(other.text, isNull);
    expect(other.isEmpty, isTrue);
  });

  test('clear removes the draft', () async {
    await ToolDraftStore.instance.save('uuid-generator', text: 'x');
    await ToolDraftStore.instance.clear('uuid-generator');
    final draft = await ToolDraftStore.instance.load('uuid-generator');
    expect(draft.isEmpty, isTrue);
  });

  test('empty text clears the stored key', () async {
    await ToolDraftStore.instance.save('case-converter', text: 'hello');
    await ToolDraftStore.instance.save('case-converter', text: '');
    final draft = await ToolDraftStore.instance.load('case-converter');
    expect(draft.text, isNull);
  });
}
