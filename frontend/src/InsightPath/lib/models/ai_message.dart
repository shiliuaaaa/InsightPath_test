class AiMessage {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;

  AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

