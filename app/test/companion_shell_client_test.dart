import 'dart:async';

import 'package:agent_workbench/src/features/companion/companion_shell_client.dart';
import 'package:agent_workbench/src/features/companion/companion_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps native event payloads into companion snapshots', () async {
    final controller = StreamController<dynamic>();
    final client = PlatformCompanionShellClient(
      methodChannel: const MethodChannel('agent_workbench/companion/methods'),
      snapshotEvents: controller.stream,
    );

    final snapshotFuture = client.snapshots.first;
    controller.add({
      'status': 'running',
      'errorMessage': null,
      'logFilePath': '/Users/test/Library/Logs/agent_workbench/daemon.log',
      'recentLogs': ['[daemon] listening on http://0.0.0.0:3333'],
    });

    expect(
      await snapshotFuture,
      const CompanionSnapshot(
        status: CompanionStatus.running,
        logFilePath: '/Users/test/Library/Logs/agent_workbench/daemon.log',
        recentLogs: ['[daemon] listening on http://0.0.0.0:3333'],
      ),
    );
  });
}
