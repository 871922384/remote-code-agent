import 'package:flutter/material.dart';

import 'src/app_scope.dart';
import 'src/data/api_client.dart';
import 'src/features/projects/project_home_screen.dart';
import 'src/theme/workbench_theme.dart';

class AgentWorkbenchApp extends StatelessWidget {
  const AgentWorkbenchApp({
    super.key,
    this.apiClient,
  });

  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return WorkbenchTheme(
      child: WorkbenchScope(
        apiClient: apiClient ?? ApiClient(),
        child: MaterialApp(
          title: 'Agent Workbench',
          theme: buildWorkbenchMaterialTheme(),
          home: const ProjectHomeScreen(),
        ),
      ),
    );
  }
}
