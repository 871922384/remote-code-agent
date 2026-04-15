import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/workspace/workspace_screen.dart';
import 'package:agent_workbench/src/models/conversation_summary.dart';

void main() {
  testWidgets('renders a horizontal conversation strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          projectName: 'alpha-api',
          conversations: const [
            ConversationSummary(
              id: 'c-1',
              title: '修复支付回调',
              status: 'running',
              lastMessagePreview: '正在检查 controller',
            ),
          ],
        ),
      ),
    );

    expect(find.text('alpha-api'), findsOneWidget);
    expect(find.text('修复支付回调'), findsOneWidget);
  });
}
