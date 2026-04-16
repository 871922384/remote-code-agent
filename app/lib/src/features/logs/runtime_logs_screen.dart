import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logging/app_logger.dart';

class RuntimeLogsScreen extends StatelessWidget {
  const RuntimeLogsScreen({
    super.key,
    required this.logger,
  });

  final AppLogger logger;

  Future<void> _copyLogs(BuildContext context) async {
    final text = logger.formatVisibleLogs();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: logger,
      builder: (context, _) {
        final entries = logger.visibleEntries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Runtime logs'),
            actions: [
              IconButton(
                key: const Key('copy-logs-button'),
                onPressed: () => _copyLogs(context),
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                key: const Key('clear-logs-button'),
                onPressed: logger.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: entries.isEmpty
              ? const Center(child: Text('No logs captured yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDCE3F1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${entry.source} · ${entry.timestamp.toIso8601String()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
