import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/conversation/conversation_screen.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';

void main() {
  testWidgets('shows messages, action cards, error cards, and confirm/interruption controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          title: '修复支付回调',
          events: const [
            ConversationEvent.message(text: '先看为什么重复入库', role: 'user'),
            ConversationEvent.action(label: 'reading files'),
            ConversationEvent.error(message: 'API unavailable'),
          ],
          canConfirm: true,
          canInterrupt: true,
        ),
      ),
    );

    expect(find.text('reading files'), findsOneWidget);
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Interrupt'), findsOneWidget);
  });
}
