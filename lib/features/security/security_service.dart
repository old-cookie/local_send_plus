import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  // ignore: unused_field
  final Ref _ref;
  final LocalAuthentication _localAuth;
  static const String errorUnknown = 'Unknown';
  static const String errorNotAvailable = 'NotAvailable';
  static const String errorNotEnrolled = 'NotEnrolled';
  static const String errorPasscodeNotSet = 'PasscodeNotSet';
  static const String errorLockedOut = 'LockedOut';
  static const String errorPermanentlyLockedOut = 'PermanentlyLockedOut';
  SecurityService(this._ref) : _localAuth = LocalAuthentication();
  Future<void> initialize() async {
    print('SecurityService initialize: No security features enabled (HTTP only).');
    await Future.value();
  }

  Future<Map<String, dynamic>> authenticateWithBiometrics(String localizedReason) async {
    Map<String, dynamic> result = {'success': false, 'errorCode': errorUnknown, 'errorMessage': 'An unknown error occurred.'};
    if (kIsWeb) {
      print('Biometric authentication is not available on the web.');
      result['errorCode'] = errorNotAvailable;
      result['errorMessage'] = 'Biometric authentication is not available on the web.';
      return result;
    }
    try {
      final bool deviceSupported = await _localAuth.isDeviceSupported();
      if (!deviceSupported) {
        result['errorCode'] = errorNotAvailable;
        result['errorMessage'] = 'Biometrics not supported on this device.';
        print(result['errorMessage']);
        return result;
      }
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        result['errorCode'] = errorNotAvailable;
        result['errorMessage'] = 'Biometrics currently unavailable.';
        print(result['errorMessage']);
        return result;
      }
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        result['errorCode'] = errorNotEnrolled;
        result['errorMessage'] = 'No biometrics enrolled on this device.';
        print(result['errorMessage']);
        return result;
      }
      print("Available biometrics: $availableBiometrics");
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (didAuthenticate) {
        result['success'] = true;
        result['errorCode'] = '';
        result['errorMessage'] = 'Authentication successful.';
      } else {
        result['success'] = false;
        result['errorCode'] = errorUnknown; // Default if no PlatformException caught
        result['errorMessage'] = 'Authentication failed or was cancelled.';
      }
      return result;
    } on PlatformException catch (e) {
      print('Biometric authentication error: ${e.code} - ${e.message}');
      result['success'] = false;
      result['errorCode'] = e.code;
      result['errorMessage'] = e.message ?? 'An authentication error occurred.';
      switch (e.code) {
        case 'LockedOut':
          result['errorCode'] = errorLockedOut;
          break;
        case 'PermanentlyLockedOut':
          result['errorCode'] = errorPermanentlyLockedOut;
          break;
        case 'NotAvailable':
          result['errorCode'] = errorNotAvailable;
          break;
        case 'NotEnrolled':
          result['errorCode'] = errorNotEnrolled;
          break;
        case 'PasscodeNotSet':
          result['errorCode'] = errorPasscodeNotSet;
          break;
      }
      return result;
    } catch (e) {
      print('Unexpected error during biometric authentication: $e');
      result['success'] = false;
      result['errorCode'] = errorUnknown;
      result['errorMessage'] = 'An unexpected error occurred: $e';
      return result;
    }
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  final service = SecurityService(ref);
  return service;
});
final initializedSecurityServiceProvider = FutureProvider<SecurityService>((ref) async {
  final service = ref.watch(securityServiceProvider);
  await service.initialize();
  return service;
});
