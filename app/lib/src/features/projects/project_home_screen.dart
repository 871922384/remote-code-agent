import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../settings/connection_settings_screen.dart';
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
    WorkbenchScope.of(context).logger.info(
      'ui',
      'Refreshing projects',
      detailed: true,
    );
    setState(() {
      _projectsFuture = WorkbenchScope.of(context).apiClient.fetchProjects();
    });
  }

  Future<void> _openConnectionSettings() async {
    final scope = WorkbenchScope.of(context);
    scope.logger.info('ui', 'Opening connection settings', detailed: true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionSettingsScreen(
          initialUri: scope.daemonConnection.baseUri!,
          initialAuthToken: scope.daemonConnection.authToken,
          initialDetailedLogsEnabled:
              scope.daemonConnection.detailedLogsEnabled,
          logger: scope.logger,
          apiClientFactory: scope.apiClientFactory,
          onSave: scope.updateDaemonConnection,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshProjects();
  }

  @override
  Widget build(BuildContext context) {
    final scope = WorkbenchScope.of(context);
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your workspaces',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: _openConnectionSettings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick up where you left off',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: snapshot.hasError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Couldn\'t reach the daemon.',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  WorkbenchScope.of(context)
                                      .daemonConnection
                                      .baseUri!
                                      .toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _openConnectionSettings,
                                  child: const Text('Connection settings'),
                                ),
                              ],
                            ),
                          )
                        : projects.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No projects found',
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Daemon connected at'),
                                    const SizedBox(height: 4),
                                    Text(
                                      WorkbenchScope.of(context)
                                          .daemonConnection
                                          .baseUri!
                                          .toString(),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Make sure your Mac has project folders under ~/code.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: _refreshProjects,
                                      child: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              )
                        : ListView.separated(
                            itemCount: projects.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final project = projects[index];
                              return ProjectCard(
                                project: project,
                                onTap: () {
                              Navigator.of(context)
                                  .push(
                                        MaterialPageRoute(
                                          builder: (_) => WorkbenchScope(
                                            apiClient: scope.apiClient,
                                            logger: scope.logger,
                                            daemonConnection:
                                                scope.daemonConnection,
                                            updateDaemonConnection:
                                                scope.updateDaemonConnection,
                                            updateDetailedLogging:
                                                scope.updateDetailedLogging,
                                            apiClientFactory:
                                                scope.apiClientFactory,
                                            child: WorkspaceScreen(
                                              projectId: project.id,
                                              projectName: project.name,
                                            ),
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
