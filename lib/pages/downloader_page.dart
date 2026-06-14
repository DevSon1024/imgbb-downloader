import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';

// Data model to hold information about each scraped image
class ScrapedImage {
  final String pageUrl;
  final String thumbnailUrl;
  bool isSelected;

  ScrapedImage({
    required this.pageUrl,
    required this.thumbnailUrl,
    this.isSelected = false,
  });
}

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});
  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Download'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Image'),
            Tab(text: 'Album'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DownloadView(isAlbum: false),
          DownloadView(isAlbum: true),
        ],
      ),
    );
  }
}

class DownloadView extends StatefulWidget {
  final bool isAlbum;
  const DownloadView({super.key, required this.isAlbum});

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _urlController = TextEditingController();
  HeadlessInAppWebView? _headlessWebView;
  String? _statusMessage;
  bool _isFetching = false;

  List<ScrapedImage> _scrapedImages = [];
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _headlessWebView = HeadlessInAppWebView(
      onWebViewCreated: (controller) {},
      onLoadError: (controller, url, code, message) {
        if (mounted) {
          setState(() {
            _isFetching = false;
            _statusMessage = "Error loading page: $message";
          });
        }
      },
    );
    _headlessWebView?.run();
    _pasteFromClipboard();
  }

  @override
  void dispose() {
    _headlessWebView?.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    final text = clipboardData?.text;
    if (text != null) {
      if ((widget.isAlbum && text.startsWith("https://ibb.co/album/")) ||
          (!widget.isAlbum && text.startsWith("https://ibb.co/") && !text.startsWith("https://ibb.co/album/"))) {
        setState(() {
          _urlController.text = text;
        });
      }
    }
  }

  Future<void> _fetchAlbumImages() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith("https://ibb.co/album/")) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid ImgBB Album URL")));
      return;
    }

    setState(() {
      _isFetching = true;
      _scrapedImages = [];
      _statusMessage = "Fetching images from album...";
    });

    final controller = _headlessWebView?.webViewController;
    if (controller == null) {
      setState(() { _isFetching = false; _statusMessage = "Error: Webview not ready."; });
      return;
    }

    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    await controller.evaluateJavascript(source: '''
      (async () => {
        const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
        let lastHeight = 0; let newHeight = document.body.scrollHeight;
        while (lastHeight !== newHeight) {
          window.scrollTo(0, document.body.scrollHeight);
          await delay(800); lastHeight = newHeight; newHeight = document.body.scrollHeight;
        }
      })();
    ''');
    await Future.delayed(const Duration(seconds: 3));

    final result = await controller.evaluateJavascript(source: '''
      Array.from(document.querySelectorAll('a.image-container.--media')).map(a => {
        const img = a.querySelector('img');
        return { pageUrl: a.href, thumbnailUrl: img ? img.src : '' };
      });
    ''');

    if (mounted && result is List && result.isNotEmpty) {
      setState(() {
        _scrapedImages = result
            .where((item) => item['pageUrl'] != null && item['thumbnailUrl'] != null)
            .map((item) => ScrapedImage(
            pageUrl: item['pageUrl'], thumbnailUrl: item['thumbnailUrl']))
            .toList();
        _statusMessage = "Found ${_scrapedImages.length} images. Select images to download.";
      });
    } else if (mounted) {
      setState(() => _statusMessage = "No images found in this album.");
    }

    if (mounted) setState(() => _isFetching = false);
  }

  Future<void> _startAlbumDownload() async {
    final selectedImages = _scrapedImages.where((img) => img.isSelected).toList();
    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image to download.")),
      );
      return;
    }

    final downloadService = context.read<DownloadService>();
    for (final image in selectedImages) {
      downloadService.addDownload(image.pageUrl);
    }
    Navigator.of(context).pop('view_downloads');
  }

  Future<void> _startSingleImageDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith("https://ibb.co/") || url.startsWith("https://ibb.co/album/")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid ImgBB Image URL")),
      );
      return;
    }
    context.read<DownloadService>().addDownload(url);
    Navigator.of(context).pop('view_downloads');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: "Enter ImgBB ${widget.isAlbum ? 'Album' : 'Page'} URL",
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.paste), onPressed: _pasteFromClipboard),
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => _urlController.clear()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (widget.isAlbum)
              ElevatedButton(
                onPressed: _isFetching ? null : _fetchAlbumImages,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: _isFetching ? const CircularProgressIndicator(color: Colors.white) : const Text("Fetch Images"),
              )
            else
              ElevatedButton(
                onPressed: _startSingleImageDownload,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: const Text("Download Image"),
              ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_statusMessage!, textAlign: TextAlign.center),
              ),
            ],

            if (widget.isAlbum && _scrapedImages.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Select Images:", style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectAll = !_selectAll;
                        for (var image in _scrapedImages) {
                          image.isSelected = _selectAll;
                        }
                      });
                    },
                    child: Text(_selectAll ? "Deselect All" : "Select All"),
                  )
                ],
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _scrapedImages.length,
                itemBuilder: (context, index) {
                  final image = _scrapedImages[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        image.isSelected = !image.isSelected;
                      });
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            image.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                          ),
                          if (image.isSelected)
                            Container(
                              color: Colors.black.withOpacity(0.6),
                              child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
                            )
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isFetching ? null : _startAlbumDownload,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: const Text("Download Selected"),
              )
            ]
          ],
        ),
      ),
    );
  }
}