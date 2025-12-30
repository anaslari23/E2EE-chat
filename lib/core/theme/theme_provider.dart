import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;
  
  ThemeNotifier(this.ref) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final storage = ref.read(secureStorageProvider);
    final theme = await storage.read(key: 'theme_mode');
    if (theme == 'light') state = ThemeMode.light;
    else if (theme == 'dark') state = ThemeMode.dark;
    else state = ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(secureStorageProvider);
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await storage.write(key: 'theme_mode', value: value);
  }
}
