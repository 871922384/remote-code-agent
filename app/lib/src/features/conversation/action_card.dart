import 'package:flutter/material.dart';

import '../../theme/workbench_tokens.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkbenchTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkbenchTokens.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: WorkbenchTokens.running.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_suggest_outlined,
              color: WorkbenchTokens.running,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
