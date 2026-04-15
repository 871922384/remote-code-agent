import 'package:flutter/material.dart';
import '../../models/conversation_event.dart';

class ConversationTimeline extends StatelessWidget {
  const ConversationTimeline({super.key, required this.events});

  final List<ConversationEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event.kind == 'action') {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: Text(event.label!),
            ),
          );
        }
        if (event.kind == 'error') {
          return Card(
            color: const Color(0xFFFFE5E5),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(event.message!),
            ),
          );
        }
        return ListTile(
          title: Text(event.text!),
          subtitle: Text(event.role!),
        );
      },
    );
  }
}
