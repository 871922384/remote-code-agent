import 'package:agent_workbench/src/features/logs/runtime_logs_screen.dart';
import 'package:agent_workbench/src/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('copies and clears visible logs', (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': copiedText};
      }
      return null;
    });

    final logger = AppLogger(detailedLoggingEnabled: false);
    logger.info('app', 'Connected to daemon');
    logger.debug('network', 'GET /projects');

    await tester.pumpWidget(
      MaterialApp(
        home: RuntimeLogsScreen(logger: logger),
      ),
    );

    expect(find.text('Connected to daemon'), findsOneWidget);
    expect(find.text('GET /projects'), findsNothing);

    await tester.tap(find.byKey(const Key('copy-logs-button')));
    await tester.pumpAndSettle();

    expect(copiedText, contains('Connected to daemon'));
    expect(copiedText, isNot(contains('GET /projects')));

    await tester.tap(find.byKey(const Key('clear-logs-button')));
    await tester.pumpAndSettle();

    expect(find.text('No logs captured yet.'), findsOneWidget);
  });
}
