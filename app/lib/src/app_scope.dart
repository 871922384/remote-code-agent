import 'package:flutter/widgets.dart';

import 'data/api_client.dart';

typedef UpdateDaemonBaseUri = Future<void> Function(Uri uri);
typedef ApiClientFactory = ApiClient Function(Uri baseUri);

Future<void> _noopUpdateDaemonBaseUri(Uri uri) async {}

ApiClient _defaultApiClientFactory(Uri baseUri) => ApiClient(baseUri: baseUri);

class WorkbenchScope extends InheritedWidget {
  WorkbenchScope({
    super.key,
    required this.apiClient,
    Uri? daemonBaseUri,
    UpdateDaemonBaseUri? updateDaemonBaseUri,
    ApiClientFactory? apiClientFactory,
    required super.child,
  })  : daemonBaseUri = daemonBaseUri ?? apiClient.baseUri,
        updateDaemonBaseUri = updateDaemonBaseUri ?? _noopUpdateDaemonBaseUri,
        apiClientFactory = apiClientFactory ?? _defaultApiClientFactory;

  final ApiClient apiClient;
  final Uri daemonBaseUri;
  final UpdateDaemonBaseUri updateDaemonBaseUri;
  final ApiClientFactory apiClientFactory;

  static WorkbenchScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WorkbenchScope>();
    assert(scope != null, 'WorkbenchScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(WorkbenchScope oldWidget) {
    return oldWidget.apiClient != apiClient ||
        oldWidget.daemonBaseUri != daemonBaseUri;
  }
}
