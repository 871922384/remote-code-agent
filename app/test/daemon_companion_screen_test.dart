import 'dart:async';

import 'package:agent_workbench/src/features/companion/companion_shell_client.dart';
import 'package:agent_workbench/src/features/companion/companion_snapshot.dart';
import 'package:agent_workbench/src/features/companion/daemon_companion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders native shell state and restart/open-logs actions',
      (tester) async {
    final client = FakeCompanionShellClient(
      initialSnapshot: const CompanionSnapshot(
        status: CompanionStatus.failed,
        errorMessage: 'Port 3333 is already in use.',
        logFilePath: '/Users/test/Library/Logs/agent_workbench/daemon.log',
        recentLogs: ['Failed to bind daemon port.'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DaemonCompanionScreen(
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daemon Control'), findsOneWidget);
    expect(find.text('Port 3333 is already in use.'), findsOneWidget);
    expect(find.text('Restart Service'), findsOneWidget);
    expect(find.text('Open Logs'), findsOneWidget);
    expect(find.text('Failed to bind daemon port.'), findsOneWidget);

    await tester.tap(find.text('Restart Service'));
    await tester.pump();
    await tester.tap(find.text('Open Logs'));
    await tester.pump();

    expect(client.restartCallCount, 1);
    expect(client.openLogsCallCount, 1);
  });
}

class FakeCompanionShellClient implements CompanionShellClient {
  FakeCompanionShellClient({required CompanionSnapshot initialSnapshot})
    : currentSnapshot = initialSnapshot;

  @override
  final CompanionSnapshot currentSnapshot;

  @override
  Stream<CompanionSnapshot> get snapshots => Stream<CompanionSnapshot>.value(
    currentSnapshot,
  );

  int restartCallCount = 0;
  int openLogsCallCount = 0;
  int quitCallCount = 0;

  @override
  Future<void> openLogs() async {
    openLogsCallCount += 1;
  }

  @override
  Future<void> quitApplication() async {
    quitCallCount += 1;
  }

  @override
  Future<void> restartDaemon() async {
    restartCallCount += 1;
  }
}
