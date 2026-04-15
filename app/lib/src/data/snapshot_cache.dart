import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SnapshotCache {
  Future<void> write(String key, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
