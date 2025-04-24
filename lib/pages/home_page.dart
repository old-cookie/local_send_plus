import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/features/discovery/discovery_provider.dart';
import 'package:local_send_plus/features/discovery/discovery_service.dart';
import 'package:local_send_plus/features/server/server_service.dart';
import 'dart:io';
import 'package:local_send_plus/features/send/send_service.dart';
import 'package:local_send_plus/models/device_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_send_plus/features/receive/received_file_provider.dart';
import 'package:local_send_plus/features/receive/received_text_provider.dart';
import 'package:local_send_plus/widgets/received_file_dialog.dart';
import 'package:local_send_plus/widgets/received_text_dialog.dart';
import 'package:local_send_plus/models/received_file_info.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:local_send_plus/pages/video_editor_page.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:local_send_plus/pages/settings_page.dart';
import 'package:local_send_plus/features/ai_chat/chat_screen.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:local_send_plus/providers/settings_provider.dart';
import 'package:local_send_plus/features/server/server_provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:local_send_plus/pages/qr_scanner_page.dart';
import 'package:logging/logging.dart'; // Import the logging package

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _log = Logger('HomePage'); // Create a logger instance
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isSending = false;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  // Remove local _favorites list - use provider directly
  // static const String _favoritesPrefKey = 'favorite_devices';
  StreamSubscription? _receivedFileSubscription;
  StreamSubscription? _receivedTextSubscription;
  DiscoveryService? _discoveryService;
  ServerService? _serverService;
  String? _localIpAddress;
  String? _scanResult;

  @override
  void initState() {
    super.initState();
    // Remove _loadFavorites(); - favorites are loaded via provider
    _fetchLocalIp();
    Future.microtask(() async {
      if (!mounted) return;
      final localRef = ref;
      _serverService = localRef.read(serverServiceProvider(2706));
      _discoveryService = localRef.read(discoveryServiceProvider);
      await _serverService!.startServer();
      if (!mounted) return;
      await _discoveryService!.startDiscovery();
      if (!mounted) return;
      _receivedFileSubscription = localRef.read(receivedFileProvider.notifier).stream.listen((ReceivedFileInfo? fileInfo) {
        if (fileInfo != null) {
          if (!mounted) return;
          // Removed context capture and route check before microtask
          Future.microtask(() {
            // Check mounted *inside* microtask before using context
            if (!mounted) return;
            showDialog(
              context: context, // Use context directly after mounted check
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return ReceivedFileDialog(fileInfo: fileInfo);
              },
            ).then((_) {
              if (mounted) {
                localRef.read(receivedFileProvider.notifier).clearReceivedFile();
              }
            });
          });
        }
      });
      _receivedTextSubscription = localRef.read(receivedTextProvider.notifier).stream.listen((String? text) {
        if (text != null) {
          if (!mounted) return;
          // Removed context capture and route check before microtask
          Future.microtask(() {
            // Check mounted *inside* microtask before using context
            if (!mounted) return;
            showDialog(
              context: context, // Use context directly after mounted check
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return ReceivedTextDialog(receivedText: text);
              },
            ).then((_) {
              if (mounted) {
                localRef.read(receivedTextProvider.notifier).state = null;
              }
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _discoveryService?.stopDiscovery();
    _serverService?.stopServer();
    _receivedFileSubscription?.cancel();
    _receivedTextSubscription?.cancel();
    _ipController.dispose();
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocalIp() async {
    if (kIsWeb) return;
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (mounted) {
        setState(() {
          _localIpAddress = ip;
        });
      }
    } catch (e) {
      _log.warning("Failed to get local IP", e); // Use logger
      if (mounted) {
        // Optionally show a snackbar or log error to UI if needed
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get IP address: $e')));
      }
    }
  }

  // --- Add NFC Dialog Method ---
  Future<void> _showNfcDialog(BuildContext context, WidgetRef ref) async {
    // Store BuildContext before any async operations
    final dialogContext = context;
    showDialog(
      context: dialogContext,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('NFC Actions'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!mounted) return;
                await ref.read(nfcServiceProvider).writeNdef(context);
              },
              child: const ListTile(
                leading: Icon(Icons.upload_file),
                title: Text('Send Device Info via NFC'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!mounted) return;
                // Store context before async gap
                final currentContext = context;
                // Call the read method, passing the callback to add to favorites
                await ref.read(nfcServiceProvider).readNdef(currentContext, (data) {
                  // This callback might run after the widget is disposed
                  if (!mounted) {
                    _log.warning("NFC Read Callback: Widget unmounted before processing data: $data");
                    return;
                  }
                  _log.info("NFC Read Callback: Received data: $data"); // Use logger
                  // Use the main settingsProvider notifier to add the favorite
                  final scaffoldMessenger = ScaffoldMessenger.of(currentContext); // Use stored context
                  try {
                    ref.read(settingsProvider.notifier).addFavoriteDevice(data);
                    _log.info("NFC Read Callback: Called addFavoriteDevice successfully."); // Use logger
                    // Optionally show a confirmation SnackBar here if NfcService doesn't
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Added ${data['name']} (${data['ip']}) to favorites via NFC.')));
                  } catch (e) {
                    _log.severe("NFC Read Callback: Error calling addFavoriteDevice", e); // Use logger
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error adding favorite via NFC: $e')));
                  }
                });
              },
              child: const ListTile(
                leading: Icon(Icons.download_for_offline),
                title: Text('Receive Device Info via NFC'),
                subtitle: Text('Adds received device to favorites'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
  // --- End NFC Dialog Method ---

  // Remove _loadFavorites and _saveFavorites - managed by SettingsNotifier

  Future<bool> _addFavoriteManually() async {
    // Renamed to avoid conflict if needed
    final String ip = _ipController.text.trim();
    final String name = _nameController.text.trim();
    if (!mounted) return false;
    if (ip.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both IP address and name.')));
      return false;
    }
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid IP address format.')));
      return false;
    }
    // Use the SettingsNotifier to add the favorite
    final deviceData = {'ip': ip, 'name': name}; // Assuming port is fixed or handled elsewhere
    // Rely on the check within addFavoriteDevice in the provider

    _log.info("Attempting to add favorite: $deviceData"); // Use logger
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
    final focusScope = FocusScope.of(context); // Store before async gap
    try {
      await ref.read(settingsProvider.notifier).addFavoriteDevice(deviceData);
      _log.info("Successfully called addFavoriteDevice for: $deviceData"); // Use logger
      if (!mounted) return false; // Check after await
      // Clear fields and unfocus after successful add
      _ipController.clear();
      _nameController.clear();
      focusScope.unfocus(); // Use stored scope
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Added $name to favorites.'))); // Use stored messenger
      return true; // Indicate success
    } catch (e) {
      _log.severe("Error calling addFavoriteDevice", e); // Use logger
      if (!mounted) return false; // Check after await (though technically before context use here)
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error adding favorite: $e'))); // Use stored messenger
      return false;
    }
  }

  Future<void> _initiateSend(DeviceInfo targetDevice) async {
    if (!mounted) return;
    setState(() {
      _isSending = true;
    });
    String? errorMessage;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
    try {
      if (_selectedFileName != null && (_selectedFilePath != null || _selectedFileBytes != null)) {
        // No await before this context use
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Sending file $_selectedFileName to ${targetDevice.alias}...')));
        await ref.read(sendServiceProvider).sendFile(targetDevice, _selectedFileName!, filePath: _selectedFilePath, fileBytes: _selectedFileBytes);
        if (!mounted) return; // Check after await
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Sent $_selectedFileName successfully!')));
        // setState is safe if mounted check is done before
        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
          _selectedFileBytes = null;
        });
      } else {
        final textToSend = _textController.text.trim();
        if (textToSend.isNotEmpty) {
          // No await before this context use
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Text('Sending text to ${targetDevice.alias}...'),
                ],
              ),
              duration: const Duration(seconds: 30),
            ),
          );
          try {
            await ref.read(sendServiceProvider).sendText(targetDevice, textToSend);
            if (!mounted) return; // Check after await
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Text sent successfully!'), backgroundColor: Colors.green));
            _textController.clear(); // Safe if mounted check passed
          } catch (e) {
            errorMessage = e.toString(); // Store error message
          }
        } else {
          // No await before this context use
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please enter text or select a file to send.')));
          // setState is safe here as no await preceded it in this block
          setState(() {
            _isSending = false;
          });
          return;
        }
      }
    } catch (e) {
      errorMessage ??= e.toString(); // Ensure errorMessage is set if it wasn't from inner catch
    } finally {
      // Check mounted *inside* finally before using context or setState, but DO NOT return.
      if (mounted) {
        if (errorMessage != null) {
          // Use the stored scaffoldMessenger
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error sending: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: () => _initiateSend(targetDevice)),
            ),
          );
        }
        setState(() {
          _isSending = false;
        });
      }
      // If not mounted, the finally block completes without doing unsafe operations.
    }
  }

  Widget _buildSelectedFileThumbnail() {
    if (_selectedFileName == null) {
      return const SizedBox.shrink();
    }
    final fileNameLower = _selectedFileName!.toLowerCase();
    final isImage = fileNameLower.endsWith('.jpg') ||
        fileNameLower.endsWith('.jpeg') ||
        fileNameLower.endsWith('.png') ||
        fileNameLower.endsWith('.gif') ||
        fileNameLower.endsWith('.bmp') ||
        fileNameLower.endsWith('.webp');
    final isVideo = fileNameLower.endsWith('.mp4') ||
        fileNameLower.endsWith('.mov') ||
        fileNameLower.endsWith('.avi') ||
        fileNameLower.endsWith('.mkv') ||
        fileNameLower.endsWith('.wmv');
    Widget thumbnailWidget;
    if (isImage) {
      if (_selectedFileBytes != null) {
        thumbnailWidget = Image.memory(_selectedFileBytes!, fit: BoxFit.cover);
      } else if (!kIsWeb && _selectedFilePath != null) {
        thumbnailWidget = Image.file(File(_selectedFilePath!), fit: BoxFit.cover);
      } else {
        thumbnailWidget = const Icon(Icons.image_not_supported, size: 50);
      }
    } else if (isVideo) {
      if (!kIsWeb && _selectedFilePath != null) {
        thumbnailWidget = FutureBuilder<Uint8List?>(
          future: FlutterVideoThumbnailPlus.thumbnailData(video: _selectedFilePath!, imageFormat: ImageFormat.jpeg, maxWidth: 150, quality: 25),
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              _log.warning('Error generating video thumbnail', snapshot.error); // Use logger
              return const Icon(Icons.video_file_outlined, size: 50);
            } else if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            } else {
              return const Icon(Icons.video_file_outlined, size: 50);
            }
          },
        );
      } else {
        thumbnailWidget = const Icon(Icons.video_file_outlined, size: 50);
      }
    } else {
      // Add the missing else block for other file types
      thumbnailWidget = const Icon(Icons.insert_drive_file_outlined, size: 50);
    }
    // Move the return Padding inside the method
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected: $_selectedFileName', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4.0)),
            alignment: Alignment.center,
            child: ClipRRect(borderRadius: BorderRadius.circular(4.0), child: thumbnailWidget),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DeviceInfo> discoveredDevices = ref.watch(discoveredDevicesProvider);
    final alias = ref.watch(deviceAliasProvider);
    final serverState = ref.watch(serverStateProvider);
    String? qrData;
    if (serverState.isRunning && serverState.port != null && _localIpAddress != null) {
      final qrInfo = {'ip': _localIpAddress, 'port': serverState.port, 'alias': alias};
      qrData = jsonEncode(qrInfo);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LocalSend Plus'),
        actions: [
          IconButton(icon: const Icon(Icons.star), onPressed: _showFavoritesDialog, tooltip: 'Show Favorites'),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discovery running automatically...')));
            },
            tooltip: 'Refresh Devices',
          ),
          // Wrap the PopupMenuButton with a Consumer to provide ref
          Consumer(builder: (context, ref, child) {
            // Watch the provider *outside* the itemBuilder
            final nfcAvailableAsync = ref.watch(nfcAvailabilityProvider);
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More Options',
              onSelected: (String result) {
                // ref is available in this scope from the Consumer builder
                switch (result) {
                  case 'nfc_actions':
                    _showNfcDialog(context, ref);
                    break;
                  case 'scan_qr':
                    _scanQrCode();
                    break;
                  case 'ai_chat':
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen()));
                    break;
                  case 'settings':
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                    break;
                }
              },
              // Pass the state down to itemBuilder
              itemBuilder: (BuildContext context) {
                final List<PopupMenuEntry<String>> items = [];

                // Use the state captured by the Consumer's builder
                nfcAvailableAsync.when(
                  data: (isAvailable) {
                    if (isAvailable) {
                      items.add(const PopupMenuItem<String>(
                        value: 'nfc_actions',
                        child: ListTile(leading: Icon(Icons.nfc), title: Text('NFC Send/Receive')),
                      ));
                    }
                  },
                  loading: () {
                    items.add(const PopupMenuItem<String>(
                      enabled: false,
                      child: ListTile(
                        leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        title: Text('Checking NFC...'),
                      ),
                    ));
                  },
                  error: (err, stack) {
                    items.add(PopupMenuItem<String>(
                      enabled: false,
                      child: ListTile(
                        leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        title: const Text('NFC Error'),
                      ),
                    ));
                  },
                );

                // Add other items conditionally, adding dividers
                bool needsDivider = items.isNotEmpty && items.last is! PopupMenuDivider;

                if (!kIsWeb) {
                  if (needsDivider) items.add(const PopupMenuDivider());
                  items.add(const PopupMenuItem<String>(
                    value: 'scan_qr',
                    child: ListTile(leading: Icon(Icons.qr_code_scanner), title: Text('Scan QR')),
                  ));
                  needsDivider = true;
                }

                if (!kIsWeb) {
                  if (needsDivider) items.add(const PopupMenuDivider());
                  items.add(const PopupMenuItem<String>(
                    value: 'ai_chat',
                    child: ListTile(leading: Icon(Icons.chat_bubble_outline), title: Text('AI Chat')),
                  ));
                  needsDivider = true;
                }

                if (needsDivider) items.add(const PopupMenuDivider());
                items.add(const PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
                ));

                return items;
              },
            );
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (qrData != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: PrettyQrView.data(
                            data: qrData,
                            decoration: const PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Visibility(
                  // Hide text field when a file is selected
                  visible: _selectedFileName == null,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: 'Enter Text to Send',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Align(alignment: Alignment.centerLeft, child: Text('Discovered Devices (${discoveredDevices.length}):')),
          ),
          Expanded(
            child: discoveredDevices.isEmpty
                ? const Center(child: Text('Searching for devices...'))
                : ListView.builder(
                    itemCount: discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = discoveredDevices[index];
                      return ListTile(
                        leading: _isSending ? const CircularProgressIndicator() : const Icon(Icons.devices),
                        title: Text(device.alias),
                        subtitle: Text('${device.ip}:${device.port}'),
                        onTap: _isSending ? null : () => _initiateSend(device),
                      );
                    },
                  ),
          ),
          _buildSelectedFileThumbnail(),
          Visibility(
            // Hide when keyboard is visible
            visible: MediaQuery.of(context).viewInsets.bottom == 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0), // Adjusted bottom padding if needed when hidden
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (kIsWeb)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach File'),
                      onPressed: () => _pickFile(context, FileType.any),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      onPressed: () {
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext bc) {
                            return SafeArea(
                              child: Wrap(
                                children: <Widget>[
                                  ListTile(
                                    leading: const Icon(Icons.photo),
                                    title: const Text('Photo'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _pickFile(context, FileType.image);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.videocam),
                                    title: const Text('Video'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _pickFile(context, FileType.video);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.attach_file),
                                    title: const Text('File'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _pickFile(context, FileType.any);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFavoritesDialog() async {
    // No need to await _loadFavorites(); - read directly from provider
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Use Consumer instead of StatefulBuilder to react to provider changes
        return Consumer(
          builder: (context, ref, child) {
            // Read the current favorites list from the provider
            final favoritesList = ref.watch(favoriteDevicesProvider);
            _log.fine("Favorites Dialog Consumer rebuilt. Received list: $favoritesList"); // Use logger (fine level for rebuilds)
            // Convert List<Map<String, String>> to List<DeviceInfo> for compatibility
            // Assuming a fixed port or handle differently if port varies
            final favorites = favoritesList.map((fav) => DeviceInfo(ip: fav['ip']!, port: 2706, alias: fav['name']!)).toList();

            return AlertDialog(
              title: const Text('Favorite Devices'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(labelText: 'IP Address', hintText: 'e.g., 192.168.1.100', border: OutlineInputBorder()),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Device Name', hintText: 'e.g., My Laptop', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Favorite'),
                        onPressed: () async {
                          // Call the updated manual add method
                          await _addFavoriteManually();
                          // No need for setDialogState, Consumer rebuilds automatically
                        },
                      ),
                      const Divider(height: 24),
                      favorites.isEmpty // Use the list from the provider
                          ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text('No favorites added yet.')))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: favorites.length, // Use the list from the provider
                              itemBuilder: (context, index) {
                                if (index < 0 || index >= favorites.length) {
                                  // Use the list from the provider
                                  return const SizedBox.shrink();
                                }
                                final device = favorites[index]; // Use the list from the provider
                                // Convert DeviceInfo back to Map for removal function if needed
                                final deviceData = {'ip': device.ip, 'name': device.alias};
                                return ListTile(
                                  leading: const Icon(Icons.star),
                                  title: Text(device.alias),
                                  subtitle: Text('${device.ip}:${device.port}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Remove Favorite',
                                    onPressed: () async {
                                      _log.info("Attempting to remove favorite with data: $deviceData"); // Use logger
                                      final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
                                      final removedDeviceAlias = device.alias;
                                      // No need for mounted check here before await
                                      try {
                                        // Call the provider's remove method
                                        await ref.read(settingsProvider.notifier).removeFavoriteDevice(deviceData);
                                        _log.info("Successfully called removeFavoriteDevice for: $deviceData"); // Use logger
                                        if (!mounted) return; // Check after await
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Removed $removedDeviceAlias from favorites.')));
                                      } catch (e) {
                                        _log.severe("Error calling removeFavoriteDevice", e); // Use logger
                                        if (!mounted) return; // Check after await (though technically before context use here)
                                        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error removing favorite: $e')));
                                      }
                                      // No need for setDialogState
                                    },
                                  ),
                                  onTap: _isSending
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                          if (!mounted) return;
                                          _initiateSend(device);
                                        },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    _ipController.clear();
                    _nameController.clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }, // End Consumer builder
        );
      },
    );
  }

  Future<void> _pickFile(BuildContext context, FileType fileType) async {
    bool permissionGranted = false;
    String? permissionTypeDenied;
    if (kIsWeb) {
      permissionGranted = true;
    } else {
      if (Platform.isAndroid) {
        if (!mounted) return;
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (!mounted) return;
        final sdkInt = androidInfo.version.sdkInt;
        List<Permission> permissionsToRequest = [];
        if (sdkInt >= 33) {
          if (fileType == FileType.image) permissionsToRequest.add(Permission.photos);
          if (fileType == FileType.video) permissionsToRequest.add(Permission.videos);
          if (permissionsToRequest.isEmpty) {
            permissionGranted = true;
          }
        } else {
          permissionsToRequest.add(Permission.storage);
        }
        if (permissionsToRequest.isNotEmpty) {
          if (!mounted) return;
          Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
          if (!mounted) return;
          permissionGranted = statuses.values.every((status) => status.isGranted);
          if (!permissionGranted) {
            permissionTypeDenied = statuses.entries.firstWhere((entry) => !entry.value.isGranted).key.toString().split('.').last;
          }
        }
      } else {
        if (fileType == FileType.image || fileType == FileType.video) {
          if (!mounted) return;
          var status = await Permission.photos.request();
          if (!mounted) return;
          permissionGranted = status.isGranted;
          if (!permissionGranted) permissionTypeDenied = 'photos';
        } else {
          permissionGranted = true;
        }
      }
    }

    if (!mounted) return; // Check mounted *after* async permission requests

    // Removed ScaffoldMessenger capture here.

    if (!permissionGranted) {
      // Use context directly here, guarded by the 'mounted' check above.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${permissionTypeDenied ?? 'Required'} permission denied')));
      return;
    }

    // ScaffoldMessenger will be captured inside the catch block if needed, after its own mounted check.
    try {
      // No context use before await here
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      if (!mounted) return;
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType, withData: true);
      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.single;
        _log.info(
            'FilePicker result on ${kIsWeb ? "Web" : "Native"}: Name: ${file.name}, Path: ${kIsWeb ? "N/A (Web)" : file.path}, Bytes: ${file.bytes?.length}'); // Use logger
        final String fileName = file.name;
        final Uint8List? fileBytes = file.bytes;
        final String? filePath = kIsWeb ? null : file.path;
        if (fileType == FileType.image && (fileBytes != null || (!kIsWeb && filePath != null))) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Send Photo'),
                content: const Text('Do you want to edit the photo before sending?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Edit Photo'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      _navigateToEditor(bytes: fileBytes, path: kIsWeb ? null : filePath, fileName: fileName);
                    },
                  ),
                  TextButton(
                    child: const Text('Send Directly'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      _setPickedFile(bytes: fileBytes, path: filePath, name: fileName);
                    },
                  ),
                ],
              );
            },
          );
        } else if (fileType == FileType.video && (fileBytes != null || (!kIsWeb && filePath != null))) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Send Video'),
                content: const Text('Do you want to edit the video before sending?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: kIsWeb
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            if (!mounted) return;
                            _navigateToVideoEditor(bytes: fileBytes, path: kIsWeb ? null : filePath, fileName: fileName);
                          },
                    child: Text('Edit Video', style: TextStyle(color: kIsWeb ? Colors.grey : null)),
                  ),
                  TextButton(
                    child: const Text('Send Directly'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      _setPickedFile(bytes: fileBytes, path: filePath, name: fileName);
                    },
                  ),
                ],
              );
            },
          );
        } else if (fileBytes != null) {
          _setPickedFile(bytes: fileBytes, path: null, name: fileName);
        } else if (!kIsWeb && filePath != null) {
          _setPickedFile(bytes: null, path: filePath, name: fileName);
        } else if (kIsWeb && filePath != null) {
          _log.warning('File picking error on Web: Only path is available, but bytes are required.'); // Use logger
          final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Failed to access selected file data.')));
        } else {
          _log.warning('File picking failed: No bytes or path available.'); // Use logger
          final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Failed to access selected file.')));
        }
      } else {
        _log.info('File picking cancelled.'); // Use logger
      }
    } catch (e) {
      _log.severe('Error picking file', e); // Use logger
      // Check mounted *after* the async gap and *before* using context.
      if (!mounted) return;
      // Capture ScaffoldMessenger *after* the await and mounted check.
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _navigateToEditor({Uint8List? bytes, String? path, required String fileName}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
    Uint8List? imageBytes = bytes;
    if (kIsWeb && imageBytes == null) {
      _log.warning('Error: Cannot edit image on web without image bytes.'); // Use logger
      // No await before this context use
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cannot edit photo: Image data not available.')));
      return;
    }
    if (!kIsWeb && imageBytes == null && path != null) {
      try {
        // No context use before await
        imageBytes = await File(path).readAsBytes();
      } catch (e) {
        _log.severe('Error reading image file from path', e); // Use logger
        if (!mounted) return; // Check after await
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error reading image file: $e')));
        return;
      }
    }
    // No await before this context use
    if (imageBytes == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cannot edit photo: No image data available.')));
      return;
    }
    // No await before this context use
    final Uint8List? editedImageBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes!)),
    );
    if (!mounted) return;
    if (editedImageBytes != null) {
      _log.info('Image editing complete. Got ${editedImageBytes.length} bytes.'); // Use logger
      final editedFileName = 'edited_$fileName';
      _setPickedFile(bytes: editedImageBytes, path: null, name: editedFileName);
    } else {
      _log.info('Image editing cancelled.'); // Use logger
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
    }
  }

  Future<void> _navigateToVideoEditor({Uint8List? bytes, String? path, required String fileName}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before async gap
    if (kIsWeb) {
      _log.warning('Video editing is not supported on the web.'); // Use logger
      // No await before this context use
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Video editing is not supported on the web.')));
      return;
    }

    String? videoPath = path;
    File? tempFile;
    // setState is safe here
    setState(() {
      _isSending = true;
    });
    if (videoPath == null && bytes != null) {
      try {
        // No context use before await
        final tempDir = await getTemporaryDirectory();
        final String tempFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
        tempFile = File('${tempDir.path}/$tempFileName');
        await tempFile.writeAsBytes(bytes);
        videoPath = tempFile.path;
        _log.info('Saved video bytes to temporary file: $videoPath'); // Use logger
      } catch (e) {
        _log.severe('Error saving video bytes to temporary file', e); // Use logger
        if (!mounted) return; // Check after await
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error preparing video for editing: $e')));
        // Ensure _isSending is reset on error before returning
        setState(() {
          _isSending = false;
        });
        return;
      }
    }
    // No await before this context use
    if (videoPath == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cannot edit video: No video file path available.')));
      setState(() {
        _isSending = false;
      }); // Reset sending state
      return;
    }

    final File videoFile = File(videoPath);
    // No await before this context use
    // The Navigator.push itself uses context, but the await is for its result.
    // The context passed to Navigator.push is captured before the await.
    final ExportConfig? exportConfig = await Navigator.push<ExportConfig?>(
      context,
      MaterialPageRoute(builder: (context) => VideoEditorScreen(file: videoFile)),
    );

    // Handle temp file deletion after navigation completes
    if (tempFile != null) {
      try {
        await tempFile.delete();
        _log.info('Deleted temporary video file: ${tempFile.path}'); // Use logger
      } catch (e) {
        _log.warning('Error deleting temporary video file', e); // Use logger
        // Decide if this error needs user notification
      }
    }

    if (!mounted) return; // Check after Navigator.push and tempFile.delete

    if (exportConfig != null) {
      _log.info('Video editing confirmed. Preparing FFmpeg execution...'); // Use logger
      _log.info('Command: ${exportConfig.command}'); // Use logger
      _log.info('Output Path: ${exportConfig.outputPath}'); // Use logger
      // setState is safe here
      setState(() {}); // Potentially update UI to show processing state more explicitly if needed
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Processing video... This may take a moment.')));
      await FFmpegKit.executeAsync(
        exportConfig.command,
        (FFmpegSession session) async {
          // This callback runs after FFmpeg finishes
          final state = await session.getState();
          final returnCode = await session.getReturnCode();
          final failStackTrace = await session.getFailStackTrace();

          if (!mounted) return; // Check inside the async callback

          setState(() {
            // Update state inside the callback
            _isSending = false;
          });

          if (ReturnCode.isSuccess(returnCode)) {
            _log.info('FFmpeg process completed successfully.'); // Use logger
            final editedVideoPath = exportConfig.outputPath;
            final editedFileName = editedVideoPath.split(Platform.pathSeparator).last;
            _setPickedFile(bytes: null, path: editedVideoPath, name: editedFileName); // Uses context via _setPickedFile -> ScaffoldMessenger
            // _setPickedFile already checks mounted
          } else {
            _log.severe('FFmpeg process failed with state $state and rc $returnCode.'); // Use logger
            if (failStackTrace != null) {
              _log.severe('FFmpeg failure stack trace: $failStackTrace'); // Use logger
            }
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error processing video. Code: $returnCode')));
            setState(() {
              // Update state inside the callback
              _selectedFilePath = null;
              _selectedFileName = null;
              _selectedFileBytes = null;
            });
          }
        },
        (Log log) {}, // Log callback
        (Statistics statistics) {}, // Statistics callback
      );
    } else {
      // This block runs if Navigator.push returned null (editing cancelled)
      _log.info('Video editing cancelled.'); // Use logger
      setState(() {
        // Update state after Navigator.push returned
        _selectedFilePath = null;
        _selectedFileName = null;
        _selectedFileBytes = null;
        _isSending = false;
      });
    }
  }

  void _setPickedFile({Uint8List? bytes, String? path, required String name}) {
    if (!mounted) return;
    setState(() {
      _selectedFileBytes = bytes;
      _selectedFilePath = path;
      _selectedFileName = name;
    });
    _log.info('Selected file: $name ${bytes != null ? "(from bytes)" : "(from path)"}'); // Use logger
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Store before potential async gap in caller
    if (!mounted) return; // Check before using context
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Selected: $name. Tap a device to send.')));
  }

  Future<void> _scanQrCode() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('QR Code scanning via camera is not supported on web.')));
      return;
    }
    try {
      if (!mounted) return;
      final currentContext = context;
      final String? scanResult = await Navigator.push<String>(currentContext, MaterialPageRoute(builder: (context) => const QrScannerPage()));
      if (!mounted) return; // Check after await
      if (scanResult == null) {
        _log.info('QR Code scan cancelled or failed.'); // Use logger
        return;
      }
      setState(() {
        _scanResult = scanResult;
      });
      _log.info('QR Code Scanned: $_scanResult'); // Use logger
      try {
        final Map<String, dynamic> data = jsonDecode(_scanResult!);
        final String? ip = data['ip'] as String?;
        final int? port = data['port'] as int?; // Keep port if available in QR
        final String? alias = data['alias'] as String?;
        if (ip != null && alias != null) {
          // Port might be optional or fixed
          final scannedDevice = DeviceInfo(ip: ip, port: port ?? 2706, alias: alias); // Use default port if missing
          final deviceData = {'ip': ip, 'name': alias}; // Data for provider
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Device Found: ${scannedDevice.alias}'),
              content: Text('IP: ${scannedDevice.ip}:${scannedDevice.port}\n\nSend current selection or add to favorites?'),
              actions: [
                TextButton(
                  child: const Text('Add Favorite'),
                  onPressed: () async {
                    // Store context before async operations
                    final dialogContext = context;
                    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                    Navigator.of(dialogContext).pop();
                    // Use provider to add favorite
                    await ref.read(settingsProvider.notifier).addFavoriteDevice(deviceData);
                    if (!mounted) return; // Check after await
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Added ${scannedDevice.alias} to favorites.')));
                  },
                ),
                TextButton(
                  child: const Text('Send'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _initiateSend(scannedDevice);
                  },
                ),
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          );
        } else {
          throw const FormatException('Invalid QR code data format (missing ip, port, or alias).');
        }
      } catch (e) {
        _log.severe('Error processing scanned QR code', e); // Use logger
        if (!mounted) return; // Check before context use
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Invalid QR data. Scanned: "$_scanResult"')));
      }
    } catch (e) {
      _log.severe('Error during QR scan or processing', e); // Use logger
      if (!mounted) return; // Check before context use
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error scanning QR code: $e')));
    }
  }
}
