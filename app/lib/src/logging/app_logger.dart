import 'package:flutter/foundation.dart';

enum AppLogLevel {
  info,
  error,
  debug,
}

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.detailed = false,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;
  final bool detailed;
}

class AppLogger extends ChangeNotifier {
  AppLogger({
    bool detailedLoggingEnabled = false,
    this.maxEntries = 300,
  }) : _detailedLoggingEnabled = detailedLoggingEnabled;

  final int maxEntries;
  final List<AppLogEntry> _entries = [];
  bool _detailedLoggingEnabled;

  bool get detailedLoggingEnabled => _detailedLoggingEnabled;

  List<AppLogEntry> get visibleEntries => List.unmodifiable(
        _entries.where((entry) => _detailedLoggingEnabled || !entry.detailed),
      );

  void setDetailedLoggingEnabled(bool enabled) {
    if (_detailedLoggingEnabled == enabled) return;
    _detailedLoggingEnabled = enabled;
    notifyListeners();
  }

  void info(
    String source,
    String message, {
    bool detailed = false,
  }) {
    _append(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.info,
        source: source,
        message: message,
        detailed: detailed,
      ),
    );
  }

  void error(String source, String message) {
    _append(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.error,
        source: source,
        message: message,
      ),
    );
  }

  void debug(String source, String message) {
    _append(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.debug,
        source: source,
        message: message,
        detailed: true,
      ),
    );
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  String formatVisibleLogs() {
    return visibleEntries.map(_formatEntry).join('\n');
  }

  void _append(AppLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
  }

  String _formatEntry(AppLogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = switch (entry.level) {
      AppLogLevel.info => 'INFO',
      AppLogLevel.error => 'ERROR',
      AppLogLevel.debug => 'DEBUG',
    };
    return '[$timestamp] [$level] [${entry.source}] ${entry.message}';
  }
}
