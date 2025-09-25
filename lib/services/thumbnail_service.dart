import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;

class ThumbnailRequest {
  final String filePath;
  final SendPort sendPort;

  ThumbnailRequest(this.filePath, this.sendPort);
}

void generateThumbnail(ThumbnailRequest request) {
  final file = File(request.filePath);
  if (file.existsSync()) {
    final imageBytes = file.readAsBytesSync();
    final image = img.decodeImage(imageBytes);
    if (image != null) {
      final thumbnail = img.copyResize(image, width: 120);
      request.sendPort.send({'filePath': request.filePath, 'thumbnail': img.encodeJpg(thumbnail)});
    }
  }
}