import 'package:flutter/material.dart';

import '../../data/api_client.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({
    super.key,
    required this.initialUri,
    required this.apiClientFactory,
    required this.onSave,
  });

  final Uri initialUri;
  final ApiClient Function(Uri baseUri) apiClientFactory;
  final Future<void> Function(Uri uri) onSave;

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late final TextEditingController _controller;
  bool _testing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUri.toString());
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
      final ok = await widget.apiClientFactory(uri).checkHealth();
      if (!mounted) return;
      setState(() {
        _status = ok ? 'Connection successful.' : 'Daemon health check failed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString();
      });
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

    await widget.onSave(uri);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://192.168.0.8:3333',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use your Mac daemon address on the same local network.',
            style: Theme.of(context).textTheme.bodySmall,
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
                  onPressed: _save,
                  child: const Text('Save'),
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
