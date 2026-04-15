import 'package:flutter/material.dart';
import 'src/features/projects/project_home_screen.dart';

class AgentWorkbenchApp extends StatelessWidget {
  const AgentWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent Workbench',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB)),
      home: const ProjectHomeScreen(),
    );
  }
}
