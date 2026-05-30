import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';

class UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;
  CancelToken? _cancelToken;
  Dio? _dio;

  String get _updateUrl {
    if (Platform.isAndroid && widget.versionInfo.updateUrlAndroid.isNotEmpty) {
      return widget.versionInfo.updateUrlAndroid;
    }
    if (Platform.isIOS && widget.versionInfo.updateUrlIos.isNotEmpty) {
      return widget.versionInfo.updateUrlIos;
    }
    return '';
  }

  bool get _isApkUrl =>
      Platform.isAndroid && _updateUrl.toLowerCase().endsWith('.apk');

  Future<void> _downloadAndInstall() async {
    final url = _updateUrl;
    if (url.isEmpty) return;

    // 非 APK 链接（如应用商店），直接用浏览器打开
    if (!_isApkUrl) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!widget.versionInfo.forceUpdate && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        setState(() {
          _error = '无法访问存储空间';
          _isDownloading = false;
        });
        return;
      }

      final savePath = '${dir.path}/app_update.apk';
      // 删除旧的更新文件（如果存在）
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      _cancelToken = CancelToken();
      _dio = Dio();
      _dio!.options.connectTimeout = const Duration(seconds: 15);
      _dio!.options.receiveTimeout = const Duration(minutes: 10);

      await _dio!.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      // 触发安装
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        setState(() {
          _error = '安装失败: ${result.message}';
          _isDownloading = false;
        });
        return;
      }

      if (!widget.versionInfo.forceUpdate && mounted) {
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (mounted) {
        setState(() {
          _error = '下载失败，请检查网络后重试';
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '下载失败: $e';
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _dio?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.versionInfo.forceUpdate,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '新版本 ${widget.versionInfo.latestVersion} 已发布，建议更新到最新版本以获得更好的体验。',
            ),
            if (widget.versionInfo.forceUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '此版本为强制更新',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '下载中 ${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.versionInfo.forceUpdate && !_isDownloading) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后再说'),
            ),
          ],
          FilledButton(
            onPressed: _isDownloading ? null : _downloadAndInstall,
            child: Text(_isDownloading ? '下载中...' : '立即更新'),
          ),
        ],
      ),
    );
  }
}
