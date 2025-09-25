import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  _DownloaderPageState createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadUrl;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => print('WebView: Started loading $url'),
          onPageFinished: (String url) => print('WebView: Finished loading $url'),
          onWebResourceError: (error) => print('WebView: Error: ${error.description}'),
        ),
      );
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        if (await Permission.photos.request().isGranted) return true;
        return false;
      }

      if (sdkInt >= 30) {
        if (await Permission.storage.request().isGranted) return true;
        if (await Permission.manageExternalStorage.request().isGranted) return true;
        return false;
      }

      if (await Permission.storage.request().isGranted) return true;
      return false;
    }
    return true;
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData != null && clipboardData.text != null) {
        _urlController.text = clipboardData.text!;
        setState(() {});

        // Validate the URL immediately after pasting
        if (!_urlController.text.trim().startsWith("https://ibb.co/")) {
          _showInvalidUrlError();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to access clipboard")),
      );
    }
  }

  void _showInvalidUrlError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("❌ This doesn't look like a valid ImgBB link"),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _downloadImage(String imagePageUrl) async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadUrl = null;
    });

    if (!await requestStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Storage permission denied'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      setState(() => _isDownloading = false);
      return;
    }

    try {
      print('Loading WebView: $imagePageUrl');
      await _webViewController.loadRequest(Uri.parse(imagePageUrl));
      await Future.delayed(const Duration(seconds: 2));

      String html = await _webViewController
          .runJavaScriptReturningResult('document.documentElement.outerHTML')
      as String;
      html = html.replaceAll(r'\"', '"').replaceAll(r'\n', '');
      print('WebView HTML length: ${html.length}');

      final RegExp reg = RegExp(r'href="([^"]+\.(?:jpg|jpeg|png|gif|webp))"[^>]*class="[^"]*btn-download[^"]*"');
      final match = reg.firstMatch(html);
      if (match == null) {
        print('No download link found in HTML');
        throw 'Download link not found in page!';
      }

      final String downloadUrl = match.group(1)!;
      print('Found download link: $downloadUrl');
      setState(() {
        _downloadUrl = downloadUrl;
      });

      Dio dio = Dio(BaseOptions(
        headers: {
          "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": imagePageUrl,
          "Accept": "image/*,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9",
          "Accept-Encoding": "gzip, deflate, br",
          "Connection": "keep-alive",
        },
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 3),
        followRedirects: true,
        maxRedirects: 10,
        receiveDataWhenStatusError: true,
      ));

      final filenameParts = downloadUrl.split('/');
      final originalFilename = filenameParts.last;
      final id = filenameParts[filenameParts.length - 2];
      final filename = '${originalFilename.split('.').first}_$id.${originalFilename.split('.').last}';
      const downloadsPath = '/storage/emulated/0/Download/IMGbb Downloaded/';
      final filePath = '$downloadsPath$filename';

      Directory(downloadsPath).createSync(recursive: true);
      print('Saving to: $filePath');

      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
            setState(() {
              _progress = progress;
            });
          } else {
            print('Total size unknown, received: $received bytes');
          }
        },
        options: Options(
          headers: {"Range": "bytes=0-"},
          responseType: ResponseType.bytes,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Image downloaded: $filename")),
      );
    } catch (e) {
      print('Error during download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: "Enter ImgBB Link",
              border: const OutlineInputBorder(),
              prefixIcon: IconButton(
                icon: const Icon(Icons.paste),
                onPressed: _pasteFromClipboard,
                tooltip: 'Paste from clipboard',
              ),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _urlController.clear();
                  setState(() {});
                },
              )
                  : null,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isDownloading
                ? null
                : () {
              final url = _urlController.text.trim();
              if (url.startsWith("https://ibb.co/")) {
                _downloadImage(url);
              } else {
                _showInvalidUrlError();
              }
            },
            icon: const Icon(Icons.download),
            label: const Text("Download Image"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_downloadUrl != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Download Link: $_downloadUrl',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _downloadUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Link copied to clipboard")),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 20),
          if (_isDownloading)
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 8,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${(_progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }
}