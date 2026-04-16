import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../theme/workbench_tokens.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({super.key});

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
              hintText: 'Continue the conversation',
              showBottomDivider: false,
              needClear: true,
            ),
            const SizedBox(height: 12),
            TDButton(
              text: 'Send',
              type: TDButtonType.fill,
              isBlock: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
