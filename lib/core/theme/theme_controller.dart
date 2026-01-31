import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key for storing theme mode preference
const _themePreferenceKey = 'theme_mode';

/// Theme mode notifier for managing theme state with persistence
class ThemeController extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeController(this._prefs) : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Load theme preference from storage
  void _loadTheme() {
    final savedTheme = _prefs.getString(_themePreferenceKey);
    if (savedTheme != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
  }

  /// Set and persist theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_themePreferenceKey, mode.name);
  }

  /// Toggle between light and dark (ignores system)
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Check if dark mode is currently active
  bool get isDarkMode => state == ThemeMode.dark;
}

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

/// Provider for ThemeController
final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ThemeController(prefs);
    });

/// Convenience provider for checking dark mode status
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeControllerProvider);
  return themeMode == ThemeMode.dark;
});
