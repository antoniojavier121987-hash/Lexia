class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  final DateTime createdAt;

  ChatMessage({required this.role, required this.content, required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
