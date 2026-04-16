import 'package:shared_preferences/shared_preferences.dart';

class DaemonConnectionSettings {
  const DaemonConnectionSettings({
    this.baseUri,
    this.authToken,
    this.detailedLogsEnabled = false,
  });

  final Uri? baseUri;
  final String? authToken;
  final bool detailedLogsEnabled;
}

abstract class DaemonConnectionStore {
  Future<DaemonConnectionSettings> loadSettings();
  Future<void> saveSettings(DaemonConnectionSettings settings);

  Future<Uri?> loadBaseUri() async => (await loadSettings()).baseUri;

  Future<String?> loadAuthToken() async => (await loadSettings()).authToken;

  Future<void> saveBaseUri(Uri uri) async {
    final settings = await loadSettings();
    await saveSettings(
      DaemonConnectionSettings(
        baseUri: uri,
        authToken: settings.authToken,
        detailedLogsEnabled: settings.detailedLogsEnabled,
      ),
    );
  }

  Future<void> saveConnection({
    required Uri uri,
    String? authToken,
    bool detailedLogsEnabled = false,
  }) {
    return saveSettings(
      DaemonConnectionSettings(
        baseUri: uri,
        authToken: authToken,
        detailedLogsEnabled: detailedLogsEnabled,
      ),
    );
  }
}

class SharedPreferencesDaemonConnectionStore extends DaemonConnectionStore {
  static const _baseUrlKey = 'daemon_base_url';
  static const _authTokenKey = 'daemon_auth_token';
  static const _detailedLogsEnabledKey = 'detailed_logs_enabled';

  @override
  Future<DaemonConnectionSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final baseUrl = preferences.getString(_baseUrlKey);
    final authToken = preferences.getString(_authTokenKey)?.trim();
    final detailedLogsEnabled =
        preferences.getBool(_detailedLogsEnabledKey) ?? false;
    return DaemonConnectionSettings(
      baseUri: (baseUrl == null || baseUrl.isEmpty) ? null : Uri.tryParse(baseUrl),
      authToken: (authToken == null || authToken.isEmpty) ? null : authToken,
      detailedLogsEnabled: detailedLogsEnabled,
    );
  }

  @override
  Future<void> saveSettings(DaemonConnectionSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    if (settings.baseUri == null) {
      await preferences.remove(_baseUrlKey);
    } else {
      await preferences.setString(_baseUrlKey, settings.baseUri.toString());
    }

    final authToken = settings.authToken?.trim();
    if (authToken == null || authToken.isEmpty) {
      await preferences.remove(_authTokenKey);
    } else {
      await preferences.setString(_authTokenKey, authToken);
    }

    await preferences.setBool(
      _detailedLogsEnabledKey,
      settings.detailedLogsEnabled,
    );
  }
}
