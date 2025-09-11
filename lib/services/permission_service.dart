import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  Future<bool> requestAllPermissions() async {
    final permissions = <Permission>[];

    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.nearbyWifiDevices,
        Permission.location,
        Permission.notification,
      ]);
    } else if (Platform.isIOS) {
      permissions.addAll([
        Permission.photos,
        Permission.storage,
        Permission.notification,
      ]);
    }

    final statuses = await permissions.request();
    return statuses.values.every((status) => 
        status == PermissionStatus.granted || 
        status == PermissionStatus.limited);
  }

  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      return await Permission.storage.isGranted ||
             await Permission.manageExternalStorage.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.photos.isGranted;
    }
    return true; // Desktop platforms
  }

  Future<bool> hasLocationPermission() async {
    if (Platform.isAndroid) {
      return await Permission.location.isGranted;
    }
    return true;
  }

  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
