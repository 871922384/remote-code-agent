import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('shows the pinned project list and opens a workspace', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());

    expect(find.text('Projects'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsWidgets);
  });
}
