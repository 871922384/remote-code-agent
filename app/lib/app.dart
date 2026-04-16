import 'package:flutter/material.dart';

import 'src/app_scope.dart';
import 'src/config/daemon_connection_store.dart';
import 'src/data/api_client.dart';
import 'src/features/projects/project_home_screen.dart';
import 'src/theme/workbench_theme.dart';

class AgentWorkbenchApp extends StatefulWidget {
  const AgentWorkbenchApp({
    super.key,
    this.apiClient,
    this.connectionStore,
    this.apiClientFactory,
  });

  final ApiClient? apiClient;
  final DaemonConnectionStore? connectionStore;
  final ApiClientFactory? apiClientFactory;

  @override
  State<AgentWorkbenchApp> createState() => _AgentWorkbenchAppState();
}

class _AgentWorkbenchAppState extends State<AgentWorkbenchApp> {
  late final DaemonConnectionStore _connectionStore =
      widget.connectionStore ?? SharedPreferencesDaemonConnectionStore();
  late final ApiClientFactory _apiClientFactory =
      widget.apiClientFactory ?? ((baseUri) => ApiClient(baseUri: baseUri));

  ApiClient? _apiClient;
  Uri? _daemonBaseUri;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.apiClient != null && widget.apiClientFactory == null) {
      setState(() {
        _apiClient = widget.apiClient;
        _daemonBaseUri = widget.apiClient!.baseUri;
        _ready = true;
      });
      return;
    }

    final storedUri = await _connectionStore.loadBaseUri();
    final daemonBaseUri = storedUri ?? ApiClient.defaultBaseUri;
    if (!mounted) return;
    setState(() {
      _daemonBaseUri = daemonBaseUri;
      _apiClient = _apiClientFactory(daemonBaseUri);
      _ready = true;
    });
  }

  Future<void> _updateDaemonBaseUri(Uri uri) async {
    await _connectionStore.saveBaseUri(uri);
    if (!mounted) return;
    setState(() {
      _daemonBaseUri = uri;
      _apiClient = _apiClientFactory(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WorkbenchTheme(
      child: MaterialApp(
        title: 'Agent Workbench',
        theme: buildWorkbenchMaterialTheme(),
        home: !_ready
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : WorkbenchScope(
                apiClient: _apiClient!,
                daemonBaseUri: _daemonBaseUri!,
                updateDaemonBaseUri: _updateDaemonBaseUri,
                apiClientFactory: _apiClientFactory,
                child: const ProjectHomeScreen(),
              ),
      ),
    );
  }
}
