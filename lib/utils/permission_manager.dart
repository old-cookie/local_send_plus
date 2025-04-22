import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static Future<bool> requestPhotosPermission() async {
    PermissionStatus status;
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
        if (status.isGranted) {
          status = await Permission.videos.request();
        }
      } else {
        status = await Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      return true;
    }
    return status.isGranted;
  }

  static Future<bool> requestStoragePermission() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        return true;
      }
    } else {
      return true;
    }
  }

  static Future<bool> openPermissionSettings() async {
    return await openAppSettings();
  }
}
