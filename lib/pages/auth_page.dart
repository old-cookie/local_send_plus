import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/features/security/security_service.dart';
import 'package:local_send_plus/pages/home_page.dart';
import 'package:local_send_plus/providers/settings_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _isAuthenticating = false;
  bool _authFailed = false;
  String _statusText = '';
  bool _showBiometricHelp = false;
  String _biometricErrorCode = '';
  @override
  void initState() {
    super.initState();
    print('AuthPage initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAuthenticate();
    });
  }

  Future<void> _checkAndAuthenticate() async {
    print('Checking authentication method');
    if (kIsWeb) {
      print('Web platform, proceeding to app');
      _proceedToApp();
      return;
    }
    final bool biometricEnabled = ref.read(biometricAuthProvider);
    print('Biometric enabled in settings: $biometricEnabled');
    if (biometricEnabled) {
      print('Attempting biometric authentication');
      _authenticate();
    } else {
      print('Biometric not enabled, proceeding to app');
      _proceedToApp();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) {
      print('Authentication already in progress, ignoring request');
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _authFailed = false;
      _statusText = 'Authenticating...';
      _showBiometricHelp = false;
      _biometricErrorCode = '';
    });
    final securityService = ref.read(securityServiceProvider);
    const String reason = 'Please authenticate to open LocalSend Plus';
    print('Displaying biometric prompt: $reason');
    final Map<String, dynamic> result = await securityService.authenticateWithBiometrics(reason);
    final bool authenticated = result['success'] as bool;
    if (!mounted) return;
    if (authenticated) {
      print('Authentication successful');
      _proceedToApp();
    } else {
      print('Authentication failed: ${result['errorMessage']} (Code: ${result['errorCode']})');
      setState(() {
        _authFailed = true;
        _isAuthenticating = false;
        _statusText = result['errorMessage'] ?? 'Authentication failed, please try again.';
        _biometricErrorCode = result['errorCode'] ?? SecurityService.errorUnknown;
        _showBiometricHelp = true; // Show help section on failure
      });
    }
  }

  void _proceedToApp() {
    if (!mounted) return;
    print('Proceeding to HomePage');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomePage()));
  }

  void _exitApp() {
    print('User chose to exit app');
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  Widget _buildBiometricHelpSection() {
    String helpMessage = '';
    switch (_biometricErrorCode) {
      case SecurityService.errorNotAvailable:
        helpMessage = '• Biometrics not available or not supported on this device.\n• Check system settings.';
        break;
      case SecurityService.errorNotEnrolled:
        helpMessage = '• No fingerprints or face data enrolled.\n• Please add biometric data in system settings.';
        break;
      case SecurityService.errorLockedOut:
        helpMessage = '• Authentication locked due to too many attempts.\n• Please try again later or use device passcode.';
        break;
      case SecurityService.errorPermanentlyLockedOut:
        helpMessage = '• Authentication permanently locked.\n• Device passcode unlock required.';
        break;
      case SecurityService.errorPasscodeNotSet: // iOS specific
        helpMessage = '• Device passcode is not set.\n• Please set a passcode in system settings.';
        break;
      // Add cases for other specific errors if needed
      default: // Handles Unknown and other codes
        helpMessage = '• Ensure sensor is clean.\n• Use an enrolled finger/face.\n• Try again.';
        break;
    }
    return Column(
      children: [
        const SizedBox(height: 16),
        Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 32), // Add some horizontal margin
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: Text(helpMessage, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0), // Add padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(padding: EdgeInsets.all(32.0), child: Icon(Icons.fingerprint, size: 100)),
              Text('LocalSend Plus', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 50),
              if (_statusText.isNotEmpty && !_isAuthenticating)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _statusText,
                    style: TextStyle(color: _authFailed ? Theme.of(context).colorScheme.error : Theme.of(context).textTheme.bodyMedium?.color),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_showBiometricHelp) _buildBiometricHelpSection(),
              const SizedBox(height: 30),
              if (_isAuthenticating)
                const Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Please complete biometric authentication')])
              else if (_authFailed)
                Column(
                  children: [
                    ElevatedButton.icon(onPressed: _authenticate, icon: const Icon(Icons.fingerprint), label: const Text('Retry')),
                    const SizedBox(height: 10),
                    TextButton(onPressed: _exitApp, child: const Text('Exit App')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
