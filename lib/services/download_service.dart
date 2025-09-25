import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _downloadedLinksKey = 'downloaded_links';

  List<DownloadTask> get tasks => _tasks;

  Future<String> _getDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('downloadPath');
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return customPath;
      }
    }
    // Fallback to default documents directory if custom path is not set or invalid
    final defaultDir = await getApplicationDocumentsDirectory();
    return defaultDir.path;
  }

  Future<bool> isDuplicateDownload(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedLinks = prefs.getStringList(_downloadedLinksKey) ?? [];
    return downloadedLinks.contains(url);
  }

  Future<void> _logDownload(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedLinks = prefs.getStringList(_downloadedLinksKey) ?? [];
    if (!downloadedLinks.contains(url)) {
      downloadedLinks.add(url);
      await prefs.setStringList(_downloadedLinksKey, downloadedLinks);
    }
  }

  Future<void> startDownload(String url) async {
    final downloadPath = await _getDownloadPath();
    final fileName = url.split('/').last;
    // Ensure the directory exists
    await Directory(downloadPath).create(recursive: true);
    final savePath = '$downloadPath/$fileName';
    final task =
    DownloadTask(id: const Uuid().v4(), url: url, savePath: savePath);

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
      _logDownload(task.url); // Log the download
      notifyListeners();

      Future.delayed(const Duration(seconds: 4), () {
        _tasks.removeWhere((t) => t.id == task.id);
        notifyListeners();
      });
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Download cancelled';
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Download failed';
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
    task.cancelToken = CancelToken();
    _download(task);
  }

  void pauseDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.cancelToken.cancel('Download paused');
    task.status = DownloadStatus.paused;
    notifyListeners();
  }

  void resumeDownload(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.cancelToken = CancelToken();
    _download(task);
  }
}