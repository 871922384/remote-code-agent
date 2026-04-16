class ConversationEvent {
  const ConversationEvent._({
    required this.kind,
    required this.createdAt,
    this.role,
    this.text,
    this.label,
    this.message,
  });

  final String kind;
  final DateTime createdAt;
  final String? role;
  final String? text;
  final String? label;
  final String? message;

  ConversationEvent.message({
    required String text,
    required String role,
    DateTime? createdAt,
  }) : this._(
          kind: 'message',
          role: role,
          text: text,
          createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );

  ConversationEvent.action({
    required String label,
    DateTime? createdAt,
  }) : this._(
          kind: 'action',
          label: label,
          createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );

  ConversationEvent.error({
    required String message,
    DateTime? createdAt,
  }) : this._(
          kind: 'error',
          message: message,
          createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );

  factory ConversationEvent.fromMessageJson(Map<String, dynamic> json) {
    return ConversationEvent.message(
      text: json['text'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ConversationEvent? fromRunEventJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final payload = json['payload'] as Map<String, dynamic>? ?? const {};

    switch (json['kind']) {
      case 'run.action':
        return ConversationEvent.action(
          label: payload['label'] as String? ?? 'Working',
          createdAt: createdAt,
        );
      case 'run.error':
      case 'run.failed':
        return ConversationEvent.error(
          message: payload['message'] as String? ?? 'Unknown run error',
          createdAt: createdAt,
        );
      case 'message.created':
        return ConversationEvent.message(
          text: payload['text'] as String? ?? '',
          role: payload['role'] as String? ?? 'assistant',
          createdAt: createdAt,
        );
      default:
        return null;
    }
  }
}
