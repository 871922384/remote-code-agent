import 'package:flutter/material.dart';

import 'companion_shell_client.dart';
import 'companion_snapshot.dart';

class DaemonCompanionScreen extends StatefulWidget {
  const DaemonCompanionScreen({
    super.key,
    required this.client,
  });

  final CompanionShellClient client;

  @override
  State<DaemonCompanionScreen> createState() => _DaemonCompanionScreenState();
}

class _DaemonCompanionScreenState extends State<DaemonCompanionScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompanionSnapshot>(
      stream: widget.client.snapshots,
      initialData: widget.client.currentSnapshot,
      builder: (context, snapshot) {
        final shellSnapshot = snapshot.data ?? CompanionSnapshot.initial;

        return Scaffold(
          appBar: AppBar(title: const Text('Daemon Control')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Text(
                    _statusLabel(shellSnapshot.status),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: widget.client.restartDaemon,
                    child: const Text('Restart Service'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: widget.client.openLogs,
                    child: const Text('Open Logs'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoRow(
                label: 'Status',
                value: _statusLabel(shellSnapshot.status),
              ),
              _InfoRow(
                label: 'Log file',
                value: shellSnapshot.logFilePath.isEmpty
                    ? 'Unavailable'
                    : shellSnapshot.logFilePath,
              ),
              if (shellSnapshot.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(shellSnapshot.errorMessage!),
                ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: widget.client.quitApplication,
                child: const Text('Quit App'),
              ),
              const SizedBox(height: 24),
              Text('Recent logs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDCE3F1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: shellSnapshot.recentLogs.isEmpty
                      ? const [Text('No daemon logs yet.')]
                      : shellSnapshot.recentLogs
                          .map((line) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(line),
                              ))
                          .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(CompanionStatus status) => switch (status) {
        CompanionStatus.starting => 'Starting',
        CompanionStatus.running => 'Running',
        CompanionStatus.stopping => 'Stopping',
        CompanionStatus.stopped => 'Stopped',
        CompanionStatus.failed => 'Failed',
      };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
