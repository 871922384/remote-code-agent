import 'package:flutter/material.dart';
import 'src/features/projects/project_home_screen.dart';
import 'src/theme/workbench_theme.dart';

class AgentWorkbenchApp extends StatelessWidget {
  const AgentWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkbenchTheme(
      child: MaterialApp(
        title: 'Agent Workbench',
        theme: buildWorkbenchMaterialTheme(),
        home: const ProjectHomeScreen(),
      ),
    );
  }
}
