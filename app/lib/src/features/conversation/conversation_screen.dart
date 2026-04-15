import 'package:flutter/material.dart';
import '../../models/conversation_event.dart';
import 'conversation_composer.dart';
import 'conversation_timeline.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.title,
    required this.events,
    required this.canConfirm,
    required this.canInterrupt,
  });

  final String title;
  final List<ConversationEvent> events;
  final bool canConfirm;
  final bool canInterrupt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(child: ConversationTimeline(events: events)),
          Row(
            children: [
              if (canConfirm) FilledButton(onPressed: () {}, child: const Text('Confirm')),
              const SizedBox(width: 12),
              if (canInterrupt) OutlinedButton(onPressed: () {}, child: const Text('Interrupt')),
            ],
          ),
          const ConversationComposer(),
        ],
      ),
    );
  }
}
