import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _currentPageKey = 'currentPage';
  static const String _isDarkModeKey = 'isDarkMode';

  static Future<int> getCurrentPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentPageKey) ?? 1;
  }

  static Future<void> saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentPageKey, page);
  }

  static Future<bool> getIsDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDarkModeKey) ?? false;
  }

  static Future<void> saveIsDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, isDarkMode);
  }
}






