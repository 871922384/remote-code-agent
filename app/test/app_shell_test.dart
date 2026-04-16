import 'package:agent_workbench/app.dart';
import 'package:agent_workbench/src/features/companion/companion_shell_client.dart';
import 'package:agent_workbench/src/features/companion/companion_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_connection_store.dart';

void main() {
  testWidgets('uses the daemon companion shell in auto mode on macOS',
      (tester) async {
    final client = FakeCompanionShellClient(
      initialSnapshot: const CompanionSnapshot(
        status: CompanionStatus.running,
        logFilePath: '/Users/test/Library/Logs/agent_workbench/daemon.log',
        recentLogs: ['Daemon is healthy.'],
      ),
    );

    await tester.pumpWidget(
      AgentWorkbenchApp(
        shellMode: AppShellMode.auto,
        platformOverride: TargetPlatform.macOS,
        connectionStore: FakeDaemonConnectionStore(),
        companionShellClient: client,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Daemon Control'), findsOneWidget);
    expect(find.text('Your workspaces'), findsNothing);
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

  @override
  Future<void> openLogs() async {}

  @override
  Future<void> quitApplication() async {}

  @override
  Future<void> restartDaemon() async {}
}
