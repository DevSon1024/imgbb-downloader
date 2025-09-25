import 'package:flutter/material.dart';
import 'dart:io';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<File> _images = [];
  String _sortOption = 'Newest to Oldest';

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    const downloadsPath = '/storage/emulated/0/Download/IMGbb Downloaded/';
    final directory = Directory(downloadsPath);
    if (await directory.exists()) {
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg') ||
          file.path.endsWith('.jpeg') ||
          file.path.endsWith('.png') ||
          file.path.endsWith('.gif') ||
          file.path.endsWith('.webp'))
          .toList();
      setState(() {
        _images = files.cast<File>();
        _sortImages();
      });
    }
  }

  void _sortImages() {
    setState(() {
      switch (_sortOption) {
        case 'Newest to Oldest':
          _images.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          break;
        case 'Oldest to Newest':
          _images.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
          break;
        case 'Largest to Smallest':
          _images.sort((a, b) => b.statSync().size.compareTo(a.statSync().size));
          break;
        case 'Smallest to Largest':
          _images.sort((a, b) => a.statSync().size.compareTo(b.statSync().size));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _sortOption,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Newest to Oldest', child: Text('Newest to Oldest')),
              DropdownMenuItem(value: 'Oldest to Newest', child: Text('Oldest to Newest')),
              DropdownMenuItem(value: 'Largest to Smallest', child: Text('Largest to Smallest')),
              DropdownMenuItem(value: 'Smallest to Largest', child: Text('Smallest to Largest')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortOption = value;
                  _sortImages();
                });
              }
            },
          ),
        ),
        Expanded(
          child: _images.isEmpty
              ? const Center(child: Text('No images downloaded yet'))
              : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            padding: const EdgeInsets.all(8),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final file = _images[index];
              return Card(
                elevation: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        file.path.split('/').last,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}