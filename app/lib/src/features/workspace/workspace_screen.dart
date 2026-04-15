import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';
import 'conversation_strip.dart';

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
      appBar: AppBar(title: Text(projectName)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConversationStrip(conversations: conversations),
          ),
          Expanded(
            child: ListView(
              children: conversations.map((conversation) {
                return ListTile(
                  title: Text(conversation.lastMessagePreview),
                  trailing: Text(conversation.status),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
