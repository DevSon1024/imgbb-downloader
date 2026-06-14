import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum DownloadStatus { downloading, paused, failed, completed, scraping }

class DownloadTask {
  final String id;
  final String pageUrl; // The ImgBB page URL, used for retries
  String? downloadUrl; // The direct image url, might expire
  final String savePath;
  double progress = 0.0;
  int totalBytes = 0;
  DownloadStatus status = DownloadStatus.scraping;
  CancelToken cancelToken = CancelToken();
  String? errorMessage;

  DownloadTask({required this.id, required this.pageUrl, this.downloadUrl, required this.savePath});
}

class DownloadService with ChangeNotifier {
  final Dio _dio = Dio();
  final List<DownloadTask> _tasks = [];
  late Box _downloadedLinksBox;
  HeadlessInAppWebView? _headlessWebView;

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
    _headlessWebView = HeadlessInAppWebView();
    _headlessWebView?.run();
  }

  Future<String?> getDownloadPath() async {
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
      } else if (Platform.isAndroid) {
        if (await _requestPermission(Permission.storage)) {
          directory = Directory('/storage/emulated/0/Download/IMGbb Download');
        } else {
          return null;
        }
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

  Future<void> addDownload(String pageUrl) async {
    if (await isDuplicateDownload(pageUrl)) {
      print("Download is a duplicate");
      return;
    }

    final downloadPath = await getDownloadPath();
    if (downloadPath == null) {
      // Handle error: show a message to the user
      return;
    }
    final fileName = pageUrl.split('/').last + ".jpg";
    final savePath = '$downloadPath/$fileName';
    final task = DownloadTask(id: const Uuid().v4(), pageUrl: pageUrl, savePath: savePath);
    _tasks.add(task);
    notifyListeners();
    _scrapeAndDownload(task);
  }

  Future<void> _scrapeAndDownload(DownloadTask task) async {
    task.status = DownloadStatus.scraping;
    notifyListeners();

    try {
      final downloadUrl = await _scrapeImageLink(task.pageUrl);
      if (downloadUrl != null) {
        task.downloadUrl = downloadUrl;
        _download(task);
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = "Could not find download link.";
        notifyListeners();
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = "Scraping failed: $e";
      notifyListeners();
    }
  }

  Future<String?> _scrapeImageLink(String pageUrl) async {
    final controller = _headlessWebView?.webViewController;
    if (controller == null) {
      return null;
    }
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(pageUrl)));
    await Future.delayed(const Duration(seconds: 3)); // Wait for page to load
    final html = await controller.getHtml();
    if (html != null) {
      final regExp = RegExp(
          r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_.]+\.(?:jpg|jpeg|png|gif|webp|bmp|svg)',
          caseSensitive: false);
      final match = regExp.firstMatch(html);
      return match?.group(0);
    }
    return null;
  }

  Future<void> _download(DownloadTask task) async {
    try {
      task.status = DownloadStatus.downloading;
      notifyListeners();

      await _dio.download(
        task.downloadUrl!,
        task.savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && task.status == DownloadStatus.downloading) {
            task.progress = received / total;
            task.totalBytes = total;
            notifyListeners();
          }
        },
      );

      if (task.cancelToken.isCancelled) return;

      task.status = DownloadStatus.completed;
      await _logDownload(task.pageUrl);

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
    _scrapeAndDownload(task);
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
    if (task.downloadUrl != null) {
      _download(task);
    } else {
      _scrapeAndDownload(task);
    }
  }
}