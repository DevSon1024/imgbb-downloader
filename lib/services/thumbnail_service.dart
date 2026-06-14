import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;

class ThumbnailRequest {
  final List<String> filePaths;
  final SendPort sendPort;

  ThumbnailRequest(this.filePaths, this.sendPort);
}

void generateThumbnails(ThumbnailRequest request) {
  for (var filePath in request.filePaths) {
    final file = File(filePath);
    if (file.existsSync()) {
      final imageBytes = file.readAsBytesSync();
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        final thumbnail = img.copyResize(image, width: 120);
        request.sendPort.send({'filePath': filePath, 'thumbnail': img.encodeJpg(thumbnail)});
      }
    }
  }
}