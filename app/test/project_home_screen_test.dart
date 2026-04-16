import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('shows the premium project cards with running counts and summaries', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());
    await tester.pumpAndSettle();

    expect(find.text('Your workspaces'), findsOneWidget);
    expect(find.text('2 conversations running'), findsOneWidget);
    expect(find.text('Pick up where you left off'), findsOneWidget);
  });
}
