import 'package:flutter/material.dart';

import '../../logging/app_logger.dart';
import '../../data/api_client.dart';
import '../logs/runtime_logs_screen.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({
    super.key,
    required this.initialUri,
    this.initialAuthToken,
    required this.initialDetailedLogsEnabled,
    required this.logger,
    required this.apiClientFactory,
    required this.onSave,
  });

  final Uri initialUri;
  final String? initialAuthToken;
  final bool initialDetailedLogsEnabled;
  final AppLogger logger;
  final ApiClient Function(
    Uri baseUri, {
    String? authToken,
    AppLogger? logger,
  }) apiClientFactory;
  final Future<void> Function(
    Uri uri,
    String? authToken,
    bool detailedLogsEnabled,
  ) onSave;

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _authTokenController;
  late bool _detailedLogsEnabled;
  bool _testing = false;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUri.toString());
    _authTokenController = TextEditingController(
      text: widget.initialAuthToken ?? '',
    );
    _detailedLogsEnabled = widget.initialDetailedLogsEnabled;
  }

  Uri? get _parsedUri => Uri.tryParse(_controller.text.trim());

  Future<void> _testConnection() async {
    final uri = _parsedUri;
    if (uri == null) {
      setState(() {
        _status = 'Enter a valid daemon URL.';
      });
      return;
    }

    setState(() {
      _testing = true;
      _status = null;
    });

    try {
      widget.logger.info('ui', 'Testing daemon connection', detailed: true);
      final ok = await widget.apiClientFactory(
        uri,
        authToken: _normalizedAuthToken,
        logger: widget.logger,
      ).checkHealth();
      if (!mounted) return;
      setState(() {
        _status = ok ? 'Connection successful.' : 'Daemon health check failed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString();
      });
      widget.logger.error('ui', 'Daemon connection test failed: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    final uri = _parsedUri;
    if (uri == null) {
      setState(() {
        _status = 'Enter a valid daemon URL.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });

    await widget.onSave(uri, _normalizedAuthToken, _detailedLogsEnabled);
    widget.logger.info('ui', 'Saved connection settings', detailed: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daemon URL saved.')),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  String? get _normalizedAuthToken {
    final token = _authTokenController.text.trim();
    return token.isEmpty ? null : token;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Daemon URL',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('daemon-url-field'),
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://10.0.2.2:3333',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Android Emulator uses 10.0.2.2. Real devices should use your Mac LAN IP.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Access token',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('daemon-token-field'),
            controller: _authTokenController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Optional bearer token',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Required when the daemon is started with authentication enabled.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            key: const Key('detailed-logs-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Detailed logs'),
            subtitle: const Text(
              'Include network requests and key UI actions in this run.',
            ),
            value: _detailedLogsEnabled,
            onChanged: (value) {
              setState(() {
                _detailedLogsEnabled = value;
              });
              widget.logger.setDetailedLoggingEnabled(value);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('view-logs-button'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RuntimeLogsScreen(logger: widget.logger),
                ),
              );
            },
            child: const Text('View logs'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: Text(_testing ? 'Testing…' : 'Test connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
