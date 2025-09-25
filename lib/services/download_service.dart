import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum DownloadStatus { downloading, paused, failed, completed }

class DownloadTask {
  final String id;
  final String url;
  final String savePath;
  double progress = 0.0;
  DownloadStatus status = DownloadStatus.downloading;
  CancelToken cancelToken = CancelToken();
  String? errorMessage;

  DownloadTask({required this.id, required this.url, required this.savePath});
}

class DownloadService with ChangeNotifier {
  final Dio _dio = Dio();
  final List<DownloadTask> _tasks = [];

  List<DownloadTask> get tasks => _tasks;

  Future<void> startDownload(String url) async {
    final downloadsDir = await getApplicationDocumentsDirectory();
    final savePath = '${downloadsDir.path}/${url.split('/').last}';
    final task = DownloadTask(id: const Uuid().v4(), url: url, savePath: savePath);

    _tasks.add(task);
    notifyListeners();

    _download(task);
  }

  Future<void> _download(DownloadTask task) async {
    try {
      task.status = DownloadStatus.downloading;
      notifyListeners();

      await _dio.download(
        task.url,
        task.savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && task.status == DownloadStatus.downloading) {
            task.progress = received / total;
            notifyListeners();
          }
        },
      );

      task.status = DownloadStatus.completed;
      // Remove from active downloads list after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        _tasks.removeWhere((t) => t.id == task.id);
        notifyListeners();
      });

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Download cancelled';
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Download failed: ${e.message}';
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = 'An unknown error occurred.';
    } finally {
      notifyListeners();
    }
  }

  void cancelDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.cancelToken.cancel();
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void retryDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.progress = 0.0;
    task.errorMessage = null;
    task.cancelToken = CancelToken(); // Get a new token for the new request
    _download(task);
  }

  // Note: True pause/resume is complex and requires server support for Range headers.
  // This implementation simulates it by cancelling and restarting.
  void pauseDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.cancelToken.cancel('Download paused');
    task.status = DownloadStatus.paused;
    notifyListeners();
  }

  void resumeDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.cancelToken = CancelToken();
    _download(task); // This will restart the download
  }
}