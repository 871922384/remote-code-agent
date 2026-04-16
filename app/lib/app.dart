import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app_scope.dart';
import 'src/config/daemon_connection_store.dart';
import 'src/data/api_client.dart';
import 'src/features/companion/companion_shell_client.dart';
import 'src/features/companion/daemon_companion_screen.dart';
import 'src/features/projects/project_home_screen.dart';
import 'src/logging/app_logger.dart';
import 'src/theme/workbench_theme.dart';

enum AppShellMode {
  auto,
  workbench,
  daemonCompanion,
}

class AgentWorkbenchApp extends StatefulWidget {
  const AgentWorkbenchApp({
    super.key,
    this.apiClient,
    this.connectionStore,
    this.apiClientFactory,
    this.shellMode = AppShellMode.workbench,
    this.platformOverride,
    this.companionShellClient,
  });

  final ApiClient? apiClient;
  final DaemonConnectionStore? connectionStore;
  final ApiClientFactory? apiClientFactory;
  final AppShellMode shellMode;
  final TargetPlatform? platformOverride;
  final CompanionShellClient? companionShellClient;

  @override
  State<AgentWorkbenchApp> createState() => _AgentWorkbenchAppState();
}

class _AgentWorkbenchAppState extends State<AgentWorkbenchApp> {
  late final DaemonConnectionStore _connectionStore =
      widget.connectionStore ?? SharedPreferencesDaemonConnectionStore();
  late final ApiClientFactory _apiClientFactory =
      widget.apiClientFactory ??
      ((baseUri, {authToken, logger}) => ApiClient(
            baseUri: baseUri,
            authToken: authToken,
            logger: logger,
          ));
  late final CompanionShellClient _companionShellClient =
      widget.companionShellClient ?? PlatformCompanionShellClient();

  ApiClient? _apiClient;
  late final AppLogger _appLogger = AppLogger();
  DaemonConnectionSettings _daemonConnection = const DaemonConnectionSettings();
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
        _daemonConnection = DaemonConnectionSettings(
          baseUri: widget.apiClient!.baseUri,
          authToken: widget.apiClient!.authToken,
        );
        _ready = true;
      });
      return;
    }

    final storedSettings = await _connectionStore.loadSettings();
    final daemonBaseUri = ApiClient.normalizeBaseUri(
      storedSettings.baseUri ?? ApiClient.defaultBaseUri,
    );
    final authToken = storedSettings.authToken?.trim();
    _appLogger.setDetailedLoggingEnabled(storedSettings.detailedLogsEnabled);
    if (!mounted) return;
    setState(() {
      _daemonConnection = DaemonConnectionSettings(
        baseUri: daemonBaseUri,
        authToken: (authToken == null || authToken.isEmpty) ? null : authToken,
        detailedLogsEnabled: storedSettings.detailedLogsEnabled,
      );
      _apiClient = _apiClientFactory(
        daemonBaseUri,
        authToken: authToken,
        logger: _appLogger,
      );
      _ready = true;
    });
  }

  Future<void> _updateDaemonConnection(
    Uri uri,
    String? authToken,
    bool detailedLogsEnabled,
  ) async {
    final normalizedUri = ApiClient.normalizeBaseUri(uri);
    final normalizedToken = authToken?.trim();
    _appLogger.setDetailedLoggingEnabled(detailedLogsEnabled);
    await _connectionStore.saveConnection(
      uri: normalizedUri,
      authToken: normalizedToken,
      detailedLogsEnabled: detailedLogsEnabled,
    );
    if (!mounted) return;
    setState(() {
      _daemonConnection = DaemonConnectionSettings(
        baseUri: normalizedUri,
        authToken:
            (normalizedToken == null || normalizedToken.isEmpty)
                ? null
                : normalizedToken,
        detailedLogsEnabled: detailedLogsEnabled,
      );
      _apiClient = _apiClientFactory(
        normalizedUri,
        authToken: normalizedToken,
        logger: _appLogger,
      );
    });
  }

  Future<void> _updateDetailedLogging(bool enabled) async {
    _appLogger.setDetailedLoggingEnabled(enabled);
    await _connectionStore.saveSettings(
      DaemonConnectionSettings(
        baseUri: _daemonConnection.baseUri,
        authToken: _daemonConnection.authToken,
        detailedLogsEnabled: enabled,
      ),
    );
    if (!mounted) return;
    setState(() {
      _daemonConnection = DaemonConnectionSettings(
        baseUri: _daemonConnection.baseUri,
        authToken: _daemonConnection.authToken,
        detailedLogsEnabled: enabled,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final shellMode = _resolveShellMode();

    return WorkbenchTheme(
      child: MaterialApp(
        title: 'Agent Workbench',
        theme: buildWorkbenchMaterialTheme(),
        home: !_ready
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : shellMode == AppShellMode.daemonCompanion
            ? DaemonCompanionScreen(
                client: _companionShellClient,
              )
            : WorkbenchScope(
                apiClient: _apiClient!,
                logger: _appLogger,
                daemonConnection: _daemonConnection,
                updateDaemonConnection: _updateDaemonConnection,
                updateDetailedLogging: _updateDetailedLogging,
                apiClientFactory: _apiClientFactory,
                child: const ProjectHomeScreen(),
              ),
      ),
    );
  }

  AppShellMode _resolveShellMode() {
    if (widget.shellMode != AppShellMode.auto) {
      return widget.shellMode;
    }

    final platform = widget.platformOverride ?? defaultTargetPlatform;
    if (!kIsWeb && platform == TargetPlatform.macOS) {
      return AppShellMode.daemonCompanion;
    }

    return AppShellMode.workbench;
  }
}
