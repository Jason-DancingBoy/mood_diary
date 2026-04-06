import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageManager {
  static Future<String> saveImageToFile(XFile xFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
    final filePath = '${appDir.path}/mood_images/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await xFile.readAsBytes());

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