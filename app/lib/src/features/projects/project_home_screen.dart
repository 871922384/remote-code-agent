import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../models/project_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../workspace/workspace_screen.dart';
import 'project_card.dart';

class ProjectHomeScreen extends StatelessWidget {
  const ProjectHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();
    return FutureBuilder<List<ProjectSummary>>(
      future: client.fetchProjects(),
      initialData: seededProjects,
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your workspaces', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Pick up where you left off', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return ProjectCard(
                          project: project,
                          onTap: () async {
                            final conversations = await client.fetchConversations(project.id);
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkspaceScreen(
                                  projectName: project.name,
                                  conversations: conversations,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
