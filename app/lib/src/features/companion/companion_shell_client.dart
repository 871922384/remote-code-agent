import 'dart:async';

import 'package:flutter/services.dart';

import 'companion_snapshot.dart';

abstract class CompanionShellClient {
  CompanionSnapshot get currentSnapshot;
  Stream<CompanionSnapshot> get snapshots;

  Future<void> restartDaemon();
  Future<void> openLogs();
  Future<void> quitApplication();
}

class PlatformCompanionShellClient implements CompanionShellClient {
  PlatformCompanionShellClient({
    MethodChannel methodChannel = const MethodChannel(_methodChannelName),
    EventChannel eventChannel = const EventChannel(_eventChannelName),
    Stream<dynamic>? snapshotEvents,
    CompanionSnapshot initialSnapshot = CompanionSnapshot.initial,
  }) : _methodChannel = methodChannel,
       _currentSnapshot = initialSnapshot {
    _snapshots =
        (snapshotEvents ?? eventChannel.receiveBroadcastStream())
            .map(_parseSnapshot)
            .transform(
              StreamTransformer<CompanionSnapshot, CompanionSnapshot>.fromHandlers(
                handleData: (snapshot, sink) {
                  _currentSnapshot = snapshot;
                  sink.add(snapshot);
                },
              ),
            )
            .asBroadcastStream();
  }

  static const _methodChannelName = 'agent_workbench/companion/methods';
  static const _eventChannelName = 'agent_workbench/companion/events';

  final MethodChannel _methodChannel;
  late final Stream<CompanionSnapshot> _snapshots;
  CompanionSnapshot _currentSnapshot;

  @override
  CompanionSnapshot get currentSnapshot => _currentSnapshot;

  @override
  Stream<CompanionSnapshot> get snapshots => _snapshots;

  @override
  Future<void> openLogs() {
    return _methodChannel.invokeMethod<void>('openLogs');
  }

  @override
  Future<void> quitApplication() {
    return _methodChannel.invokeMethod<void>('quitApplication');
  }

  @override
  Future<void> restartDaemon() {
    return _methodChannel.invokeMethod<void>('restartDaemon');
  }

  CompanionSnapshot _parseSnapshot(dynamic event) {
    if (event is! Map) {
      throw const FormatException('Companion snapshot event must be a map.');
    }

    return CompanionSnapshot.fromMap(Map<Object?, Object?>.from(event));
  }
}
