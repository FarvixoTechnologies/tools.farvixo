import 'package:farvixo_all/models/chat_message.dart';
import 'package:farvixo_all/services/ai_chat_history_service.dart';
import 'package:farvixo_all/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiService', () {
    test('sendMessage returns a non-empty reply', () async {
      final reply = await AiService().sendMessage('Hello Farvixo');
      expect(reply.trim(), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('streamChat completes with done', () async {
      final events = <AiChatEvent>[];
      await for (final ev in AiService().streamChat(
        history: const [ChatMessage(role: ChatRole.user, text: 'Hi')],
      )) {
        events.add(ev);
        if (events.length > 200) break;
      }
      expect(events, isNotEmpty);
      expect(
        events.any((e) => e is AiChatDone || e is AiChatDelta || e is AiChatError),
        isTrue,
      );
    }, timeout: const Timeout(Duration(seconds: 45)));
  });

  group('AiChatHistoryService', () {
    test('upsert and load roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc = AiChatHistoryService(prefs);
      final convo = AiConversation.empty().copyWith(
        title: 'Test chat',
        messages: const [
          ChatMessage(role: ChatRole.user, text: 'Hello'),
          ChatMessage(role: ChatRole.assistant, text: 'Hi there'),
        ],
      );
      await svc.upsert(convo);
      final loaded = svc.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.title, 'Test chat');
      expect(loaded.first.messages, hasLength(2));
    });
  });
}
