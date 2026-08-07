import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPrefs.getAsync();
      final isDark = prefs.getBool(_themeKey) ?? false;
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      debugPrint('[ThemeNotifier] Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    final isDark = state == ThemeMode.light;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPrefs.getAsync();
      await prefs.setBool(_themeKey, isDark);
    } catch (e) {
      debugPrint('[ThemeNotifier] Error saving theme: $e');
    }
  }
}
