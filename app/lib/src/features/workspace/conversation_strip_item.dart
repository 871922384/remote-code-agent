import 'package:flutter/material.dart';

import '../../models/conversation_summary.dart';
import '../../theme/workbench_tokens.dart';
import 'conversation_state_badge.dart';

class ConversationStripItem extends StatelessWidget {
  const ConversationStripItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        conversation.title.isEmpty ? '?' : conversation.title.characters.first;

    return InkWell(
      borderRadius: BorderRadius.circular(WorkbenchTokens.chipRadius),
      onTap: onTap,
      child: Container(
        width: 228,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WorkbenchTokens.surface,
          borderRadius: BorderRadius.circular(WorkbenchTokens.chipRadius),
          border: Border.all(color: WorkbenchTokens.softBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEAF1FF),
                  foregroundColor: WorkbenchTokens.primaryBlue,
                  child: Text(
                    initial.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: WorkbenchTokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConversationStateBadge(conversation.status),
            const SizedBox(height: 12),
            Text(
              conversation.lastMessagePreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
