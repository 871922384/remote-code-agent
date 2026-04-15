class ConversationEvent {
  const ConversationEvent._({
    required this.kind,
    this.role,
    this.text,
    this.label,
    this.message,
  });

  final String kind;
  final String? role;
  final String? text;
  final String? label;
  final String? message;

  const ConversationEvent.message({required String text, required String role})
      : this._(kind: 'message', role: role, text: text);

  const ConversationEvent.action({required String label})
      : this._(kind: 'action', label: label);

  const ConversationEvent.error({required String message})
      : this._(kind: 'error', message: message);
}
