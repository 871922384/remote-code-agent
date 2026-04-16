import 'package:flutter/foundation.dart';

enum CompanionStatus {
  starting,
  running,
  stopping,
  stopped,
  failed,
}

@immutable
class CompanionSnapshot {
  const CompanionSnapshot({
    required this.status,
    this.errorMessage,
    required this.logFilePath,
    required this.recentLogs,
  });

  factory CompanionSnapshot.fromMap(Map<Object?, Object?> map) {
    return CompanionSnapshot(
      status: CompanionStatus.values.byName(map['status']! as String),
      errorMessage: map['errorMessage'] as String?,
      logFilePath: (map['logFilePath'] as String?) ?? '',
      recentLogs: ((map['recentLogs'] as List<Object?>?) ?? const [])
          .map((line) => '$line')
          .toList(growable: false),
    );
  }

  static const initial = CompanionSnapshot(
    status: CompanionStatus.stopped,
    logFilePath: '',
    recentLogs: [],
  );

  final CompanionStatus status;
  final String? errorMessage;
  final String logFilePath;
  final List<String> recentLogs;

  @override
  bool operator ==(Object other) {
    return other is CompanionSnapshot &&
        other.status == status &&
        other.errorMessage == errorMessage &&
        other.logFilePath == logFilePath &&
        listEquals(other.recentLogs, recentLogs);
  }

  @override
  int get hashCode => Object.hash(
    status,
    errorMessage,
    logFilePath,
    Object.hashAll(recentLogs),
  );
}
