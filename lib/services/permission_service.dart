import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  Future<bool> requestAllPermissions() async {
    // On desktop platforms like macOS, Windows, and Linux, many of these
    // permissions are not managed at runtime via this plugin. Network permissions
    // for macOS are handled via entitlements, not here.
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return true;
    }

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

  // Renamed to avoid recursive call with the package's top-level function
  Future<void> requestOpenAppSettings() async {
    // Now this correctly calls the `openAppSettings` function from the permission_handler package
    await openAppSettings(); 
  }
}
