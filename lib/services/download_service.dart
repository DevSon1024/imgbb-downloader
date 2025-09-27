import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  late Box _downloadedLinksBox;

  List<DownloadTask> get tasks => _tasks;

  DownloadService() {
    _init();
  }

  void _init() async {
    if (!Hive.isBoxOpen('downloaded_links')) {
      _downloadedLinksBox = await Hive.openBox('downloaded_links');
    } else {
      _downloadedLinksBox = Hive.box('downloaded_links');
    }
  }

  Future<String?> _getDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('downloadPath');
    if (customPath != null) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return customPath;
      }
    }

    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        if (await _requestPermission(Permission.storage)) {
          Directory? downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            directory = Directory('${downloadsDir.path}/IMGbb Downloads');
          }
        } else {
          return null;
        }
      }
    } catch (err) {
      debugPrint("Cannot get download directory: $err");
    }

    if (directory != null && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory?.path;
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      return result == PermissionStatus.granted;
    }
  }

  Future<bool> isDuplicateDownload(String url) async {
    return _downloadedLinksBox.containsKey(url);
  }

  Future<void> _logDownload(String url) async {
    await _downloadedLinksBox.put(url, true);
  }

  Future<void> startDownload(String url) async {
    debugPrint("Starting download for: $url");

    final downloadPath = await _getDownloadPath();
    if (downloadPath == null) {
      debugPrint("Download path is not available. Check permissions.");
      return;
    }

    // Extract filename from URL and sanitize it
    String fileName = url.split('/').last;
    if (fileName.isEmpty) {
      fileName = 'image_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Remove any invalid characters
    fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    // Ensure file has an extension
    if (!fileName.contains('.')) {
      fileName += '.jpg'; // Default extension
    }

    final savePath = '$downloadPath/$fileName';
    debugPrint("Save path: $savePath");

    final task = DownloadTask(id: const Uuid().v4(), url: url, savePath: savePath);

    _tasks.add(task);
    debugPrint("Task added to queue. Total tasks: ${_tasks.length}");
    notifyListeners();

    // Start download immediately
    await _download(task);
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

      if (task.cancelToken.isCancelled) return;

      task.status = DownloadStatus.completed;
      await _logDownload(task.url);

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
        task.errorMessage = 'Download cancelled';
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Download failed: ${e.message}';
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = 'An unknown error occurred.';
    } finally {
      // **CRITICAL FIX**: Do not auto-remove the task here.
      // This was the source of the framework crash.
      notifyListeners();
    }
  }

  void cancelDownload(String taskId) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      _tasks[taskIndex].cancelToken.cancel();
      _tasks.removeAt(taskIndex);
      notifyListeners();
    }
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