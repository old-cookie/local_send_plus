import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/pages/home_page.dart';
import 'package:local_send_plus/pages/auth_page.dart';
import 'package:local_send_plus/providers/settings_provider.dart';
import 'package:local_send_plus/services/theme_service.dart';
import 'package:encrypt_shared_preferences/provider.dart';
import 'package:local_send_plus/features/security/custom_encryptor.dart'; // Import the custom encryptor

// Define a record type for the theme state
typedef ThemeState = ({ThemeMode mode, ThemeData lightTheme, ThemeData darkTheme});

// Update provider to use EncryptedSharedPreferencesAsync
final sharedPreferencesProvider = Provider<EncryptedSharedPreferencesAsync>((ref) {
  throw UnimplementedError('EncryptedSharedPreferencesAsync provider was not overridden');
});

// Update StateNotifierProvider to use the new ThemeState record
final themeStateNotifierProvider = StateNotifierProvider<ThemeStateNotifier, ThemeState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  // Provide initial default themes while loading
  return ThemeStateNotifier(prefs)..loadInitialTheme();
});

// Update StateNotifier to manage ThemeState and handle async operations
class ThemeStateNotifier extends StateNotifier<ThemeState> {
  final EncryptedSharedPreferencesAsync _prefs;

  ThemeStateNotifier(this._prefs)
      : super((
          mode: ThemeMode.system, // Default mode
          lightTheme: themeModifier(ThemeData.light()), // Default light theme
          darkTheme: themeModifier(ThemeData.dark()) // Default dark theme
        ));

  // Load initial theme asynchronously
  Future<void> loadInitialTheme() async {
    final mode = await _calculateThemeMode(_prefs);
    final light = await themeLight(_prefs);
    final dark = await themeDark(_prefs);
    state = (mode: mode, lightTheme: light, darkTheme: dark);
  }

  // Make calculation async and return Future<ThemeMode>
  static Future<ThemeMode> _calculateThemeMode(EncryptedSharedPreferencesAsync prefs) async {
    return await themeMode(prefs);
  }

  // Update theme mode and themes
  Future<void> setThemeMode(String brightnessValue) async {
    await _prefs.setString("brightness", brightnessValue);
    // Recalculate and update state
    await loadInitialTheme();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize EncryptedSharedPreferencesAsync with CustomEncryptor
  final key = "localsendplusmax"; // Placeholder key - replace with secure key management
  await EncryptedSharedPreferencesAsync.initialize(key, encryptor: CustomEncryptor());
  final prefsInstance = EncryptedSharedPreferencesAsync.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefsInstance)],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool useBiometrics = ref.watch(biometricAuthProvider);
    // Watch the new theme state provider
    final themeState = ref.watch(themeStateNotifierProvider);

    return MaterialApp(
      title: 'LocalSend Plus',
      // Use themes from the state record
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.mode,
      home: useBiometrics ? const AuthPage() : const HomePage(),
    );
  }
}
