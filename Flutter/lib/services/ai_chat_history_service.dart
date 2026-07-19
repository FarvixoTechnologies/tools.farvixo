import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

/// One saved AI conversation.
@immutable
class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  AiConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return AiConversation(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': [
          for (final m in messages)
            if (!m.isLoading)
              {
                'role': m.role == ChatRole.user ? 'user' : 'assistant',
                'text': m.text,
              },
        ],
      };

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final msgs = <ChatMessage>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final role = item['role'] == 'assistant'
            ? ChatRole.assistant
            : ChatRole.user;
        final text = item['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        msgs.add(ChatMessage(role: role, text: text));
      }
    }
    return AiConversation(
      id: json['id']?.toString() ?? _newId(),
      title: json['title']?.toString() ?? 'Chat',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: msgs,
    );
  }

  static String titleFromMessages(List<ChatMessage> messages) {
    ChatMessage? firstUser;
    for (final m in messages) {
      if (m.role == ChatRole.user) {
        firstUser = m;
        break;
      }
    }
    final t = firstUser?.text.trim() ?? 'New chat';
    if (t.length <= 42) return t;
    return '${t.substring(0, 42)}…';
  }

  factory AiConversation.empty() {
    return AiConversation(
      id: _newId(),
      title: 'New chat',
      updatedAt: DateTime.now(),
      messages: const [],
    );
  }

  static String _newId() {
    final r = Random();
    final ms = DateTime.now().microsecondsSinceEpoch;
    // Web (JS) bitwise ops are 32-bit; `1 << 32` is 0 and crashes nextInt.
    final suffix = r.nextInt(1 << 30).toRadixString(16);
    return 'c_${ms}_$suffix';
  }
}

/// Local persistence for AI chats (SharedPreferences JSON).
class AiChatHistoryService {
  AiChatHistoryService(this._prefs);

  final SharedPreferences _prefs;
  static const _kKey = 'ai_chat_conversations_v1';
  static const _maxConversations = 30;

  List<AiConversation> loadAll() {
    final raw = _prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final list = <AiConversation>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(AiConversation.fromJson(item));
        } else if (item is Map) {
          list.add(AiConversation.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (e) {
      debugPrint('AiChatHistoryService.loadAll: $e');
      return const [];
    }
  }

  Future<void> saveAll(List<AiConversation> conversations) async {
    final trimmed = conversations.take(_maxConversations).toList();
    final encoded = jsonEncode([for (final c in trimmed) c.toJson()]);
    await _prefs.setString(_kKey, encoded);
  }

  Future<AiConversation> upsert(AiConversation conversation) async {
    final all = List<AiConversation>.from(loadAll());
    final idx = all.indexWhere((c) => c.id == conversation.id);
    if (idx >= 0) {
      all[idx] = conversation;
    } else {
      all.insert(0, conversation);
    }
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await saveAll(all);
    return conversation;
  }

  Future<void> delete(String id) async {
    final all = loadAll().where((c) => c.id != id).toList();
    await saveAll(all);
  }

  Future<void> clear() async {
    await _prefs.remove(_kKey);
  }

  AiConversation createEmpty() => AiConversation.empty();
}
