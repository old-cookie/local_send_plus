import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/pages/home_page.dart';
import 'package:local_send_plus/pages/auth_page.dart';
import 'package:local_send_plus/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_send_plus/services/theme_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences provider was not overridden');
});
final themeModeNotifierProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  ThemeModeNotifier(this._prefs) : super(_calculateThemeMode(_prefs));
  static ThemeMode _calculateThemeMode(SharedPreferences prefs) {
    return themeMode(prefs);
  }

  Future<void> setThemeMode(String brightnessValue) async {
    await _prefs.setString("brightness", brightnessValue);
    state = _calculateThemeMode(_prefs);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsInstance = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefsInstance)], child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool useBiometrics = ref.watch(biometricAuthProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final currentThemeMode = ref.watch(themeModeNotifierProvider);

    return MaterialApp(
      title: 'LocalSend Plus',
      theme: themeLight(prefs),
      darkTheme: themeDark(prefs),
      themeMode: currentThemeMode,
      home: useBiometrics ? const AuthPage() : const HomePage(),
    );
  }
}
