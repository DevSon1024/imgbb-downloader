import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
  List<File> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    setState(() { _isLoading = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPath = (await getApplicationDocumentsDirectory()).path;
      final downloadPath = prefs.getString('downloadPath') ?? defaultPath;

      final directory = Directory(downloadPath);
      if (await directory.exists()) {
        final files = directory.listSync()
            .whereType<File>()
            .where((file) => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((ext) => file.path.toLowerCase().endsWith(ext)))
            .toList();

        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        if (mounted) {
          setState(() {
            _images = files;
          });
        }
      }
    } catch (e) {
      print("Error loading images: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadImages,
        child: _images.isEmpty
            ? const Center(child: Text('No downloaded images found.'))
            : GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          padding: const EdgeInsets.all(4),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            return Image.file(_images[index], fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}