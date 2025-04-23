import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/providers/settings_provider.dart' hide sharedPreferencesProvider;
import 'package:file_picker/file_picker.dart';
import 'package:local_send_plus/main.dart';

void selectionHaptic() {
  HapticFeedback.selectionClick();
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  Widget _buildBrightnessSegmentedButton(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final currentBrightness = prefs.getString("brightness") ?? "system";
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: "dark", label: Text("Dark"), icon: Icon(Icons.brightness_4_rounded)),
        ButtonSegment(value: "system", label: Text("System"), icon: Icon(Icons.brightness_auto_rounded)),
        ButtonSegment(value: "light", label: Text("Light"), icon: Icon(Icons.brightness_high_rounded)),
      ],
      selected: {currentBrightness},
      onSelectionChanged: (Set<String> newSelection) async {
        selectionHaptic();
        final newBrightness = newSelection.first;
        await ref.read(themeModeNotifierProvider.notifier).setThemeMode(newBrightness);
      },
    );
  }

  Future<void> _showEditAliasDialog(BuildContext context, WidgetRef ref, String currentAlias) async {
    final TextEditingController controller = TextEditingController(text: currentAlias);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Device Alias'),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Enter new alias')),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final newAlias = controller.text.trim();
                if (newAlias.isNotEmpty) {
                  await ref.read(deviceAliasProvider.notifier).setAlias(newAlias);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alias updated successfully!')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alias cannot be empty.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDestinationDirectory(BuildContext context, WidgetRef ref) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Destination Directory');
      if (selectedDirectory != null) {
        await ref.read(destinationDirectoryProvider.notifier).setDestinationDirectory(selectedDirectory);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Destination directory set to: $selectedDirectory')));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Directory selection cancelled.')));
        }
      }
    } catch (e) {
      print('Error picking directory: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting directory: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentAlias = ref.watch(deviceAliasProvider);
    final String? currentDestinationDir = ref.watch(destinationDirectoryProvider);
    final bool useBiometricAuth = ref.watch(biometricAuthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Device Alias'),
            subtitle: Text(currentAlias),
            onTap: () {
              _showEditAliasDialog(context, ref, currentAlias);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Destination Directory'),
            subtitle: Text(currentDestinationDir ?? 'Not set (Defaults to Downloads)'),
            onTap: () {
              _pickDestinationDirectory(context, ref);
            },
          ),
          const Divider(),
          if (!kIsWeb)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Use Biometric Authentication'),
              subtitle: const Text('Require fingerprint/face ID to open the app'),
              value: useBiometricAuth,
              onChanged: (bool value) {
                ref.read(biometricAuthProvider.notifier).setBiometricAuth(value);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Brightness'),
            subtitle: Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildBrightnessSegmentedButton(context, ref)),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
