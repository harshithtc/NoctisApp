import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and manages app ThemeMode with system-follow capability.
/// - Stores selection in SharedPreferences under key 'theme_mode'
/// - Listens to platform brightness changes when in system mode
class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
  }

  // Load persisted theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_prefsKey) ?? 'system';

    switch (themeModeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  // Persist and apply a new ThemeMode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);

    notifyListeners();
  }

  // Convenience toggle between light/dark (ignores system)
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  // Re-emit changes when system brightness changes and mode == system
  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
    super.didChangePlatformBrightness();
  }

  // Helper to compute effective brightness (when using ThemeMode.system)
  Brightness effectiveBrightness(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context);
    }
    return _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
