import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/pages/home_page.dart';
import 'package:local_send_plus/pages/auth_page.dart';
import 'package:local_send_plus/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool useBiometrics = ref.watch(biometricAuthProvider);
    return MaterialApp(
      title: 'LocalSend Plus',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: useBiometrics ? const AuthPage() : const HomePage(),
    );
  }
}
