import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/app_scope.dart';
import 'package:agent_workbench/src/features/conversation/conversation_screen.dart';
import 'package:agent_workbench/src/logging/app_logger.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';

import 'support/fake_api_client.dart';

void main() {
  testWidgets('shows product cards and the tdesign composer actions',
      (tester) async {
    final client = FakeApiClient(
      timelines: {
        'conv-1': [
          ConversationEvent.message(
            text: 'Start with the callback path',
            role: 'user',
            createdAt: DateTime.parse('2026-04-16T10:00:00.000Z'),
          ),
          ConversationEvent.action(
            label: 'Reading billing_controller.dart',
            createdAt: DateTime.parse('2026-04-16T10:00:01.000Z'),
          ),
          ConversationEvent.error(
            message: 'API unavailable',
            createdAt: DateTime.parse('2026-04-16T10:00:02.000Z'),
          ),
        ],
      },
    );
    await tester.pumpWidget(
      WorkbenchScope(
        apiClient: client,
        logger: AppLogger(),
        child: const MaterialApp(
          home: ConversationScreen(
            title: 'Fix billing callback',
            projectId: '/Users/rex/code/alpha-api',
            conversationId: 'conv-1',
            canInterrupt: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.text('The model provider could not be reached right now.'),
        findsOneWidget);
    expect(find.text('Interrupt'), findsOneWidget);
    expect(find.text('Continue the conversation'), findsOneWidget);
  });

  testWidgets('keeps the conversation screen alive when realtime events fail',
      (tester) async {
    final client = FakeApiClient(
      events: Stream<Never>.error(StateError('websocket dropped')),
    );

    await tester.pumpWidget(
      WorkbenchScope(
        apiClient: client,
        logger: AppLogger(),
        child: const MaterialApp(
          home: ConversationScreen(
            title: 'Fix billing callback',
            projectId: '/Users/rex/code/alpha-api',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('websocket dropped'), findsOneWidget);
  });
}
