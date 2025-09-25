import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});
  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final TextEditingController _urlController = TextEditingController();
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;
  String? _statusMessage;
  bool _isScraping = false;

  @override
  void initState() {
    super.initState();
    _headlessWebView = HeadlessInAppWebView(
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStop: (controller, url) async {
        if (url != null && url.toString() != "about:blank") {
          await _extractImageLink(controller);
        }
      },
      onLoadError: (controller, url, code, message) {
        if (mounted) {
          setState(() {
            _isScraping = false;
            _statusMessage = "Error loading page: $message";
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _headlessWebView?.dispose();
    super.dispose();
  }

  Future<void> _startScraping() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith("https://ibb.co/")) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid imgbb.co URL")));
      return;
    }

    setState(() {
      _isScraping = true;
      _statusMessage = "Scraping page for download link...";
    });

    try {
      if (!(_headlessWebView?.isRunning() ?? false)) {
        await _headlessWebView?.run();
      }

      if (_webViewController != null) {
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
      } else {
        throw Exception("WebView controller is not available.");
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _isScraping = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _extractImageLink(InAppWebViewController controller) async {
    await Future.delayed(const Duration(seconds: 3));
    final html = await controller.getHtml();

    if (html == null) {
      if(mounted) {
        setState(() {
          _isScraping = false;
          _statusMessage = "Could not get page content.";
        });
      }
      return;
    }

    final regExp = RegExp(
        r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_]+\.(?:jpg|jpeg|png|gif|webp)');
    final match = regExp.firstMatch(html);

    if (match != null) {
      final downloadUrl = match.group(0)!;
      final downloadService = context.read<DownloadService>();
      downloadService.startDownload(downloadUrl);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Download started!"),
          action: SnackBarAction(
            label: "View",
            onPressed: () {
              // Corrected: Pop this page and send a result back to MainScreen
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop('view_downloads');
              }
            },
          ),
        ));
      }

    } else {
      _statusMessage = "Download link not found.";
    }

    if(mounted) {
      setState(() { _isScraping = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Download')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                onPressed: _isScraping ? null : _startScraping,
                child: _isScraping
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Get Download Link"),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Text(_statusMessage!),
              ]
            ],
          ),
        ),
      ),
    );
  }
}