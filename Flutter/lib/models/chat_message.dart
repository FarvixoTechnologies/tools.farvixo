enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isLoading = false,
  });

  final ChatRole role;
  final String text;
  final bool isLoading;

  ChatMessage copyWith({
    ChatRole? role,
    String? text,
    bool? isLoading,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
