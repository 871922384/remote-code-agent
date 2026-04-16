import 'package:flutter/material.dart';

import '../../models/conversation_event.dart';
import 'action_card.dart';
import 'error_card.dart';
import 'message_card.dart';

class ConversationTimeline extends StatelessWidget {
  const ConversationTimeline({super.key, required this.events});

  final List<ConversationEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event.kind == 'action') {
          return ActionCard(label: event.label!);
        }
        if (event.kind == 'error') {
          return ErrorCard(message: event.message!);
        }
        return MessageCard(text: event.text!, role: event.role!);
      },
    );
  }
}
