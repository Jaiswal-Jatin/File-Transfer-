import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/device.dart';
import '../services/transfer_service.dart';
import '../services/file_storage_service.dart';
import '../widgets/file_category_card.dart';
import '../widgets/selected_file_item.dart';

class SendFileScreen extends StatefulWidget {
  final Device targetDevice;

  const SendFileScreen({
    super.key,
    required this.targetDevice,
  });

  @override
  State<SendFileScreen> createState() => _SendFileScreenState();
}

class _SendFileScreenState extends State<SendFileScreen> {
  final List<PlatformFile> _selectedFiles = [];
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Files',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'to ${widget.targetDevice.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Target Device Info
          Container(
            margin: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getDeviceIcon(),
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.targetDevice.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.targetDevice.ipAddress}:${widget.targetDevice.port}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Connected',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // File Categories or Selected Files
          Expanded(
            child: _selectedFiles.isEmpty ? _buildFileCategories() : _buildSelectedFiles(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedFiles.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'} selected',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _getTotalSize(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedFiles.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSelecting ? null : _sendFiles,
                        icon: _isSelecting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                        label: Text(_isSelecting ? 'Sending...' : 'Send Files'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFileCategories() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose File Type',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the type of files you want to send',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              FileCategoryCard(
                icon: Icons.image,
                title: 'Images',
                subtitle: 'Photos, screenshots',
                color: Colors.blue,
                onTap: () => _pickFiles(FileType.image),
              ),
              FileCategoryCard(
                icon: Icons.videocam,
                title: 'Videos',
                subtitle: 'Movies, clips',
                color: Colors.red,
                onTap: () => _pickFiles(FileType.video),
              ),
              FileCategoryCard(
                icon: Icons.audiotrack,
                title: 'Audio',
                subtitle: 'Music, recordings',
                color: Colors.orange,
                onTap: () => _pickFiles(FileType.audio),
              ),
              FileCategoryCard(
                icon: Icons.description,
                title: 'Documents',
                subtitle: 'PDFs, text files',
                color: Colors.green,
                onTap: () => _pickFiles(FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf']),
              ),
              FileCategoryCard(
                icon: Icons.apps,
                title: 'Apps',
                subtitle: 'APK files',
                color: Colors.purple,
                onTap: () => _pickFiles(FileType.custom, allowedExtensions: ['apk']),
              ),
              FileCategoryCard(
                icon: Icons.folder,
                title: 'Any File',
                subtitle: 'All file types',
                color: Colors.grey,
                onTap: () => _pickFiles(FileType.any),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Selected Files',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedFiles.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickFiles(FileType.any),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add More'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              return SelectedFileItem(
                file: file,
                onRemove: () {
                  setState(() {
                    _selectedFiles.removeAt(index);
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickFiles(FileType type, {List<String>? allowedExtensions}) async {
    setState(() {
      _isSelecting = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
        allowedExtensions: allowedExtensions,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          // Add new files, avoiding duplicates
          for (final file in result.files) {
            if (!_selectedFiles.any((f) => f.path == file.path)) {
              _selectedFiles.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSelecting = false;
      });
    }
  }

  Future<void> _sendFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isSelecting = true;
    });

    try {
      final transferService = context.read<TransferService>();
      
      // Send each file
      for (final file in _selectedFiles) {
        if (file.path != null) {
          await transferService.sendFile(file.path!, widget.targetDevice);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started sending ${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSelecting = false;
      });
    }
  }

  String _getTotalSize() {
    int totalBytes = 0;
    for (final file in _selectedFiles) {
      totalBytes += file.size;
    }
    return FileStorageService.formatFileSize(totalBytes);
  }

  IconData _getDeviceIcon() {
    final deviceName = widget.targetDevice.name.toLowerCase();
    
    if (deviceName.contains('iphone') || deviceName.contains('ios')) {
      return Icons.phone_iphone;
    } else if (deviceName.contains('android')) {
      return Icons.phone_android;
    } else if (deviceName.contains('mac') || deviceName.contains('macbook')) {
      return Icons.laptop_mac;
    } else if (deviceName.contains('windows') || deviceName.contains('pc')) {
      return Icons.computer;
    } else if (deviceName.contains('tablet') || deviceName.contains('ipad')) {
      return Icons.tablet;
    }
    
    return Icons.devices;
  }
}
