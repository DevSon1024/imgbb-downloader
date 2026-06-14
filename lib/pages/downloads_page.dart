import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import 'storage_setting_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Downloads'),
      ),
      body: Consumer<DownloadService>(
        builder: (context, downloadService, child) {
          final activeTasks = downloadService.tasks
              .where((task) => task.status != DownloadStatus.completed)
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.folder),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Saving to: ${_downloadPath ?? "Loading..."}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StorageSettingPage()),
                        );
                        _loadDownloadPath();
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              if (activeTasks.isEmpty)
                const Expanded(child: NoActiveDownloads())
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: activeTasks.length,
                    itemBuilder: (context, index) {
                      final task = activeTasks[index];
                      return DownloadItem(task: task);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class NoActiveDownloads extends StatelessWidget {
  const NoActiveDownloads({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cloud_download,
            size: 100,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Downloads',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Add a new download to see it here.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}


class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  const DownloadItem({super.key, required this.task});

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final downloadService =
    Provider.of<DownloadService>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.savePath.split('/').last,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.paused)
              Column(
                children: [
                  LinearProgressIndicator(value: task.progress),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${(task.progress * 100).toStringAsFixed(0)}%'),
                      Text(_formatBytes(task.totalBytes, 2)),
                    ],
                  )
                ],
              ),
            if (task.status == DownloadStatus.failed)
              Text('Error: ${task.errorMessage}',
                  style: const TextStyle(color: Colors.red)),
            if (task.status == DownloadStatus.scraping)
              const Text('Scraping link...', style: TextStyle(color: Colors.blue)),
            if (task.status == DownloadStatus.completed)
              const Text('Completed!', style: TextStyle(color: Colors.green)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(task, downloadService),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
      DownloadTask task, DownloadService service) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return [
          IconButton(
              icon: const Icon(CupertinoIcons.pause_fill),
              onPressed: () => service.pauseDownload(task.id)),
          IconButton(
              icon: const Icon(CupertinoIcons.xmark),
              onPressed: () => service.cancelDownload(task.id)),
        ];
      case DownloadStatus.paused:
        return [
          IconButton(
              icon: const Icon(CupertinoIcons.play_arrow_solid),
              onPressed: () => service.resumeDownload(task.id)),
          IconButton(
              icon: const Icon(CupertinoIcons.xmark),
              onPressed: () => service.cancelDownload(task.id)),
        ];
      case DownloadStatus.failed:
        return [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => service.retryDownload(task.id)),
          IconButton(
              icon: const Icon(CupertinoIcons.xmark),
              onPressed: () => service.cancelDownload(task.id)),
        ];
      default:
        return [];
    }
  }
}