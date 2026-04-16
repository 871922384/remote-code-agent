import 'package:agent_workbench/src/config/daemon_connection_store.dart';

class FakeDaemonConnectionStore implements DaemonConnectionStore {
  FakeDaemonConnectionStore([this.savedUri]);

  Uri? savedUri;
  int saveCalls = 0;

  @override
  Future<Uri?> loadBaseUri() async => savedUri;

  @override
  Future<void> saveBaseUri(Uri uri) async {
    saveCalls += 1;
    savedUri = uri;
  }
}
