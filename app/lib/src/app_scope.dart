import 'package:flutter/widgets.dart';

import 'config/daemon_connection_store.dart';
import 'data/api_client.dart';
import 'logging/app_logger.dart';

typedef UpdateDaemonConnection = Future<void> Function(
  Uri uri,
  String? authToken,
  bool detailedLogsEnabled,
);
typedef ApiClientFactory = ApiClient Function(
  Uri baseUri, {
  String? authToken,
  AppLogger? logger,
});
typedef UpdateDetailedLogging = Future<void> Function(bool enabled);

Future<void> _noopUpdateDaemonConnection(
  Uri uri,
  String? authToken,
  bool detailedLogsEnabled,
) async {}

Future<void> _noopUpdateDetailedLogging(bool enabled) async {}

ApiClient _defaultApiClientFactory(
  Uri baseUri, {
  String? authToken,
  AppLogger? logger,
}) => ApiClient(
  baseUri: baseUri,
  authToken: authToken,
  logger: logger,
);

class WorkbenchScope extends InheritedWidget {
  WorkbenchScope({
    super.key,
    required this.apiClient,
    required this.logger,
    DaemonConnectionSettings? daemonConnection,
    UpdateDaemonConnection? updateDaemonConnection,
    UpdateDetailedLogging? updateDetailedLogging,
    ApiClientFactory? apiClientFactory,
    required super.child,
  })  : daemonConnection =
            daemonConnection ??
            DaemonConnectionSettings(
              baseUri: apiClient.baseUri,
              authToken: apiClient.authToken,
            ),
        updateDaemonConnection =
            updateDaemonConnection ?? _noopUpdateDaemonConnection,
        updateDetailedLogging =
            updateDetailedLogging ?? _noopUpdateDetailedLogging,
        apiClientFactory = apiClientFactory ?? _defaultApiClientFactory;

  final ApiClient apiClient;
  final AppLogger logger;
  final DaemonConnectionSettings daemonConnection;
  final UpdateDaemonConnection updateDaemonConnection;
  final UpdateDetailedLogging updateDetailedLogging;
  final ApiClientFactory apiClientFactory;

  static WorkbenchScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WorkbenchScope>();
    assert(scope != null, 'WorkbenchScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(WorkbenchScope oldWidget) {
    return oldWidget.apiClient != apiClient ||
        oldWidget.logger != logger ||
        oldWidget.daemonConnection.baseUri != daemonConnection.baseUri ||
        oldWidget.daemonConnection.authToken != daemonConnection.authToken ||
        oldWidget.daemonConnection.detailedLogsEnabled !=
            daemonConnection.detailedLogsEnabled;
  }
}
