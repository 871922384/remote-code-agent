import 'package:flutter/material.dart';

import '../../models/conversation_summary.dart';
import 'conversation_strip_item.dart';

class ConversationStrip extends StatelessWidget {
  const ConversationStrip({
    super.key,
    required this.conversations,
  });

  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ConversationStripItem(
            conversation: conversations[index],
          );
        },
      ),
    );
  }
}
