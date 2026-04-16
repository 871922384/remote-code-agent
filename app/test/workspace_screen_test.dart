import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/app_scope.dart';
import 'package:agent_workbench/src/features/workspace/workspace_screen.dart';
import 'package:agent_workbench/src/models/conversation_summary.dart';

import 'support/fake_api_client.dart';

void main() {
  testWidgets(
      'renders the workspace header, conversation strip, and new conversation button',
      (tester) async {
    await tester.pumpWidget(
      WorkbenchScope(
        apiClient: FakeApiClient(
          conversations: const {
            '/Users/rex/code/alpha-api': [
              ConversationSummary(
                id: 'c-1',
                title: 'Fix billing callback',
                status: 'running',
                lastMessagePreview: 'Reading billing_controller.dart',
                projectId: '/Users/rex/code/alpha-api',
                activeRunId: 'run-1',
              ),
            ],
          },
        ),
        child: const MaterialApp(
          home: WorkspaceScreen(
            projectId: '/Users/rex/code/alpha-api',
            projectName: 'alpha-api',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha-api'), findsOneWidget);
    expect(find.text('New conversation'), findsOneWidget);
    expect(find.text('Running'), findsWidgets);
    expect(find.text('Reading billing_controller.dart'), findsWidgets);
  });
}
