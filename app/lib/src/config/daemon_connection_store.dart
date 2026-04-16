import 'package:shared_preferences/shared_preferences.dart';

abstract class DaemonConnectionStore {
  Future<Uri?> loadBaseUri();
  Future<void> saveBaseUri(Uri uri);
}

class SharedPreferencesDaemonConnectionStore implements DaemonConnectionStore {
  static const _baseUrlKey = 'daemon_base_url';

  @override
  Future<Uri?> loadBaseUri() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_baseUrlKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return Uri.tryParse(value);
  }

  @override
  Future<void> saveBaseUri(Uri uri) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, uri.toString());
  }
}
