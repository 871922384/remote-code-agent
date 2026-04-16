class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.lastMessagePreview,
    this.projectId,
    this.activeRunId,
    this.requiresConfirmation = false,
  });

  final String id;
  final String title;
  final String status;
  final String lastMessagePreview;
  final String? projectId;
  final String? activeRunId;
  final bool requiresConfirmation;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'idle',
      lastMessagePreview:
          json['lastMessagePreview'] as String? ?? 'No messages yet.',
      projectId: json['projectId'] as String?,
      activeRunId: json['activeRunId'] as String?,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
    );
  }
}
