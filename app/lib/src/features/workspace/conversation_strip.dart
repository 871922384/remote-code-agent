import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';

class ConversationStrip extends StatelessWidget {
  const ConversationStrip({
    super.key,
    required this.conversations,
  });

  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final initial = conversation.title.isEmpty ? '?' : conversation.title.characters.first;
          return Chip(
            avatar: CircleAvatar(child: Text(initial)),
            label: Text(conversation.title),
          );
        },
      ),
    );
  }
}
