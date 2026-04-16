import 'package:flutter/material.dart';

import '../../theme/workbench_tokens.dart';

class ConversationStateBadge extends StatelessWidget {
  const ConversationStateBadge(this.status, {super.key});

  final String status;

  String get label => switch (status) {
        'running' => 'Running',
        'waiting_confirmation' => 'Waiting',
        'completed' => 'Done',
        'failed' => 'Failed',
        _ => 'Idle',
      };

  Color get color => switch (status) {
        'running' => WorkbenchTokens.running,
        'waiting_confirmation' => WorkbenchTokens.waiting,
        'completed' => WorkbenchTokens.completed,
        'failed' => WorkbenchTokens.failed,
        _ => WorkbenchTokens.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
