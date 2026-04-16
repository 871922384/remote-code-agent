import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/conversation/conversation_screen.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';

void main() {
  testWidgets('shows product cards and the tdesign composer actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          title: 'Fix billing callback',
          events: const [
            ConversationEvent.message(
                text: 'Start with the callback path', role: 'user'),
            ConversationEvent.action(label: 'Reading billing_controller.dart'),
            ConversationEvent.error(message: 'API unavailable'),
          ],
          canConfirm: true,
          canInterrupt: true,
        ),
      ),
    );

    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.text('The model provider could not be reached right now.'),
        findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Interrupt'), findsOneWidget);
    expect(find.text('Continue the conversation'), findsOneWidget);
  });
}
