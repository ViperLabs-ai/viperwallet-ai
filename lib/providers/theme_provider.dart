import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  static const String _themeKey = 'theme_mode';

  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool(_themeKey);
      if (savedTheme != null) {
        _isDarkMode = savedTheme;
        notifyListeners();
      }
    } catch (e) {
      print('❌ Theme loading error: $e');
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('❌ Theme saving error: $e');
    }
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('❌ Theme saving error: $e');
    }
  }

  // Light theme
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.orange,
    primaryColor: const Color(0xFFFF6B35),
    scaffoldBackgroundColor: Colors.grey[50],
    fontFamily: 'Poppins',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black87,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFFF6B35)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFF6B35),
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFFFF6B35),
      secondary: const Color(0xFFFF8C42),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      background: Colors.grey[50]!,
      surface: Colors.white,
    ),
  );

  // Dark theme
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.orange,
    primaryColor: const Color(0xFFFF6B35),
    scaffoldBackgroundColor: const Color(0xFF121212),
    fontFamily: 'Poppins',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFFF6B35)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFF6B35),
      ),
    ),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFFF6B35),
      secondary: const Color(0xFFFF8C42),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      background: const Color(0xFF121212),
      surface: const Color(0xFF1E1E1E),
    ),
  );
}
