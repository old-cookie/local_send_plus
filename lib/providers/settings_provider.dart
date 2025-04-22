import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefDeviceAlias = 'pref_device_alias';
const String prefDestinationDir = 'pref_destination_dir';
const String prefUseBiometricAuth = 'pref_use_biometric_auth';
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});
final deviceAliasProvider = StateNotifierProvider<DeviceAliasNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  final initialAlias = prefs?.getString(prefDeviceAlias);
  return DeviceAliasNotifier(prefs, initialAlias);
});

class DeviceAliasNotifier extends StateNotifier<String> {
  final SharedPreferences? _prefs;
  DeviceAliasNotifier(this._prefs, String? initialAlias) : super(initialAlias ?? _generateDefaultAlias()) {
    if (initialAlias == null && _prefs != null) {
      _prefs.setString(prefDeviceAlias, state);
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
    if (_prefs != null && newAlias.isNotEmpty) {
      await _prefs.setString(prefDeviceAlias, newAlias);
      state = newAlias;
    }
  }
}

final destinationDirectoryProvider = StateNotifierProvider<DestinationDirectoryNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  final initialDir = prefs?.getString(prefDestinationDir);
  return DestinationDirectoryNotifier(prefs, initialDir);
});

class DestinationDirectoryNotifier extends StateNotifier<String?> {
  final SharedPreferences? _prefs;
  DestinationDirectoryNotifier(this._prefs, String? initialDir) : super(initialDir);
  Future<void> setDestinationDirectory(String newDir) async {
    if (_prefs != null) {
      await _prefs.setString(prefDestinationDir, newDir);
      state = newDir;
    }
  }
}

final biometricAuthProvider = StateNotifierProvider<BiometricAuthNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  final initialValue = prefs?.getBool(prefUseBiometricAuth) ?? false;
  return BiometricAuthNotifier(prefs, initialValue);
});

class BiometricAuthNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;
  BiometricAuthNotifier(this._prefs, bool initialValue) : super(initialValue);
  Future<void> setBiometricAuth(bool enabled) async {
    if (_prefs != null) {
      await _prefs.setBool(prefUseBiometricAuth, enabled);
      state = enabled;
    }
  }
}
