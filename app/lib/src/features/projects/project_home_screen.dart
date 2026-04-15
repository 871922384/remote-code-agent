import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../models/project_summary.dart';
import '../workspace/workspace_screen.dart';

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
          appBar: AppBar(title: const Text('Projects')),
          body: ListView(
            children: projects.map((project) {
              return ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(project.name),
                subtitle: Text(project.path),
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
            }).toList(),
          ),
        );
      },
    );
  }
}
