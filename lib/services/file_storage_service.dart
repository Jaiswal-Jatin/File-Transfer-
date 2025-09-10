import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class FileStorageService {
  static Future<String> getDefaultDownloadPath() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Request storage permission
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final directory = await getExternalStorageDirectory();
        return '${directory?.path}/Download' ?? '/storage/emulated/0/Download';
      } else {
        // Fallback to app directory
        final directory = await getApplicationDocumentsDirectory();
        return directory.path;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final directory = await getDownloadsDirectory();
      return directory?.path ?? (await getApplicationDocumentsDirectory()).path;
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      final directory = await getDownloadsDirectory();
      return directory?.path ?? (await getApplicationDocumentsDirectory()).path;
    }
    
    // Fallback
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<bool> requestStoragePermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // Other platforms don't need explicit permission
  }

  static Future<String> generateUniqueFilePath(String directory, String fileName) async {
    String baseName = fileName;
    String extension = '';
    
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      baseName = fileName.substring(0, lastDotIndex);
      extension = fileName.substring(lastDotIndex);
    }
    
    String filePath = '$directory/$fileName';
    int counter = 1;
    
    while (await File(filePath).exists()) {
      filePath = '$directory/${baseName}_$counter$extension';
      counter++;
    }
    
    return filePath;
  }

  static Future<bool> createDirectoryIfNotExists(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error creating directory: $e');
      return false;
    }
  }

  static Future<int> getDirectorySize(String path) async {
    try {
      final directory = Directory(path);
      int totalSize = 0;
      
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
      return 0;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String getFileExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < fileName.length - 1) {
      return fileName.substring(lastDotIndex + 1).toLowerCase();
    }
    return '';
  }

  static String getMimeType(String fileName) {
    final extension = getFileExtension(fileName);
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/avi';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }
}
