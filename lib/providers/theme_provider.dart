import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF3F51B5);

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  static final ThemeProvider instance = ThemeProvider._internal();

  factory ThemeProvider() {
    return instance;
  }

  ThemeProvider._internal() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('theme_mode') ?? 'system';
    int colorValue = prefs.getInt('seed_color') ?? 0xFF3F51B5;

    // Migrate old defaults to new default Material Indigo
    if (colorValue == 0xFF5B5FED || colorValue == 0xFF4300FF) {
      colorValue = 0xFF3F51B5;
      await prefs.setInt('seed_color', 0xFF3F51B5);
    }

    switch (modeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }

    _seedColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String modeString = 'system';
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      default:
        modeString = 'system';
    }
    await prefs.setString('theme_mode', modeString);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color', color.value);
  }
}
