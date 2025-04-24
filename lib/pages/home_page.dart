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
// Remove shared_preferences import, use provider from main.dart
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
// Import main.dart provider instead of settings_provider's local one
import 'package:local_send_plus/main.dart' show sharedPreferencesProvider;
import 'package:local_send_plus/providers/settings_provider.dart';
import 'package:local_send_plus/features/server/server_provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:local_send_plus/pages/qr_scanner_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isSending = false;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  List<DeviceInfo> _favorites = [];
  static const String _favoritesPrefKey = 'favorite_devices';
  StreamSubscription? _receivedFileSubscription;
  StreamSubscription? _receivedTextSubscription;
  DiscoveryService? _discoveryService;
  ServerService? _serverService;
  String? _localIpAddress;
  String? _scanResult;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
          final BuildContext currentContext = context;
          if (!(ModalRoute.of(currentContext)?.isCurrent ?? false)) return;
          Future.microtask(() {
            if (!mounted || !(ModalRoute.of(currentContext)?.isCurrent ?? false)) return;
            showDialog(
              context: currentContext,
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
          final BuildContext currentContext = context;
          if (!(ModalRoute.of(currentContext)?.isCurrent ?? false)) return;
          Future.microtask(() {
            if (!mounted || !(ModalRoute.of(currentContext)?.isCurrent ?? false)) return;
            showDialog(
              context: currentContext,
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
      print("Failed to get local IP: $e");
      if (mounted) {
      }
    }
  }

  Future<void> _loadFavorites() async {
    // Use the provider from main.dart
    final prefs = ref.read(sharedPreferencesProvider);
    // Await getStringList
    final List<String>? favoritesJson = await prefs.getStringList(_favoritesPrefKey);
    if (favoritesJson != null) {
      if (!mounted) return;
      setState(() {
        _favorites = favoritesJson.map((json) => DeviceInfo.fromJson(jsonDecode(json))).toList();
      });
    }
  }

  Future<void> _saveFavorites() async {
    // Use the provider from main.dart
    final prefs = ref.read(sharedPreferencesProvider);
    final List<String> favoritesJson = _favorites.map((device) => jsonEncode(device.toJson())).toList();
    // Await setStringList
    await prefs.setStringList(_favoritesPrefKey, favoritesJson);
  }

  Future<bool> _addFavorite() async {
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
    const int port = 2706;
    final newFavorite = DeviceInfo(ip: ip, port: port, alias: name);
    if (_favorites.any((fav) => fav.ip == newFavorite.ip && fav.port == newFavorite.port)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Device ${newFavorite.ip}:${newFavorite.port} already in favorites.')));
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _favorites.add(newFavorite);
      _ipController.clear();
      _nameController.clear();
      FocusScope.of(context).unfocus();
    });
    await _saveFavorites();
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${newFavorite.alias} to favorites.')));
    return true;
  }

  Future<void> _initiateSend(DeviceInfo targetDevice) async {
    if (!mounted) return;
    setState(() {
      _isSending = true;
    });
    String? errorMessage;
    try {
      if (_selectedFileName != null && (_selectedFilePath != null || _selectedFileBytes != null)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sending file $_selectedFileName to ${targetDevice.alias}...')));
        if (!mounted) return;
        await ref.read(sendServiceProvider).sendFile(targetDevice, _selectedFileName!, filePath: _selectedFilePath, fileBytes: _selectedFileBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent $_selectedFileName successfully!')));
        if (!mounted) return;
        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
          _selectedFileBytes = null;
        });
      } else {
        final textToSend = _textController.text.trim();
        if (textToSend.isNotEmpty) {
          if (!mounted) return;
          final scaffoldMessenger = ScaffoldMessenger.of(context);
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
            if (!mounted) return;
            await ref.read(sendServiceProvider).sendText(targetDevice, textToSend);
            if (!mounted) return;
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Text sent successfully!'), backgroundColor: Colors.green));
            _textController.clear();
          } catch (e) {
            errorMessage = e.toString();
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter text or select a file to send.')));
          setState(() {
            _isSending = false;
          });
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'Error sending: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: () => _initiateSend(targetDevice)),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildSelectedFileThumbnail() {
    if (_selectedFileName == null) {
      return const SizedBox.shrink();
    }
    final fileNameLower = _selectedFileName!.toLowerCase();
    final isImage =
        fileNameLower.endsWith('.jpg') ||
        fileNameLower.endsWith('.jpeg') ||
        fileNameLower.endsWith('.png') ||
        fileNameLower.endsWith('.gif') ||
        fileNameLower.endsWith('.bmp') ||
        fileNameLower.endsWith('.webp');
    final isVideo =
        fileNameLower.endsWith('.mp4') ||
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
              print('Error generating video thumbnail: ${snapshot.error}');
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
      thumbnailWidget = const Icon(Icons.insert_drive_file_outlined, size: 50);
    }
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
            child: ClipRRect(borderRadius: BorderRadius.circular(4.0), child: thumbnailWidget),
            alignment: Alignment.center,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            onSelected: (String result) {
              switch (result) {
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
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!kIsWeb)
                    const PopupMenuItem<String>(value: 'scan_qr', child: ListTile(leading: Icon(Icons.qr_code_scanner), title: Text('Scan QR'))),
                  if (!kIsWeb)
                    const PopupMenuItem<String>(value: 'ai_chat', child: ListTile(leading: Icon(Icons.chat_bubble_outline), title: Text('AI Chat'))),
                  const PopupMenuItem<String>(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('Settings'))),
                ],
          ),
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
                Row(
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Align(alignment: Alignment.centerLeft, child: Text('Discovered Devices (${discoveredDevices.length}):')),
          ),
          Expanded(
            child:
                discoveredDevices.isEmpty
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
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
        ],
      ),
    );
  }

  Future<void> _showFavoritesDialog() async {
    await _loadFavorites();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          final success = await _addFavorite();
                          if (success && mounted) {
                            setDialogState(() {});
                          }
                        },
                      ),
                      const Divider(height: 24),
                      _favorites.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text('No favorites added yet.')))
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _favorites.length,
                            itemBuilder: (context, index) {
                              if (index < 0 || index >= _favorites.length) {
                                return const SizedBox.shrink();
                              }
                              final device = _favorites[index];
                              return ListTile(
                                leading: const Icon(Icons.star),
                                title: Text(device.alias),
                                subtitle: Text('${device.ip}:${device.port}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Remove Favorite',
                                  onPressed: () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    final removedDeviceAlias = device.alias;
                                    if (!mounted) return;
                                    setDialogState(() {
                                      if (index >= 0 && index < _favorites.length) {
                                        _favorites.removeAt(index);
                                      }
                                    });
                                    if (!mounted) return;
                                    await _saveFavorites();
                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Removed $removedDeviceAlias from favorites.')));
                                  },
                                ),
                                onTap:
                                    _isSending
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
          },
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

    if (!mounted) return;
    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${permissionTypeDenied ?? 'Required'} permission denied')));
      return;
    }
    try {
      if (!mounted) return;
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
        print('FilePicker result on ${kIsWeb ? "Web" : "Native"}:');
        print('  Name: ${file.name}');
        print('  Path: ${kIsWeb ? "N/A (Web)" : file.path}');
        print('  Bytes length: ${file.bytes?.length}');
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
                    onPressed:
                        kIsWeb
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
          print('File picking error on Web: Only path is available, but bytes are required.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to access selected file data.')));
        } else {
          print('File picking failed: No bytes or path available.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to access selected file.')));
        }
      } else {
        print('File picking cancelled.');
      }
    } catch (e) {
      print('Error picking file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _navigateToEditor({Uint8List? bytes, String? path, required String fileName}) async {
    Uint8List? imageBytes = bytes;
    if (kIsWeb && imageBytes == null) {
      print('Error: Cannot edit image on web without image bytes.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit photo: Image data not available.')));
      return;
    }
    if (!kIsWeb && imageBytes == null && path != null) {
      try {
        if (!mounted) return;
        imageBytes = await File(path).readAsBytes();
      } catch (e) {
        print('Error reading image file from path: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reading image file: $e')));
        return;
      }
    }
    if (!mounted) return;
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit photo: No image data available.')));
      return;
    }
    if (!mounted) return;
    final Uint8List? editedImageBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes!)),
    );
    if (!mounted) return;
    if (editedImageBytes != null) {
      print('Image editing complete. Got ${editedImageBytes.length} bytes.');
      final editedFileName = 'edited_$fileName';
      _setPickedFile(bytes: editedImageBytes, path: null, name: editedFileName);
    } else {
      print('Image editing cancelled.');
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
    }
  }

  Future<void> _navigateToVideoEditor({Uint8List? bytes, String? path, required String fileName}) async {
    if (kIsWeb) {
      print('Video editing is not supported on the web.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video editing is not supported on the web.')));
      return;
    }

    String? videoPath = path;
    File? tempFile;
    setState(() {
      _isSending = true;
    });
    if (videoPath == null && bytes != null) {
      try {
        if (!mounted) return;
        final tempDir = await getTemporaryDirectory();
        final String tempFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
        tempFile = File('${tempDir.path}/$tempFileName');
        await tempFile.writeAsBytes(bytes);
        videoPath = tempFile.path;
        print('Saved video bytes to temporary file: $videoPath');
      } catch (e) {
        print('Error saving video bytes to temporary file: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error preparing video for editing: $e')));
        return;
      }
    }
    if (!mounted) return;
    if (videoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit video: No video file path available.')));
      return;
    }
    if (!mounted) return;
    final File videoFile = File(videoPath);
    if (!mounted) {
      setState(() {
        _isSending = false;
      });
      return;
    }
    final ExportConfig? exportConfig = await Navigator.push<ExportConfig?>(
      context,
      MaterialPageRoute(builder: (context) => VideoEditorScreen(file: videoFile)),
    );
    if (tempFile != null) {
      try {
        await tempFile.delete();
        print('Deleted temporary video file: ${tempFile.path}');
      } catch (e) {
        print('Error deleting temporary video file: $e');
      }
    }
    if (!mounted) {
      setState(() {
        _isSending = false;
      });
      return;
    }
    if (exportConfig != null) {
      print('Video editing confirmed. Preparing FFmpeg execution...');
      print('Command: ${exportConfig.command}');
      print('Output Path: ${exportConfig.outputPath}');
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing video... This may take a moment.')));
      await FFmpegKit.executeAsync(
        exportConfig.command,
        (FFmpegSession session) async {
          final state = await session.getState();
          final returnCode = await session.getReturnCode();
          final failStackTrace = await session.getFailStackTrace();
          if (!mounted) return;
          setState(() {
            _isSending = false;
          });
          if (ReturnCode.isSuccess(returnCode)) {
            print('FFmpeg process completed successfully.');
            final editedVideoPath = exportConfig.outputPath;
            final editedFileName = editedVideoPath.split(Platform.pathSeparator).last;
            _setPickedFile(bytes: null, path: editedVideoPath, name: editedFileName);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video processed successfully! Ready to send.')));
          } else {
            print('FFmpeg process failed with state $state and rc $returnCode.');
            if (failStackTrace != null) {
              print('FFmpeg failure stack trace: $failStackTrace');
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing video. Code: $returnCode')));
            setState(() {
              _selectedFilePath = null;
              _selectedFileName = null;
              _selectedFileBytes = null;
            });
          }
        },
        (Log log) {},
        (Statistics statistics) {},
      );
    } else {
      print('Video editing cancelled.');
      setState(() {
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
    print('Selected file: $name ${bytes != null ? "(from bytes)" : "(from path)"}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected: $name. Tap a device to send.')));
  }

  Future<void> _scanQrCode() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code scanning via camera is not supported on web.')));
      return;
    }
    try {
      final String? scanResult = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const QrScannerPage()));
      if (!mounted) return;
      if (scanResult == null) {
        print('QR Code scan cancelled or failed.');
        return;
      }
      setState(() {
        _scanResult = scanResult;
      });
      print('QR Code Scanned: $_scanResult');
      try {
        final Map<String, dynamic> data = jsonDecode(_scanResult!);
        final String? ip = data['ip'] as String?;
        final int? port = data['port'] as int?;
        final String? alias = data['alias'] as String?;
        if (ip != null && port != null && alias != null) {
          final scannedDevice = DeviceInfo(ip: ip, port: port, alias: alias);
          if (!mounted) return;
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Device Found: ${scannedDevice.alias}'),
                  content: Text('IP: ${scannedDevice.ip}:${scannedDevice.port}\n\nSend current selection or add to favorites?'),
                  actions: [
                    TextButton(
                      child: const Text('Add Favorite'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _ipController.text = scannedDevice.ip;
                        _nameController.text = scannedDevice.alias;
                        _addFavorite().then((success) {
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${scannedDevice.alias} to favorites.')));
                          }
                        });
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
        print('Error processing scanned QR code: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid QR data. Scanned: "$_scanResult"')));
      }
    } catch (e) {
      print('Error during QR scan or processing: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning QR code: $e')));
    }
  }
}
