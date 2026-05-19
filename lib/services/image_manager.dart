import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageManager {
  /// Detect image format from magic bytes and return the correct extension.
  static String _detectExtension(List<int> bytes) {
    if (bytes.length < 4) return '.jpg';
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return '.jpg';
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return '.png';
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return '.gif';
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return '.webp';
    }
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return '.bmp';
    }
    return '.jpg';
  }

  static Future<String> saveImageToFile(XFile xFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bytes = await xFile.readAsBytes();
    final ext = _detectExtension(bytes);
    final baseName = xFile.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$baseName$ext';
    final filePath = '${appDir.path}/mood_images/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return fileName;
  }

  static Future<String> getImagePathAsync(String? fileName) async {
    if (fileName == null) return '';
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/mood_images/$fileName';
  }

  /// 同步获取图片路径（使用缓存）
  static String getImagePath(String? fileName) {
    if (fileName == null) return '';
    return '$_cachedAppDirPath/mood_images/$fileName';
  }

  static String? _cachedAppDirPath;

  /// 预热缓存路径（应在应用启动时调用）
  static Future<void> warmupCache() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cachedAppDirPath = appDir.path;
  }

  static Future<void> deleteImage(String? fileName) async {
    if (fileName == null) return;
    final imagePath = await getImagePathAsync(fileName);
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}