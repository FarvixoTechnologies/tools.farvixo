import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/chat_message.dart';
import '../../providers/app_providers.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/ai_chat_history_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_kit.dart';
import 'widgets/typing_indicator.dart';
import '../../theme/app_typography.dart';

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
          duration: Motion.base,
          curve: Motion.easeOut,
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
                    const BorderRadius.vertical(top: Radii.rPanel),
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
                      borderRadius: Radii.brPill,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          'Chat history',
                          style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
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
                              style: AppTypography.bodyLarge(context, color: p.textMuted),
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
                                  style: AppTypography.bodyLarge(
                                    context,
                                    color: p.textPrimary,
                                    weight: FontWeights.semibold,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTime(c.updatedAt),
                                  style: AppTypography.labelMedium(context, color: p.textMuted),
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
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, Insets.sm, Insets.md, Insets.sm),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final prev = i > 0 ? _messages[i - 1] : null;
                          return _MessageBubble(
                            message: msg,
                            groupedWithPrevious:
                                prev != null && prev.role == msg.role,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, Insets.xs, Insets.md, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md),
                        borderRadius: Radii.brPanel,
                        borderColor: _controller.text.trim().isNotEmpty
                            ? p.accent.withValues(alpha: .45)
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 50),
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !_sending,
                            style: AppTypography.bodyLarge(context, color: p.textPrimary),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              hintText: 'Ask me anything...',
                              hintStyle: AppTypography.bodyLarge(context, color: p.textMuted),
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Gaps.w12,
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
    return PressableScale(
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
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            sending ? Icons.stop_rounded : Icons.send_rounded,
            key: ValueKey(sending),
            color: AppColors.onAccent,
            size: 22,
          ),
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
                  borderRadius: Radii.brSheet,
                  boxShadow: [
                    BoxShadow(
                        color: p.accent.withValues(alpha: .5),
                        blurRadius: 30,
                        spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.onAccent, size: 44),
              ),
              const SizedBox(height: 22),
              Text('How can I help you today?',
                  style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold)),
              const SizedBox(height: 8),
              Text(
                'Write, summarize, translate, brainstorm — powered by AI.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(context, color: p.textSecondary).copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    PressableScale(
                      onTap: () => onSuggestion(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: .8),
                          borderRadius: Radii.brPill,
                          border: Border.all(
                              color: p.accent.withValues(alpha: .4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 13,
                                color: p.accent.withValues(alpha: .9)),
                            const SizedBox(width: Insets.sm),
                            Text(s,
                                style: AppTypography.bodySmall(context, color: p.textPrimary, weight: FontWeights.semibold)),
                          ],
                        ),
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

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    this.groupedWithPrevious = false,
  });

  final ChatMessage message;
  final bool groupedWithPrevious;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _copied = true);
    Future<void>.delayed(Motion.snackbar, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final p = AppPalette.of(context);
    final isUser = message.role == ChatRole.user;
    final showCursor =
        !isUser && message.isLoading && message.text.isNotEmpty;
    final isThinking = message.isLoading && message.text.isEmpty;
    // Only assistant, finished, non-empty messages are copyable.
    final canCopy = !isUser && !message.isLoading && message.text.isNotEmpty;

    final bubble = RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: 12),
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
            topLeft: const Radius.circular(Radii.card),
            topRight: const Radius.circular(Radii.card),
            bottomLeft: Radius.circular(isUser ? Radii.card : Radii.xs),
            bottomRight: Radius.circular(isUser ? Radii.xs : Radii.card),
          ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: p.accent.withValues(alpha: .28),
                    blurRadius: 16,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: isThinking
            ? const TypingIndicator()
            : SelectableText(
                showCursor ? '${message.text}▋' : message.text,
                style: AppTypography.titleSmall(context, color: isUser ? AppColors.onAccent : p.textPrimary).copyWith(height: 1.45),
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        top: widget.groupedWithPrevious ? 0 : Insets.xs,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _AssistantAvatar(
                  accent: p.accent,
                  visible: !widget.groupedWithPrevious,
                ),
                Gaps.w8,
              ],
              Flexible(child: bubble),
            ],
          ),
          if (canCopy)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: Insets.xs),
              child: _CopyChip(
                copied: _copied,
                accent: p.accent,
                color: p.textMuted,
                onTap: _copy,
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.accent, required this.visible});
  final Color accent;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(width: 28);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent,
          Color.lerp(accent, AppColors.brandMagenta, .55)!,
        ]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .4), blurRadius: 10),
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: AppColors.onAccent, size: 15),
    );
  }
}

class _CopyChip extends StatelessWidget {
  const _CopyChip({
    required this.copied,
    required this.accent,
    required this.color,
    required this.onTap,
  });

  final bool copied;
  final Color accent;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: Row(
          key: ValueKey(copied),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 13,
              color: copied ? AppColors.success : color,
            ),
            const SizedBox(width: Insets.xs),
            Text(
              copied ? 'Copied' : 'Copy',
              style: AppTypography.labelSmall(context, color: copied ? AppColors.success : color, weight: FontWeights.semibold),
            ),
          ],
        ),
      ),
    );
  }
}
