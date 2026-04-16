import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';
import 'package:agent_workbench/src/data/api_client.dart';
import 'package:agent_workbench/src/models/project_summary.dart';

import 'support/fake_api_client.dart';
import 'support/fake_connection_store.dart';

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
        connectionStore: FakeDaemonConnectionStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your workspaces'), findsOneWidget);
    expect(find.text('2 conversations running'), findsOneWidget);
    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets(
      'shows a connection error state when the daemon cannot be reached',
      (tester) async {
    await tester.pumpWidget(
      AgentWorkbenchApp(
        apiClient: FakeApiClient(
          projectsError: const ApiException('daemon unavailable'),
        ),
        connectionStore: FakeDaemonConnectionStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t reach the daemon.'), findsOneWidget);
    expect(find.text('Connection settings'), findsOneWidget);
  });
}
