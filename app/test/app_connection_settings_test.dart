import 'package:agent_workbench/app.dart';
import 'package:agent_workbench/src/models/project_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_client.dart';
import 'support/fake_connection_store.dart';

void main() {
  testWidgets('loads the saved daemon url into the connection settings flow',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      Uri.parse('http://192.168.0.8:3333'),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri) => FakeApiClient(
          projects: const [
            ProjectSummary(
              id: '/Users/rex/code/alpha-api',
              name: 'alpha-api',
              path: '/Users/rex/code/alpha-api',
              lastSummary: 'Reading billing_controller.dart',
              runningConversationCount: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Daemon URL'), findsOneWidget);
    expect(find.text('http://192.168.0.8:3333'), findsWidgets);
  });

  testWidgets('saves a new daemon url from the connection settings screen',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      Uri.parse('http://127.0.0.1:3333'),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri) => FakeApiClient(
          projects: const [
            ProjectSummary(
              id: '/Users/rex/code/alpha-api',
              name: 'alpha-api',
              path: '/Users/rex/code/alpha-api',
              lastSummary: 'Reading billing_controller.dart',
              runningConversationCount: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'http://192.168.0.9:3333',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.savedUri, Uri.parse('http://192.168.0.9:3333'));
    expect(store.saveCalls, 1);
  });
}
