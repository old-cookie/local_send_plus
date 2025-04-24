import 'dart:convert';
import 'dart:io' show Platform;
import 'package:logging/logging.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// A service class that handles NFC (Near Field Communication) operations.
/// This class provides functionality for reading and writing device information using NFC tags.
class NfcService {
  final _logger = Logger('NfcService');

  /// Checks if NFC is available on the current device.
  ///
  /// Returns:
  ///   - true if NFC is available and can be used
  ///   - false if NFC is not supported or disabled
  Future<bool> isNfcAvailable() async {
    if (kIsWeb) {
      return false; // NFC not available on web
    }
    // Check availability
    bool isAvailable = await NfcManager.instance.isAvailable();
    return isAvailable;
  }

  /// Retrieves device information including IP address and device name.
  ///
  /// Returns:
  ///   - Map containing 'ip' and 'name' if successful
  ///   - null if the information cannot be retrieved
  Future<Map<String, String>?> _getDeviceInfo() async {
    final networkInfo = NetworkInfo();
    final deviceInfoPlugin = DeviceInfoPlugin();
    String? ipAddress;
    String? deviceName;

    try {
      ipAddress = await networkInfo.getWifiIP(); // Requires ACCESS_WIFI_STATE

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
          deviceName = androidInfo.model; // Or use .device, .product, etc.
        } else if (Platform.isIOS) {
          // iOS implementation if needed later
          // IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
          // deviceName = iosInfo.name;
          deviceName = 'iOS Device'; // Placeholder
        } else {
          // Handle other platforms if necessary
          deviceName = 'Unknown Device';
        }
      } else {
        deviceName = 'Web Browser';
      }

      if (ipAddress != null) {
        return {'ip': ipAddress, 'name': deviceName};
      }
    } catch (e) {
      _logger.warning('Error getting device info', e);
    }
    return null;
  }

  /// Writes device information to an NFC tag.
  ///
  /// Parameters:
  ///   - context: BuildContext for showing status messages
  ///
  /// Shows progress and status via SnackBar messages.
  Future<void> writeNdef(BuildContext context) async {
    if (!await isNfcAvailable()) {
      _showSnackBar(context, 'NFC is not available on this device.');
      return;
    }

    final deviceInfo = await _getDeviceInfo();
    if (deviceInfo == null) {
      _showSnackBar(context, 'Could not retrieve device IP or name.');
      return;
    }

    final deviceInfoJson = jsonEncode(deviceInfo);
    _showSnackBar(context, 'Ready to write. Hold tag near device.');

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      Ndef? ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF writable.');
        _showSnackBar(context, 'Tag is not NDEF writable.');
        return;
      }

      NdefMessage message = NdefMessage([
        NdefRecord.createText(deviceInfoJson),
        // Consider adding a custom record type for better identification
        // NdefRecord.createMime('application/vnd.yourcompany.devicedata', Uint8List.fromList(deviceInfoJson.codeUnits)),
      ]);

      try {
        await ndef.write(message);
        NfcManager.instance.stopSession();
        _showSnackBar(context, 'Device info written successfully!');
      } catch (e) {
        NfcManager.instance.stopSession(errorMessage: 'Write failed: $e');
        _showSnackBar(context, 'Error writing to tag: $e');
      }
    }, onError: (error) async {
      _showSnackBar(context, 'NFC Error: ${error.message}');
    });
  }

  /// Reads device information from an NFC tag.
  ///
  /// Parameters:
  ///   - context: BuildContext for showing status messages
  ///   - onDataReceived: Callback function to handle the received data
  Future<void> readNdef(BuildContext context, Function(Map<String, String> data) onDataReceived) async {
    if (!await isNfcAvailable()) {
      _showSnackBar(context, 'NFC is not available on this device.');
      return;
    }

    _showSnackBar(context, 'Ready to scan. Hold tag near device.');

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      Ndef? ndef = Ndef.from(tag);
      if (ndef == null) {
        NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF compatible.');
        _showSnackBar(context, 'Tag is not NDEF compatible.');
        return;
      }

      NdefMessage? message = ndef.cachedMessage; // Read cached message if available

      if (message == null || message.records.isEmpty) {
        try {
          // If no cached message, try reading explicitly
          message = await ndef.read();
        } catch (e) {
          NfcManager.instance.stopSession(errorMessage: 'Read failed: $e');
          _showSnackBar(context, 'Error reading tag: $e');
          return;
        }
      }

      if (message.records.isNotEmpty) {
        final record = message.records.first;
        // Assuming the first record is the text record we wrote
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown && record.type.length == 1 && record.type[0] == 0x54 /* T */) {
          try {
            // Decode the payload (skip language code byte)
            final payloadString = utf8.decode(record.payload.sublist(record.payload[0] + 1));
            final Map<String, dynamic> decodedData = jsonDecode(payloadString);
            // Ensure keys are strings and values are strings
            final Map<String, String> stringData = decodedData.map((key, value) => MapEntry(key, value.toString()));
            onDataReceived(stringData);
            NfcManager.instance.stopSession();
            _showSnackBar(context, 'Device info received!');
          } catch (e) {
            NfcManager.instance.stopSession(errorMessage: 'Data parsing error: $e');
            _showSnackBar(context, 'Error parsing data from tag: $e');
          }
        } else {
          NfcManager.instance.stopSession(errorMessage: 'Unsupported record type.');
          _showSnackBar(context, 'Tag contains unsupported data format.');
        }
      } else {
        NfcManager.instance.stopSession(errorMessage: 'No NDEF message found.');
        _showSnackBar(context, 'No NDEF data found on tag.');
      }
    }, onError: (error) async {
      _showSnackBar(context, 'NFC Error: ${error.message}');
    });
  }

  /// Shows a SnackBar message to the user.
  ///
  /// Parameters:
  ///   - context: BuildContext for showing the SnackBar
  ///   - message: The message to display
  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
