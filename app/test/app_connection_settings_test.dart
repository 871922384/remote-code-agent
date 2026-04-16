import 'package:agent_workbench/app.dart';
import 'package:agent_workbench/src/models/project_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_client.dart';
import 'support/fake_connection_store.dart';

String readDaemonUrlField(WidgetTester tester) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('daemon-url-field')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

String readDaemonTokenField(WidgetTester tester) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('daemon-token-field')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

void main() {
  testWidgets('migrates a saved localhost daemon url to the emulator host bridge',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      savedUri: Uri.parse('http://127.0.0.1:3333'),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri, {authToken, logger}) => FakeApiClient(
          authToken: authToken,
          logger: logger,
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

    expect(readDaemonUrlField(tester), 'http://10.0.2.2:3333');
  });

  testWidgets('loads the saved daemon url into the connection settings flow',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      savedUri: Uri.parse('http://192.168.0.8:3333'),
      savedAuthToken: 'secret-123',
      savedDetailedLogsEnabled: true,
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri, {authToken, logger}) => FakeApiClient(
          authToken: authToken,
          logger: logger,
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
    expect(readDaemonUrlField(tester), 'http://192.168.0.8:3333');
    expect(readDaemonTokenField(tester), 'secret-123');
    expect(
      tester.widget<SwitchListTile>(
        find.byKey(const Key('detailed-logs-switch')),
      ).value,
      isTrue,
    );
  });

  testWidgets('tests the daemon connection and shows success feedback',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      savedUri: Uri.parse('http://10.0.2.2:3333'),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri, {authToken, logger}) => FakeApiClient(
          authToken: authToken,
          logger: logger,
          healthCheckAuthToken: 'secret-123',
          healthOk: true,
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
      find.byKey(const Key('daemon-token-field')),
      'secret-123',
    );
    final testButton = find.widgetWithText(OutlinedButton, 'Test connection');
    await tester.ensureVisible(testButton);
    await tester.tap(testButton);
    await tester.pumpAndSettle();

    expect(find.text('Connection successful.'), findsOneWidget);
  });

  testWidgets('saves a new daemon url from the connection settings screen',
      (tester) async {
    final store = FakeDaemonConnectionStore(
      savedUri: Uri.parse('http://127.0.0.1:3333'),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        connectionStore: store,
        apiClientFactory: (baseUri, {authToken, logger}) => FakeApiClient(
          authToken: authToken,
          logger: logger,
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
      find.byKey(const Key('daemon-url-field')),
      'http://192.168.0.9:3333',
    );
    await tester.enterText(
      find.byKey(const Key('daemon-token-field')),
      'secret-456',
    );
    await tester.tap(find.byKey(const Key('detailed-logs-switch')));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(store.savedUri, Uri.parse('http://192.168.0.9:3333'));
    expect(store.savedAuthToken, 'secret-456');
    expect(store.savedDetailedLogsEnabled, isTrue);
    expect(store.saveCalls, 1);
    expect(find.text('Daemon URL saved.'), findsOneWidget);
  });
}
