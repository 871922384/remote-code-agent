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
}
