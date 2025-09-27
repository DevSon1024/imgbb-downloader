import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class StorageSettingPage extends StatefulWidget {
  const StorageSettingPage({super.key});

  @override
  State<StorageSettingPage> createState() => _StorageSettingPageState();
}

class _StorageSettingPageState extends State<StorageSettingPage> {
  String? _downloadPath;

  @override
  void initState() {
    super.initState();
    _loadDownloadPath();
  }

  Future<void> _loadDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    String? defaultPath;
    if (Platform.isAndroid) {
      defaultPath = '/storage/emulated/0/Download/IMGbb Download';
    } else {
      defaultPath = (await getApplicationDocumentsDirectory()).path;
    }
    setState(() {
      _downloadPath = prefs.getString('downloadPath') ?? defaultPath;
    });
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('downloadPath', selectedDirectory);
      setState(() {
        _downloadPath = selectedDirectory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Download Location', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_downloadPath ?? 'Loading...'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickDirectory,
              child: const Text('Change Download Folder'),
            ),
          ],
        ),
      ),
    );
  }
}