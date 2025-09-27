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
  late final Dio _dio;
  String? _statusMessage;
  bool _isFetching = false;
  bool _isDownloading = false;

  List<ScrapedImage> _scrapedImages = [];
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();

    // Initialize Dio with browser-like headers
    _dio = Dio(BaseOptions(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        }
    ));

    _headlessWebView = HeadlessInAppWebView(
      onWebViewCreated: (controller) {},
      onLoadError: (controller, url, code, message) {
        if (mounted) {
          setState(() {
            _isFetching = false;
            _isDownloading = false;
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

    setState(() { _isDownloading = true; });

    int count = 0;
    int successCount = 0;
    final downloadService = context.read<DownloadService>();
    final initialTaskCount = downloadService.tasks.length;

    for (final image in selectedImages) {
      if (!mounted) break;
      count++;
      setState(() {
        _statusMessage = "Processing ${count}/${selectedImages.length}: ${image.pageUrl.split('/').last}";
      });

      try {
        await _scrapeAndQueue(image.pageUrl, downloadService);

        // Check if a new download was actually added
        if (downloadService.tasks.length > initialTaskCount + successCount) {
          successCount++;
        }

        // Increased delay to prevent overwhelming the server
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint("Error processing ${image.pageUrl}: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _statusMessage = "$successCount out of ${selectedImages.length} downloads queued successfully.";

        // Clear selections
        for (var img in _scrapedImages) {
          img.isSelected = false;
        }
        _selectAll = false;
      });

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$successCount downloads started! Check the Downloads tab."),
            action: SnackBarAction(
              label: "View Downloads",
              onPressed: () {
                Navigator.of(context).pop('view_downloads');
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _startSingleImageDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith("https://ibb.co/") || url.startsWith("https://ibb.co/album/")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid ImgBB Image URL")),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = "Scraping image...";
    });

    final downloadService = context.read<DownloadService>();
    final initialTaskCount = downloadService.tasks.length;

    try {
      await _scrapeAndQueue(url, downloadService);

      if (mounted) {
        // Check if download was actually added
        final downloadAdded = downloadService.tasks.length > initialTaskCount;

        setState(() {
          _isDownloading = false;
          _statusMessage = downloadAdded
              ? "Download queued! View progress in the Downloads tab."
              : "Image already downloaded or could not be processed.";
        });

        if (downloadAdded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Download started! Check the Downloads tab."),
              action: SnackBarAction(
                label: "View Downloads",
                onPressed: () {
                  Navigator.of(context).pop('view_downloads');
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Error: ${e.toString()}";
        });
      }
      debugPrint("Error in single image download: $e");
    }
  }

  Future<void> _scrapeAndQueue(String pageUrl, DownloadService downloadService) async {
    setState(() {
      _statusMessage = "Fetching page: ${pageUrl.split('/').last}...";
    });

    String? html;
    // Retry logic with Dio
    for (int i = 0; i < 3; i++) {
      try {
        final response = await _dio.get<String>(pageUrl, options: Options(
            headers: {
              'Referer': 'https://imgbb.com/'
            }
        ));
        html = response.data;
        if (html != null) break;
      } catch (e) {
        debugPrint("Attempt ${i + 1} failed for $pageUrl: $e");
        if (i < 2) await Future.delayed(const Duration(seconds: 2));
      }
    }

    // WebView fallback
    if (html == null) {
      debugPrint("Dio failed, falling back to WebView for $pageUrl");
      final controller = _headlessWebView?.webViewController;
      if (controller != null) {
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri(pageUrl)));
        await Future.delayed(const Duration(seconds: 3));
        html = await controller.getHtml();
      }
    }

    if (html == null || html.isEmpty) {
      debugPrint("Could not get page content for $pageUrl");
      setState(() {
        _statusMessage = "Error: Empty response from $pageUrl";
      });
      return;
    }

    // More comprehensive regex pattern to catch ImgBB direct image URLs
    final regExp = RegExp(
        r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_.]+\.(?:jpg|jpeg|png|gif|webp|bmp|svg)',
        caseSensitive: false
    );

    final matches = regExp.allMatches(html);

    if (matches.isEmpty) {
      debugPrint("No image URLs found in HTML for $pageUrl");
      // Try alternative patterns or methods

      // Alternative: Look for meta property og:image
      final ogImageRegex = RegExp(r'<meta property="og:image" content="([^"]+)"');
      final ogMatch = ogImageRegex.firstMatch(html);

      if (ogMatch != null) {
        final imageUrl = ogMatch.group(1)!;
        debugPrint("Found og:image URL: $imageUrl");

        if (!await downloadService.isDuplicateDownload(imageUrl)) {
          await downloadService.startDownload(imageUrl);
          debugPrint("Download started for: $imageUrl");
        } else {
          debugPrint("Duplicate download detected: $imageUrl");
        }
      } else {
        setState(() {
          _statusMessage = "No downloadable image found in: ${pageUrl.split('/').last}";
        });
      }
      return;
    }

    // Process all found matches (in case there are multiple)
    bool downloadStarted = false;
    for (final match in matches) {
      final downloadUrl = match.group(0)!;
      debugPrint("Found image URL: $downloadUrl");

      if (!await downloadService.isDuplicateDownload(downloadUrl)) {
        await downloadService.startDownload(downloadUrl);
        debugPrint("Download started for: $downloadUrl");
        downloadStarted = true;
        break; // Take the first valid URL
      } else {
        debugPrint("Duplicate download detected: $downloadUrl");
      }
    }

    if (!downloadStarted) {
      setState(() {
        _statusMessage = "All images already downloaded or no valid URLs found";
      });
    }
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
                onPressed: _isFetching || _isDownloading ? null : _fetchAlbumImages,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: _isFetching ? const CircularProgressIndicator(color: Colors.white) : const Text("Fetch Images"),
              )
            else
              ElevatedButton(
                onPressed: _isDownloading ? null : _startSingleImageDownload,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: _isDownloading ? const CircularProgressIndicator(color: Colors.white) : const Text("Download Image"),
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
                onPressed: _isDownloading || _isFetching ? null : _startAlbumDownload,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: _isDownloading ? const CircularProgressIndicator(color: Colors.white) : const Text("Download Selected"),
              )
            ]
          ],
        ),
      ),
    );
  }
}