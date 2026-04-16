class RealtimeEvent {
  const RealtimeEvent({
    required this.kind,
    required this.createdAt,
    this.conversationId,
    this.runId,
    this.payload = const {},
  });

  final String kind;
  final DateTime createdAt;
  final String? conversationId;
  final String? runId;
  final Map<String, dynamic> payload;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      conversationId: json['conversationId'] as String?,
      runId: json['runId'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
