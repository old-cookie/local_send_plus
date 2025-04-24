import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:local_send_plus/models/device_info.dart';

/// Core service class that provides file and text transmission functionality.
/// Handles HTTP communication with target devices for file uploads and text message delivery.
class SendService {
  SendService();

  /// Sends a file to the target device.
  /// 
  /// Parameters:
  /// - [targetDevice]: Target device information containing IP and port
  /// - [fileName]: Name of the file to be sent
  /// - [filePath]: Optional, local path to the file
  /// - [fileBytes]: Optional, binary content of the file
  /// 
  /// Notes:
  /// - Either [filePath] or [fileBytes] must be provided
  /// - If both are provided, [fileBytes] takes precedence
  /// 
  /// Throws:
  /// - [ArgumentError]: When neither filePath nor fileBytes is provided
  /// - [Exception]: When file transmission fails
  Future<void> sendFile(DeviceInfo targetDevice, String fileName, {String? filePath, Uint8List? fileBytes}) async {
    if (filePath == null && fileBytes == null) {
      throw ArgumentError('sendFile requires either a filePath or fileBytes.');
    }
    if (filePath != null && fileBytes != null) {
      print('Warning: Both filePath and fileBytes provided to sendFile. Using fileBytes.');
      filePath = null;
    }
    final url = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/receive');
    final client = http.Client(); // Use the standard http client
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['fileName'] = fileName;
      http.MultipartFile multipartFile;
      int bytesLength;
      if (fileBytes != null) {
        bytesLength = fileBytes.length;
        multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: fileName);
        print('Preparing to send $fileName ($bytesLength bytes) from memory...');
      } else {
        final file = File(filePath!);
        bytesLength = await file.length();
        multipartFile = await http.MultipartFile.fromPath('file', filePath, filename: fileName);
        print('Preparing to send $fileName ($bytesLength bytes) from path $filePath...');
      }
      request.files.add(multipartFile);
      request.fields['fileSize'] = bytesLength.toString();
      print('Sending $fileName ($bytesLength bytes) to ${targetDevice.alias} at $url...');
      final response = await client.send(request);
      if (response.statusCode == 200) {
        print('File sent successfully to ${targetDevice.alias}.');
      } else {
        print('File send failed to ${targetDevice.alias}. Status code: ${response.statusCode}');
        final responseBody = await response.stream.bytesToString();
        print('Server error response: $responseBody');
        throw Exception('Failed to send file: Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending file to ${targetDevice.alias}: $e');
      throw Exception('Error sending file: $e');
    } finally {
      client.close();
      print("HTTP Client closed for sendFile request to ${targetDevice.alias}.");
    }
  }

  /// Sends a text message to the target device.
  /// 
  /// Parameters:
  /// - [targetDevice]: Target device information containing IP and port
  /// - [text]: Text content to be sent
  /// 
  /// Features:
  /// - Includes automatic retry mechanism with up to 2 retries
  /// - Uses exponential backoff algorithm for retry intervals
  /// - Request timeout of 10 seconds per attempt
  /// 
  /// Throws:
  /// - [Exception]: When text transmission fails after all retry attempts
  Future<void> sendText(DeviceInfo targetDevice, String text) async {
    // Use a specific endpoint for text messages for clarity on the server-side
    final url = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/receive-text');
    final client = http.Client();
    const timeoutDuration = Duration(seconds: 10);
    int retryCount = 0;
    const maxRetries = 2;
    try {
      print('Sending text "${text.length > 50 ? text.substring(0, 50) + '...' : text}" to ${targetDevice.alias} at $url...');
      while (retryCount <= maxRetries) {
        try {
          final response = await client
              .post(url, headers: {'Content-Type': 'text/plain; charset=utf-8'}, body: text, encoding: utf8)
              .timeout(timeoutDuration);
          if (response.statusCode == 200) {
            print('Text sent successfully to ${targetDevice.alias}.');
            return; // Success - exit the method
          } else {
            final error = 'Server responded with status ${response.statusCode}: ${response.body}';
            if (retryCount == maxRetries) {
              throw Exception(error);
            }
            print('Attempt ${retryCount + 1} failed: $error');
          }
        } on TimeoutException {
          final error = 'Request timed out after ${timeoutDuration.inSeconds} seconds';
          if (retryCount == maxRetries) {
            throw Exception(error);
          }
          print('Attempt ${retryCount + 1} failed: $error');
        } on SocketException catch (e) {
          final error = 'Network error: ${e.message}';
          if (retryCount == maxRetries) {
            throw Exception(error);
          }
          print('Attempt ${retryCount + 1} failed: $error');
        }
        retryCount++;
        if (retryCount <= maxRetries) {
          // Wait before retrying, with exponential backoff
          final waitDuration = Duration(milliseconds: 500 * (1 << retryCount));
          print('Retrying in ${waitDuration.inMilliseconds}ms...');
          await Future.delayed(waitDuration);
        }
      }
      throw Exception('Failed to send text after $maxRetries retries');
    } catch (e) {
      print('Error sending text to ${targetDevice.alias}: $e');
      rethrow;
    } finally {
      client.close();
      print("HTTP Client closed for sendText request to ${targetDevice.alias}.");
    }
  }
}

/// Provider that offers global access to SendService instance
final sendServiceProvider = Provider<SendService>((ref) {
  return SendService();
});
