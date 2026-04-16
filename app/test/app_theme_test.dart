import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('wraps the app in the workbench theme with the warm background', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF7F8FC));
    expect(find.text('Projects'), findsOneWidget);
  });
}
