import 'package:flutter/material.dart';

import '../../theme/workbench_tokens.dart';

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.text,
    required this.role,
  });

  final String text;
  final String role;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFEAF1FF) : WorkbenchTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WorkbenchTokens.softBorder),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
