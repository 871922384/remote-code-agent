import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../models/conversation_event.dart';
import '../../models/conversation_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../conversation/conversation_screen.dart';
import 'conversation_strip.dart';
import 'conversation_state_badge.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.projectName,
    required this.conversations,
  });

  final String projectName;
  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(projectName,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Switch between active threads and keep the current run in view.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              ConversationStrip(conversations: conversations),
              const SizedBox(height: 20),
              TDButton(
                text: 'New conversation',
                type: TDButtonType.fill,
                isBlock: true,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: WorkbenchTokens.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: WorkbenchTokens.softBorder),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        title: Text(
                          conversation.lastMessagePreview,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ConversationStateBadge(conversation.status),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                title: conversation.title,
                                events: [
                                  const ConversationEvent.message(
                                    text: 'Start with the callback path',
                                    role: 'user',
                                  ),
                                  ConversationEvent.action(
                                    label: conversation.lastMessagePreview,
                                  ),
                                ],
                                canConfirm: false,
                                canInterrupt: true,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
