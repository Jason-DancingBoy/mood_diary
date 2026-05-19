import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';

class UpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  String get _updateUrl {
    if (Platform.isAndroid && versionInfo.updateUrlAndroid.isNotEmpty) {
      return versionInfo.updateUrlAndroid;
    }
    if (Platform.isIOS && versionInfo.updateUrlIos.isNotEmpty) {
      return versionInfo.updateUrlIos;
    }
    return '';
  }

  Future<void> _openUrl() async {
    final url = _updateUrl;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !versionInfo.forceUpdate,
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
            Text('新版本 ${versionInfo.latestVersion} 已发布，建议更新到最新版本以获得更好的体验。'),
            if (versionInfo.forceUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ],
        ),
        actions: [
          if (!versionInfo.forceUpdate) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后再说'),
            ),
          ],
          FilledButton(
            onPressed: () {
              _openUrl();
              if (!versionInfo.forceUpdate) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
