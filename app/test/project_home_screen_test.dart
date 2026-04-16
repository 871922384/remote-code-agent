import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';
import 'package:agent_workbench/src/models/project_summary.dart';

import 'support/fake_api_client.dart';

void main() {
  testWidgets(
      'shows the premium project cards with running counts and summaries',
      (tester) async {
    await tester.pumpWidget(
      AgentWorkbenchApp(
        apiClient: FakeApiClient(
          projects: const [
            ProjectSummary(
              id: '/Users/rex/code/alpha-api',
              name: 'alpha-api',
              path: '/Users/rex/code/alpha-api',
              lastSummary: 'Reading billing_controller.dart',
              runningConversationCount: 2,
              pinned: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your workspaces'), findsOneWidget);
    expect(find.text('2 conversations running'), findsOneWidget);
    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
  });
}
