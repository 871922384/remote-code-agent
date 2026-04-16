import 'package:agent_workbench/src/config/daemon_connection_store.dart';

class FakeDaemonConnectionStore extends DaemonConnectionStore {
  FakeDaemonConnectionStore({
    this.savedUri,
    this.savedAuthToken,
    this.savedDetailedLogsEnabled = false,
  });

  Uri? savedUri;
  String? savedAuthToken;
  bool savedDetailedLogsEnabled;
  int saveCalls = 0;

  @override
  Future<DaemonConnectionSettings> loadSettings() async {
    return DaemonConnectionSettings(
      baseUri: savedUri,
      authToken: savedAuthToken,
      detailedLogsEnabled: savedDetailedLogsEnabled,
    );
  }

  @override
  Future<void> saveSettings(DaemonConnectionSettings settings) async {
    saveCalls += 1;
    savedUri = settings.baseUri;
    savedAuthToken = settings.authToken;
    savedDetailedLogsEnabled = settings.detailedLogsEnabled;
  }
}
