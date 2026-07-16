import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/chat_message.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

/// AI Assistant — premium galaxy backdrop, gradient header, glowing empty
/// state with glass suggestion chips, accent chat bubbles and a glass composer.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await ref.read(aiServiceProvider).sendMessage(text);
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
      _sending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ---------- header ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'AI Assistant',
                    subtitle: 'Powered by Farvixo AI',
                    emoji: '✨',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    actions: [
                      if (_messages.isNotEmpty)
                        CircleGlassButton(
                          icon: Icons.delete_outline_rounded,
                          onTap: () => setState(_messages.clear),
                        ),
                    ],
                  ),
                ),
              ),
              // ---------- chat ----------
              Expanded(
                child: _messages.isEmpty
                    ? _EmptyChat(onSuggestion: _send)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return const _TypingIndicator();
                          }
                          return _MessageBubble(message: _messages[i]);
                        },
                      ),
              ),
              // ---------- composer ----------
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
                        onTap: _sending ? null : _send),
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
  const _SendButton(
      {required this.accent, required this.sending, required this.onTap});
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
        child: Icon(sending ? Icons.hourglass_top_rounded : Icons.send_rounded,
            color: Colors.white, size: 22),
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
        child: SelectableText(
          message.text,
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: .85),
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 36,
          height: 12,
          child: LinearProgressIndicator(
            minHeight: 3,
            color: p.accent,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
