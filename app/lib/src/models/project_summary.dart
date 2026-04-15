class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.path,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String path;
  final bool pinned;
}
