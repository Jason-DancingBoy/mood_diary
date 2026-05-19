import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'image_manager.dart';
import 'supabase_service.dart';

class ImageUploadService {
  ImageUploadService._();

  /// 压缩后上传，目标 ~400KB。桌面平台压缩失败时回退到原始文件上传。
  static Future<String> uploadImage(String localFileName) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final filePath = ImageManager.getImagePath(localFileName);
    final file = File(filePath);

    // 跳过 GIF 压缩
    final isGif = localFileName.toLowerCase().endsWith('.gif');
    Uint8List bytesToUpload;

    if (isGif) {
      bytesToUpload = await file.readAsBytes();
    } else {
      bytesToUpload = await _compress(filePath);
    }

    final nameWithoutExt = localFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final remotePath = '$userId/$nameWithoutExt.jpg';

    await SupabaseService.storage.uploadBinary(remotePath, bytesToUpload);

    return SupabaseService.storage.getPublicUrl(remotePath);
  }

  static Future<List<String>> uploadImages(List<String> localFileNames) async {
    final futures = localFileNames.map(uploadImage);
    return Future.wait(futures);
  }

  /// 压缩图片：先 quality=75 + 1280px，若仍 >400KB 则 quality=55
  static Future<Uint8List> _compress(String filePath) async {
    try {
      Uint8List? result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: 75,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        return await File(filePath).readAsBytes();
      }

      if (result.length > 400 * 1024) {
        final retry = await FlutterImageCompress.compressWithFile(
          filePath,
          quality: 55,
          minWidth: 1024,
          minHeight: 1024,
          format: CompressFormat.jpeg,
        );
        if (retry != null) {
          result = retry;
        }
      }

      return result;
    } catch (_) {
      return await File(filePath).readAsBytes();
    }
  }
}
