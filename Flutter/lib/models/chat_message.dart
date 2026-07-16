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
}
