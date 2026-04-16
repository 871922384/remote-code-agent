import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/project_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../workspace/workspace_screen.dart';
import 'project_card.dart';

class ProjectHomeScreen extends StatefulWidget {
  const ProjectHomeScreen({super.key});

  @override
  State<ProjectHomeScreen> createState() => _ProjectHomeScreenState();
}

class _ProjectHomeScreenState extends State<ProjectHomeScreen> {
  Future<List<ProjectSummary>>? _projectsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _projectsFuture ??= WorkbenchScope.of(context).apiClient.fetchProjects();
  }

  Future<void> _refreshProjects() async {
    setState(() {
      _projectsFuture = WorkbenchScope.of(context).apiClient.fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectSummary>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your workspaces',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick up where you left off',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return ProjectCard(
                          project: project,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => WorkspaceScreen(
                                      projectId: project.id,
                                      projectName: project.name,
                                    ),
                                  ),
                                )
                                .then((_) => _refreshProjects());
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
