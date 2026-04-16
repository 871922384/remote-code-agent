import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../theme/workbench_tokens.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WorkbenchTokens.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WorkbenchTokens.softBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            TDInput(
              controller: controller,
              hintText: 'Continue the conversation',
              showBottomDivider: false,
              needClear: true,
            ),
            const SizedBox(height: 12),
            TDButton(
              text: isSending ? 'Sending…' : 'Send',
              type: TDButtonType.fill,
              isBlock: true,
              onTap: isSending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
