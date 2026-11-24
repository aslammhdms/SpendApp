import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_color_schemes.dart';
import 'app_theme.dart';

/// The color Android derives from the wallpaper (Android 12 and later), or
/// null where there is none: older Android and other platforms.
final wallpaperColorProvider = FutureProvider<Color?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    return palette == null ? null : Color(palette.primary.get(40));
  } catch (e) {
    debugPrint('Wallpaper colour not available: $e');
    return null;
  }
});

/// Whether the user chose the wallpaper's colours over the brand's.
final useWallpaperColorsProvider =
    StateNotifierProvider<UseWallpaperColors, bool>(
        (ref) => UseWallpaperColors());

class UseWallpaperColors extends StateNotifier<bool> {
  UseWallpaperColors() : super(false) {
    _load();
  }

  static const _key = 'settings_wallpaper_colors';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// The app's light and dark themes: the brand's teal, or the wallpaper's
/// colours when the user asked for them and the phone provides them.
final appThemesProvider = Provider<({ThemeData light, ThemeData dark})>((ref) {
  final wallpaper = ref.watch(wallpaperColorProvider).valueOrNull;
  if (wallpaper == null || !ref.watch(useWallpaperColorsProvider)) {
    return (light: AppTheme.light, dark: AppTheme.dark);
  }
  return (
    light: AppTheme.fromScheme(
        AppColorSchemes.fromWallpaper(wallpaper, Brightness.light)),
    dark: AppTheme.fromScheme(
        AppColorSchemes.fromWallpaper(wallpaper, Brightness.dark)),
  );
});
