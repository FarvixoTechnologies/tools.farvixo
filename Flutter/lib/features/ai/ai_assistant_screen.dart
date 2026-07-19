import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/chat_message.dart';
import '../../providers/app_providers.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/ai_chat_history_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

/// AI Assistant — streaming chat, multi-turn context, local history.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late AiConversation _conversation;
  bool _sending = false;
  String? _providerLabel;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _conversation = AiConversation.empty();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _persistIfEnabled() async {
    final save =
        ref.read(settingsPrefProvider(SettingsPrefKey.aiSaveHistory));
    if (!save) return;
    if (_messages.where((m) => !m.isLoading).isEmpty) return;
    _conversation = _conversation.copyWith(
      title: AiConversation.titleFromMessages(_messages),
      updatedAt: DateTime.now(),
      messages: List<ChatMessage>.from(
        _messages.where((m) => !m.isLoading),
      ),
    );
    await ref.read(aiChatHistoryProvider).upsert(_conversation);
  }

  void _startNewChat() {
    _cancelToken?.cancel();
    setState(() {
      _messages.clear();
      _sending = false;
      _providerLabel = null;
      _conversation = AiConversation.empty();
    });
  }

  void _loadConversation(AiConversation c) {
    _cancelToken?.cancel();
    setState(() {
      _conversation = c;
      _messages
        ..clear()
        ..addAll(c.messages);
      _sending = false;
      _providerLabel = null;
    });
    _scrollToBottom();
  }

  Future<void> _showHistorySheet() async {
    final history = ref.read(aiChatHistoryProvider).loadAll();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final p = AppPalette.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scroll) {
            return Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          'Chat history',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _startNewChat();
                          },
                          child: const Text('New chat'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Text(
                              'No saved chats yet',
                              style: TextStyle(color: p.textMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: scroll,
                            itemCount: history.length,
                            itemBuilder: (context, i) {
                              final c = history[i];
                              return ListTile(
                                leading: Icon(Icons.chat_bubble_outline,
                                    color: p.accent),
                                title: Text(
                                  c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTime(c.updatedAt),
                                  style: TextStyle(
                                      color: p.textMuted, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: p.textMuted),
                                  onPressed: () async {
                                    await ref
                                        .read(aiChatHistoryProvider)
                                        .delete(c.id);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      await _showHistorySheet();
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _loadConversation(c);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    final aiEnabled =
        ref.read(settingsPrefProvider(SettingsPrefKey.featureAi));
    if (!aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Assistant is disabled in Settings'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final streaming =
        ref.read(settingsPrefProvider(SettingsPrefKey.aiStreaming));

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _messages.add(
        const ChatMessage(
          role: ChatRole.assistant,
          text: '',
          isLoading: true,
        ),
      );
      _sending = true;
      _providerLabel = null;
    });
    _controller.clear();
    _scrollToBottom();

    final historyForApi = List<ChatMessage>.from(
      _messages.where((m) => !m.isLoading),
    );

    final buf = StringBuffer();
    try {
      await for (final ev in ref.read(aiServiceProvider).streamChat(
            history: historyForApi,
            cancelToken: _cancelToken,
            streaming: streaming,
          )) {
        if (!mounted) return;
        switch (ev) {
          case AiChatProviderInfo(:final provider, :final model):
            setState(() {
              _providerLabel =
                  model == null || model.isEmpty ? provider : '$provider · $model';
            });
          case AiChatDelta(:final text):
            buf.write(text);
            setState(() {
              final i = _messages.length - 1;
              if (i >= 0 && _messages[i].role == ChatRole.assistant) {
                _messages[i] = ChatMessage(
                  role: ChatRole.assistant,
                  text: buf.toString(),
                  isLoading: true,
                );
              }
            });
            _scrollToBottom();
          case AiChatError(:final message):
            setState(() {
              final i = _messages.length - 1;
              if (i >= 0 && _messages[i].role == ChatRole.assistant) {
                _messages[i] = ChatMessage(
                  role: ChatRole.assistant,
                  text: message,
                );
              }
              _sending = false;
            });
            await _persistIfEnabled();
            return;
          case AiChatDone():
            break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      final fallback = buf.toString().trim();
      setState(() {
        final i = _messages.length - 1;
        if (i >= 0 && _messages[i].role == ChatRole.assistant) {
          _messages[i] = ChatMessage(
            role: ChatRole.assistant,
            text: fallback.isNotEmpty
                ? fallback
                : 'Could not reach the AI server from this browser. '
                    'Add GEMINI_API_KEY in Flutter/.env, or ensure '
                    'tools.farvixo.com allows CORS — then try again.',
          );
        }
        _sending = false;
      });
      await _persistIfEnabled();
      return;
    }

    if (!mounted) return;
    setState(() {
      final i = _messages.length - 1;
      if (i >= 0 && _messages[i].role == ChatRole.assistant) {
        final finalText = buf.toString().trim().isEmpty
            ? 'Sorry, I could not generate a response.'
            : buf.toString();
        _messages[i] =
            ChatMessage(role: ChatRole.assistant, text: finalText);
      }
      _sending = false;
    });
    await _persistIfEnabled();
    _scrollToBottom();
  }

  void _stop() {
    _cancelToken?.cancel('user');
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'AI Assistant',
                    subtitle: _providerLabel ?? 'Powered by Farvixo AI',
                    emoji: '✨',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    actions: [
                      CircleGlassButton(
                        icon: Icons.history_rounded,
                        onTap: _showHistorySheet,
                      ),
                      const SizedBox(width: 8),
                      CircleGlassButton(
                        icon: Icons.add_comment_outlined,
                        onTap: _startNewChat,
                      ),
                      if (_messages.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        CircleGlassButton(
                          icon: Icons.delete_outline_rounded,
                          onTap: () async {
                            final id = _conversation.id;
                            _startNewChat();
                            await ref.read(aiChatHistoryProvider).delete(id);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? _EmptyChat(onSuggestion: _send)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          return _MessageBubble(message: _messages[i]);
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.border),
                        ),
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !_sending,
                          style: TextStyle(color: p.textPrimary),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 15),
                            hintText: 'Ask me anything...',
                            hintStyle: TextStyle(color: p.textMuted),
                            border: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SendButton(
                      accent: p.accent,
                      sending: _sending,
                      onTap: _sending ? _stop : () => _send(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.accent,
    required this.sending,
    required this.onTap,
  });
  final Color accent;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            accent,
            Color.lerp(accent, AppColors.brandMagenta, .55)!,
          ]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 16),
          ],
        ),
        child: Icon(
          sending ? Icons.stop_rounded : Icons.send_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final void Function(String) onSuggestion;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const suggestions = [
      'Write a professional email',
      'Summarize this text for me',
      'Translate to Hindi',
      'Generate ideas for a video',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    p.accent,
                    Color.lerp(p.accent, AppColors.brandMagenta, .55)!,
                  ]),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                        color: p.accent.withValues(alpha: .5),
                        blurRadius: 30,
                        spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 22),
              Text('How can I help you today?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Write, summarize, translate, brainstorm — powered by AI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, height: 1.5, color: p.textSecondary),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => onSuggestion(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: p.accent.withValues(alpha: .4)),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isUser = message.role == ChatRole.user;
    final showCursor =
        !isUser && message.isLoading && message.text.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(colors: [
                  p.accent,
                  Color.lerp(p.accent, AppColors.brandMagenta, .55)!,
                ])
              : null,
          color: isUser ? null : p.surface.withValues(alpha: .85),
          border: isUser ? null : Border.all(color: p.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: message.isLoading && message.text.isEmpty
            ? SizedBox(
                width: 36,
                height: 12,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: p.accent,
                  backgroundColor: Colors.transparent,
                ),
              )
            : SelectableText(
                showCursor ? '${message.text}▋' : message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: isUser ? Colors.white : p.textPrimary,
                ),
              ),
      ),
    );
  }
}
