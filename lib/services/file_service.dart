import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'network_service.dart';
import '../models/file_transfer.dart';

class FileService {
  static const int _chunkSize = 64 * 1024; // 64KB chunks

  Future<List<File>> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        return result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error picking files: $e');
      return [];
    }
  }

  Future<Directory> getAppSaveDirectory() async {
    Directory? baseDirectory;
    if (Platform.isAndroid) {
      // On Android, we want the public "Downloads" directory. This requires
      // storage permissions to be granted by the user at runtime.
      baseDirectory = await getDownloadsDirectory();

      // On some Android versions or without permissions, getDownloadsDirectory()
      // might return a private, app-specific path (e.g., /storage/emulated/0/Android/data/...).
      // We check for this and attempt a workaround to find the true public directory.
      if (baseDirectory == null || baseDirectory.path.contains('/Android/data')) {
        print("getDownloadsDirectory() returned a private path or null. Trying to find public path manually.");
        try {
          // This workaround finds the root of the external storage.
          final Directory? externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final String rootPath = externalDir.path.split('/Android/data').first;
            final publicDownloadsPath = '$rootPath/Download';
            final publicDownloadsDir = Directory(publicDownloadsPath);
            
            // Check if we have access and the directory exists. Create it if it doesn't.
            if (await publicDownloadsDir.exists() || (await publicDownloadsDir.create(recursive: true)).existsSync()) {
               baseDirectory = publicDownloadsDir;
               print("Successfully found and using public downloads path: ${baseDirectory.path}");
            } else {
               print("Failed to create or access public downloads directory. Using original path.");
            }
          }
        } catch (e) {
          print("Error finding public downloads directory manually: $e. Using path_provider's result.");
        }
      }
    } else if (Platform.isIOS) {
      baseDirectory = await getApplicationDocumentsDirectory();
    } else {
      // For desktop platforms (Windows, Linux, macOS).
      baseDirectory = await getDownloadsDirectory();
    }

    // Final fallback to the application's documents directory if no other directory is found.
    baseDirectory ??= await getApplicationDocumentsDirectory();
    final p2pShareDirectory = Directory('${baseDirectory.path}/P2P File Transfer');
    if (!await p2pShareDirectory.exists()) {
      await p2pShareDirectory.create(recursive: true);
    }
    return p2pShareDirectory;
  }

  Future<String> getFileType(String filePath) async {
    final mimeType = lookupMimeType(filePath);
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) return 'Image';
      if (mimeType.startsWith('video/')) return 'Video';
      if (mimeType.startsWith('audio/')) return 'Audio';
      if (mimeType.startsWith('text/')) return 'Document';
      if (mimeType == 'application/pdf') return 'PDF';
      if (mimeType.contains('zip') || mimeType.contains('rar')) return 'Archive';
    }
    return 'File';
  }

  Stream<FileTransferProgress> sendFile(
    File file,
    Socket socket,
    String transferId,
  ) async* {
    try {
      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      
      // Send file metadata
      final metadata = {
        'transferId': transferId,
        'fileName': fileName,
        'fileSize': fileSize,
        'type': NetworkService.msgTypeFileData, // Use consistent message type
      };
      
      socket.write(jsonEncode(metadata) + '\n'); // Use JSON and a newline delimiter
      
      int totalSent = 0;
      final startTime = DateTime.now();
      
      await for (final chunk in file.openRead()) {
        socket.add(chunk);
        totalSent += chunk.length;
        
        final elapsed = DateTime.now().difference(startTime);
        final speed = elapsed.inMilliseconds > 0 
            ? totalSent / elapsed.inMilliseconds * 1000 
            : 0.0;
        
        yield FileTransferProgress(
          transferId: transferId,
          bytesTransferred: totalSent,
          totalBytes: fileSize,
          speed: speed,
        );
      }
      
      yield FileTransferProgress(
        transferId: transferId,
        bytesTransferred: totalSent,
        totalBytes: fileSize,
        speed: 0,
        isCompleted: true,
      );
      
    } catch (e) {
      yield FileTransferProgress(
        transferId: transferId,
        bytesTransferred: 0,
        totalBytes: 0,
        speed: 0,
        error: e.toString(),
      );
    }
  }

  Stream<FileTransferProgress> receiveFile(
    Socket socket,
    String fileName,
    int fileSize,
    String transferId,
  ) async* {
    IOSink? sink;
    File? file;
    try {
      final downloadsDir = await getAppSaveDirectory();
      file = await getUniqueFile(downloadsDir, fileName);
      sink = file.openWrite();
      
      int totalReceived = 0;
      final startTime = DateTime.now();
      
      await for (final data in socket) {
        // Determine how much of the chunk to write to the file
        final bytesToWrite = (totalReceived + data.length > fileSize)
            ? fileSize - totalReceived
            : data.length;

        if (bytesToWrite > 0) {
          sink.add(data.sublist(0, bytesToWrite));
          totalReceived += bytesToWrite;
        }
        // Note: If data.length > bytesToWrite, the rest of the data in this
        // chunk is discarded. This can be an issue if the socket is reused for
        // other messages immediately after the file data.
        
        final elapsed = DateTime.now().difference(startTime);
        final speed = elapsed.inMilliseconds > 0 
            ? totalReceived / elapsed.inMilliseconds * 1000 
            : 0.0;
        
        yield FileTransferProgress(
          transferId: transferId,
          bytesTransferred: totalReceived,
          totalBytes: fileSize,
          speed: speed,
        );
        
        if (totalReceived >= fileSize) break;
      }
      
      await sink.close();
      
      yield FileTransferProgress(
        transferId: transferId,
        bytesTransferred: totalReceived,
        totalBytes: fileSize,
        speed: 0,
        isCompleted: true,
        filePath: file.path,
      );
      
    } catch (e) {
      // Ensure the sink is closed and delete the partial file on error.
      await sink?.close();
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (deleteError) {
          print('Error deleting partial file: $deleteError');
        }
      }
      yield FileTransferProgress(
        transferId: transferId,
        bytesTransferred: 0,
        totalBytes: 0,
        speed: 0,
        error: e.toString(),
      );
    } 
  }

  Future<File> getUniqueFile(Directory dir, String fileName) async {
    var file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      return file;
    }

    final name = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    final extension = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '';
    var counter = 1;
    
    while (await file.exists()) {
      file = File('${dir.path}/$name ($counter)$extension');
      counter++;
    }
    return file;
  }
}

class FileTransferProgress {
  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final double speed;
  final bool isCompleted;
  final String? error;
  final String? filePath;

  FileTransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    this.isCompleted = false,
    this.error,
    this.filePath,
  });

  double get progress => totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}
