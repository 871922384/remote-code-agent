import 'package:flutter/material.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Continue the conversation',
        ),
      ),
    );
  }
}
