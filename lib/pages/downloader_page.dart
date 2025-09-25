import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _statusMessage;
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _headlessWebView = HeadlessInAppWebView(
      onWebViewCreated: (controller) {
        _webViewController = controller;
        print("Headless WebView created!");
      },
      onLoadStop: (controller, url) async {
        print("Headless WebView loaded: $url");
        if (url.toString() != "about:blank") {
          await _extractAndDownloadImage(controller, url.toString());
        }
      },
      onLoadError: (controller, url, code, message) {
        print("Error loading page: $message");
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = "Error: Failed to load page.";
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _headlessWebView?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startDownloadProcess() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith("https://ibb.co/")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid imgbb.co URL")),
      );
      return;
    }

    if (!await _requestStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Storage permission denied'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = "Starting download...";
    });

    try {
      if (!(_headlessWebView?.isRunning() ?? false)) {
        await _headlessWebView?.run();
      }
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _extractAndDownloadImage(
      InAppWebViewController controller, String pageUrl) async {
    try {
      await Future.delayed(const Duration(seconds: 3));

      final String? html = await controller.getHtml();

      if (html == null) {
        throw "Could not get page content.";
      }

      final RegExp reg = RegExp(
          r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_]+\.(?:jpg|jpeg|png|gif|webp)');
      final Match? match = reg.firstMatch(html);

      if (match == null) {
        throw "Download link not found on the page.";
      }

      final String downloadUrl = match.group(0)!;

      if (mounted) {
        setState(() {
          _statusMessage = "Download link found! Starting download...";
        });
      }

      await _downloadFile(downloadUrl, pageUrl);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _downloadFile(String downloadUrl, String pageUrl) async {
    final dio = Dio();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = downloadUrl.split('/').last;
      final savePath = "${dir.path}/$filename";

      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
              _statusMessage =
              "Downloading... ${(_progress * 100).toStringAsFixed(0)}%";
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Download complete! Saved to $savePath";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Download failed: $e";
        });
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 30) {
        return true;
      }
    }
    var status = await Permission.storage.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: "Enter ImgBB Page URL",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isDownloading ? null : _startDownloadProcess,
            child: const Text("Download Image"),
          ),
          const SizedBox(height: 20),
          if (_isDownloading)
            Column(
              children: [
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(_statusMessage ?? ""),
              ],
            ),
          if (!_isDownloading && _statusMessage != null)
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}