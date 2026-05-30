import 'package:package_info_plus/package_info_plus.dart';
import 'supabase_service.dart';

class VersionInfo {
  final String latestVersion;
  final String updateUrlAndroid;
  final String updateUrlIos;
  final bool forceUpdate;

  VersionInfo({
    required this.latestVersion,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
    required this.forceUpdate,
  });
}

class VersionService {
  VersionService._();

  static Future<String> get currentVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<VersionInfo?> getLatestVersion() async {
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select()
          .or('key.eq.latest_version,key.eq.update_url_android,key.eq.update_url_ios,key.eq.force_update');

      final rows = response as List;
      String latestVersion = '';
      String updateUrlAndroid = '';
      String updateUrlIos = '';
      bool forceUpdate = false;

      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        switch (map['key']) {
          case 'latest_version':
            latestVersion = map['value'] as String;
          case 'update_url_android':
            updateUrlAndroid = map['value'] as String;
          case 'update_url_ios':
            updateUrlIos = map['value'] as String;
          case 'force_update':
            forceUpdate = (map['value'] as String) == 'true';
        }
      }

      if (latestVersion.isEmpty) return null;

      return VersionInfo(
        latestVersion: latestVersion,
        updateUrlAndroid: updateUrlAndroid,
        updateUrlIos: updateUrlIos,
        forceUpdate: forceUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  /// 比较两个语义化版本号，返回 true 表示 [latest] 比 [current] 新
  static bool isNewer(String current, String latest) {
    // 去掉构建元数据（+ 之后的部分）和预发布标识（- 之后的部分）
    String clean(String v) {
      var cleaned = v.split('+').first;
      cleaned = cleaned.split('-').first;
      return cleaned.trim();
    }

    try {
      final currentParts = clean(current).split('.').map(int.parse).toList();
      final latestParts = clean(latest).split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return clean(current) != clean(latest);
    }
  }
}
