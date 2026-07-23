import 'package:farvixo_all/features/tools/tool_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ToolHistoryEntry entry(String summary, {String? file}) => ToolHistoryEntry(
      summary: summary,
      fileName: file,
      timestamp: DateTime.now(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records and reloads newest-first', () async {
    await ToolHistoryStore.instance.add('merge-pdf', entry('First'));
    await ToolHistoryStore.instance.add('merge-pdf', entry('Second'));
    final list = await ToolHistoryStore.instance.load('merge-pdf');
    expect(list.map((e) => e.summary), ['Second', 'First']);
  });

  test('caps at maxEntries', () async {
    for (var i = 0; i < ToolHistoryStore.maxEntries + 5; i++) {
      await ToolHistoryStore.instance.add('hash-generator', entry('run $i'));
    }
    final list = await ToolHistoryStore.instance.load('hash-generator');
    expect(list.length, ToolHistoryStore.maxEntries);
    expect(list.first.summary, 'run ${ToolHistoryStore.maxEntries + 4}');
  });

  test('ignores an exact repeat of the last run', () async {
    await ToolHistoryStore.instance.add('uuid-generator', entry('same'));
    await ToolHistoryStore.instance.add('uuid-generator', entry('same'));
    final list = await ToolHistoryStore.instance.load('uuid-generator');
    expect(list.length, 1);
  });

  test('history is isolated per tool', () async {
    await ToolHistoryStore.instance.add('base64', entry('x'));
    final other = await ToolHistoryStore.instance.load('json-formatter');
    expect(other, isEmpty);
  });

  test('clear empties the history', () async {
    await ToolHistoryStore.instance.add('case-converter', entry('x'));
    await ToolHistoryStore.instance.clear('case-converter');
    expect(await ToolHistoryStore.instance.load('case-converter'), isEmpty);
  });

  test('ago() formats relative time', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final e = ToolHistoryEntry(
        summary: 's', timestamp: now.subtract(const Duration(hours: 2)));
    expect(e.ago(now), '2h ago');
  });
}
