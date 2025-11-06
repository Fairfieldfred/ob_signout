import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _sharerNameKey = 'sharer_name';

  /// Saves the sharer's name to shared preferences
  static Future<void> saveSharerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharerNameKey, name);
  }

  /// Loads the saved sharer's name from shared preferences
  /// Returns null if no name has been saved
  static Future<String?> loadSharerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sharerNameKey);
  }

  /// Clears the saved sharer's name
  static Future<void> clearSharerName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sharerNameKey);
  }
}
