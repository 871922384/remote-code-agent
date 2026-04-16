class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.path,
    required this.lastSummary,
    required this.runningConversationCount,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String path;
  final String lastSummary;
  final int runningConversationCount;
  final bool pinned;

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      lastSummary: json['lastSummary'] as String? ??
          'No active conversations right now.',
      runningConversationCount:
          (json['runningConversationCount'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}
