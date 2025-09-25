import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import '../services/thumbnail_service.dart';
import 'package:hive/hive.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
  List<File> _images = [];
  Map<String, Uint8List> _thumbnails = {};
  bool _isLoading = true;
  bool _isGridView = true;
  ReceivePort? _receivePort;
  Box? _thumbnailBox;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _thumbnailBox = Hive.box('thumbnails');
    _loadImages();
    _startThumbnailGeneration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopThumbnailGeneration();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadImages();
    }
  }

  void _startThumbnailGeneration() {
    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (mounted) {
        setState(() {
          _thumbnails[message['filePath']] = message['thumbnail'];
          _thumbnailBox?.put(message['filePath'], message['thumbnail']);
        });
      }
    });
  }

  void _stopThumbnailGeneration() {
    _receivePort?.close();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPath = (await getApplicationDocumentsDirectory()).path;
      final downloadPath = prefs.getString('downloadPath') ?? defaultPath;

      final directory = Directory(downloadPath);
      if (await directory.exists()) {
        final files = directory
            .listSync()
            .whereType<File>()
            .where((file) => [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp'
        ].any((ext) => file.path.toLowerCase().endsWith(ext)))
            .toList();

        files.sort(
                (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        if (mounted) {
          setState(() {
            _images = files;
          });
          _generateThumbnails();
        }
      }
    } catch (e) {
      print("Error loading images: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _generateThumbnails() {
    for (var file in _images) {
      if (_thumbnailBox!.containsKey(file.path)) {
        setState(() {
          _thumbnails[file.path] = _thumbnailBox!.get(file.path);
        });
      } else if (!_thumbnails.containsKey(file.path)) {
        Isolate.spawn(
            generateThumbnail, ThumbnailRequest(file.path, _receivePort!.sendPort));
      }
    }
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadImages,
        child: _images.isEmpty
            ? const Center(child: Text('No downloaded images found.'))
            : _isGridView
            ? GridView.builder(
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          padding: const EdgeInsets.all(4),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            final file = _images[index];
            final thumbnail = _thumbnails[file.path];
            return GestureDetector(
              onTap: () => OpenFile.open(file.path),
              child: thumbnail != null
                  ? Image.memory(thumbnail, fit: BoxFit.cover)
                  : const Center(
                  child: CircularProgressIndicator()),
            );
          },
        )
            : ListView.builder(
          itemCount: _images.length,
          itemBuilder: (context, index) {
            final file = _images[index];
            final thumbnail = _thumbnails[file.path];
            return ListTile(
              leading: thumbnail != null
                  ? Image.memory(thumbnail,
                  width: 50, height: 50, fit: BoxFit.cover)
                  : const Icon(Icons.image),
              title: Text(file.path.split('/').last),
              subtitle: Text(_formatBytes(file.lengthSync(), 2)),
              onTap: () => OpenFile.open(file.path),
            );
          },
        ),
      ),
    );
  }
}