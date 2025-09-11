import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/device.dart';
import '../services/file_service.dart';
import '../widgets/file_item.dart';
import 'transfer_screen.dart';

class FilePickerScreen extends StatefulWidget {
  final Device targetDevice;

  const FilePickerScreen({
    super.key,
    required this.targetDevice,
  });

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  final List<File> _selectedFiles = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send to ${widget.targetDevice.name}'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _sendFiles,
              child: Text('Send (${_selectedFiles.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                  ),
                ),
                const SizedBox(width: 16),
                if (_selectedFiles.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No files selected',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Add Files" to select files to send',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return FileItem(
                        file: file,
                        onRemove: () => _removeFile(index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _sendFiles,
              icon: const Icon(Icons.send),
              label: Text('Send ${_selectedFiles.length} file${_selectedFiles.length > 1 ? 's' : ''}'),
            )
          : null,
    );
  }

  Future<void> _pickFiles() async {
    setState(() => _isLoading = true);
    
    try {
      final fileService = context.read<FileService>();
      final files = await fileService.pickFiles();
      
      setState(() {
        _selectedFiles.addAll(files);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _sendFiles() {
    if (_selectedFiles.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          files: _selectedFiles,
          targetDevice: widget.targetDevice,
          isSending: true,
        ),
      ),
    );
  }
}
