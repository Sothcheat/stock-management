import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  Future<File?> compressImage(File file) async {
    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final targetPath = '$path/${const Uuid().v4()}.jpg';

    // Compress
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 1080,
      minHeight: 1080,
      quality: 85,
    );

    if (result == null) return null;

    return File(result.path);
  }
}
