import 'package:flutter/material.dart';
import '../../models/project_summary.dart';
import '../../theme/workbench_tokens.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  final ProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WorkbenchTokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkbenchTokens.cardRadius),
        side: const BorderSide(color: WorkbenchTokens.softBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkbenchTokens.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(project.lastSummary, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(
                project.runningConversationCount == 1
                    ? '1 conversation running'
                    : '${project.runningConversationCount} conversations running',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
