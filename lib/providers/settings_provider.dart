import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:encrypt_shared_preferences/provider.dart';
// Import main.dart to access its sharedPreferencesProvider
import 'package:local_send_plus/main.dart' show sharedPreferencesProvider;

const String prefDeviceAlias = 'pref_device_alias';
const String prefDestinationDir = 'pref_destination_dir';
const String prefUseBiometricAuth = 'pref_use_biometric_auth';



// Update provider to watch the correct provider and load initial state
final deviceAliasProvider = StateNotifierProvider<DeviceAliasNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeviceAliasNotifier(prefs)..loadInitialAlias();
});

class DeviceAliasNotifier extends StateNotifier<String> {
  // Update type to EncryptedSharedPreferencesAsync
  final EncryptedSharedPreferencesAsync _prefs;

  // Provide default alias synchronously
  DeviceAliasNotifier(this._prefs) : super(_generateDefaultAlias());

  // Load initial alias asynchronously
  Future<void> loadInitialAlias() async {
    // Await getString and provide default
    final initialAlias = await _prefs.getString(prefDeviceAlias, defaultValue: _generateDefaultAlias());
    if (state != initialAlias) { // Update only if different from default
      state = initialAlias!; // Use null assertion as default is provided
    }
    // Ensure a value is saved if it wasn't already
    if (await _prefs.getString(prefDeviceAlias) == null) {
       await _prefs.setString(prefDeviceAlias, state);
    }
  }

  static String _generateDefaultAlias() {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      } else if (Platform.isLinux) {
        return Platform.localHostname;
      } else if (Platform.isMacOS) {
        return Platform.localHostname;
      } else if (Platform.isWindows) {
        return Platform.localHostname;
      }
    } catch (e) {
      print("Error generating default alias: $e");
    }
    return 'LocalSend Device';
  }

  Future<void> setAlias(String newAlias) async {
    if (newAlias.isNotEmpty) {
      // Use await with EncryptedSharedPreferencesAsync
      await _prefs.setString(prefDeviceAlias, newAlias);
      state = newAlias;
    }
  }
}

// Update provider to watch the correct provider and load initial state
final destinationDirectoryProvider = StateNotifierProvider<DestinationDirectoryNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DestinationDirectoryNotifier(prefs)..loadInitialDirectory();
});

class DestinationDirectoryNotifier extends StateNotifier<String?> {
  // Update type to EncryptedSharedPreferencesAsync
  final EncryptedSharedPreferencesAsync _prefs;

  // Provide default null state synchronously
  DestinationDirectoryNotifier(this._prefs) : super(null);

  // Load initial directory asynchronously
  Future<void> loadInitialDirectory() async {
    // Await getString (no default needed, null is acceptable)
    final initialDir = await _prefs.getString(prefDestinationDir);
    if (state != initialDir) {
      state = initialDir;
    }
  }

  Future<void> setDestinationDirectory(String newDir) async {
    // Use await with EncryptedSharedPreferencesAsync
    await _prefs.setString(prefDestinationDir, newDir);
    state = newDir;
  }
}

// Update provider to watch the correct provider and load initial state
final biometricAuthProvider = StateNotifierProvider<BiometricAuthNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BiometricAuthNotifier(prefs)..loadInitialAuthState();
});

class BiometricAuthNotifier extends StateNotifier<bool> {
  // Update type to EncryptedSharedPreferencesAsync
  final EncryptedSharedPreferencesAsync _prefs;

  // Provide default false state synchronously
  BiometricAuthNotifier(this._prefs) : super(false);

  // Load initial auth state asynchronously
  Future<void> loadInitialAuthState() async {
    // Await getBool and provide default
    final initialValue = await _prefs.getBool(prefUseBiometricAuth, defaultValue: false);
    if (state != initialValue) {
      state = initialValue!; // Use null assertion as default is provided
    }
  }

  Future<void> setBiometricAuth(bool enabled) async {
    // Use await with EncryptedSharedPreferencesAsync
    await _prefs.setBool(prefUseBiometricAuth, enabled);
    state = enabled;
  }
}
