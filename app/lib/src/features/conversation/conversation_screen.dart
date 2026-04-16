import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (canConfirm)
                  Expanded(
                    child: TDButton(
                      text: 'Confirm',
                      type: TDButtonType.fill,
                      onTap: () {},
                    ),
                  ),
                if (canConfirm && canInterrupt) const SizedBox(width: 12),
                if (canInterrupt)
                  Expanded(
                    child: TDButton(
                      text: 'Interrupt',
                      type: TDButtonType.outline,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
          const ConversationComposer(),
        ],
      ),
    );
  }
}
