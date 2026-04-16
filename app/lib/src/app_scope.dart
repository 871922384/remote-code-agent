import 'package:flutter/widgets.dart';

import 'data/api_client.dart';

class WorkbenchScope extends InheritedWidget {
  const WorkbenchScope({
    super.key,
    required this.apiClient,
    required super.child,
  });

  final ApiClient apiClient;

  static WorkbenchScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WorkbenchScope>();
    assert(scope != null, 'WorkbenchScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(WorkbenchScope oldWidget) {
    return oldWidget.apiClient != apiClient;
  }
}
