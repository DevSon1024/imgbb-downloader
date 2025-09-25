import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Downloads'),
      ),
      body: Consumer<DownloadService>(
        builder: (context, downloadService, child) {
          if (downloadService.tasks.isEmpty) {
            return const Center(
              child: Text('No active downloads.'),
            );
          }
          return ListView.builder(
            itemCount: downloadService.tasks.length,
            itemBuilder: (context, index) {
              final task = downloadService.tasks[index];
              return DownloadItem(task: task);
            },
          );
        },
      ),
    );
  }
}

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  const DownloadItem({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context, listen: false);

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
            if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused)
              LinearProgressIndicator(value: task.progress),
            if (task.status == DownloadStatus.failed)
              Text('Error: ${task.errorMessage}', style: const TextStyle(color: Colors.red)),
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

  List<Widget> _buildActionButtons(DownloadTask task, DownloadService service) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return [
          IconButton(icon: const Icon(CupertinoIcons.pause_fill), onPressed: () => service.pauseDownload(task.id)),
          IconButton(icon: const Icon(CupertinoIcons.xmark), onPressed: () => service.cancelDownload(task.id)),
        ];
      case DownloadStatus.paused:
        return [
          IconButton(icon: const Icon(CupertinoIcons.play_arrow_solid), onPressed: () => service.resumeDownload(task.id)),
          IconButton(icon: const Icon(CupertinoIcons.xmark), onPressed: () => service.cancelDownload(task.id)),
        ];
      case DownloadStatus.failed:
        return [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => service.retryDownload(task.id)),
          IconButton(icon: const Icon(CupertinoIcons.xmark), onPressed: () => service.cancelDownload(task.id)),
        ];
      default:
        return [];
    }
  }
}