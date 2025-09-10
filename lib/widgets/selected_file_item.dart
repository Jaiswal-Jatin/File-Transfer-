import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_storage_service.dart';

class SelectedFileItem extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const SelectedFileItem({
    super.key,
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // File Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getFileColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(),
                color: _getFileColor(),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // File Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        FileStorageService.formatFileSize(file.size),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getFileColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          file.extension?.toUpperCase() ?? 'FILE',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getFileColor(),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Remove Button
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              iconSize: 20,
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                minimumSize: const Size(32, 32),
              ),
              tooltip: 'Remove file',
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = file.extension?.toLowerCase() ?? '';
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
      case 'rtf':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'apk':
        return Icons.android;
      case 'exe':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor() {
    final extension = file.extension?.toLowerCase() ?? '';
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.blue;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return Colors.red;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return Colors.orange;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
      case 'rtf':
        return Colors.green;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'apk':
        return Colors.green;
      case 'exe':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
