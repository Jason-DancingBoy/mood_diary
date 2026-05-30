import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'full_screen_image_view.dart';

class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor:
            theme.colorScheme.inversePrimary ?? theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimaryContainer ?? Colors.white,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final profile = authProvider.profile;
          if (profile == null) return const SizedBox.shrink();

          return ListView(
            children: [
              const SizedBox(height: 24),
              // Large avatar + nickname header section
              _buildHeader(context, authProvider, theme),
              const SizedBox(height: 24),
              const Divider(height: 1),
              // Detail rows
              _buildAvatarRow(context, authProvider, theme),
              const Divider(height: 1, indent: 16),
              _buildNicknameRow(context, authProvider, theme, profile.nickname),
              const Divider(height: 1, indent: 16),
              _buildFriendCodeRow(context, profile.friendCode, theme),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                icon: Icons.calendar_today,
                label: '注册时间',
                value: '${profile.createdAt.year}-'
                    '${profile.createdAt.month.toString().padLeft(2, '0')}-'
                    '${profile.createdAt.day.toString().padLeft(2, '0')}',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AuthProvider authProvider, ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _viewAvatar(context, authProvider),
                child: ClipOval(
                    child: _buildAvatarImage(authProvider, theme, size: 80)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickCropAndUploadAvatar(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          authProvider.profile!.nickname,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '好友码: ${authProvider.profile!.friendCode}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _copyFriendCode(context, authProvider.profile!.friendCode),
              child: Icon(Icons.copy, size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarImage(AuthProvider authProvider, ThemeData theme,
      {double size = 56}) {
    final fallback = Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        authProvider.profile!.nickname.isNotEmpty
            ? authProvider.profile!.nickname[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );

    if (authProvider.localAvatarPath != null) {
      return Image.file(File(authProvider.localAvatarPath!), fit: BoxFit.cover);
    }
    if (authProvider.cachedAvatarPath != null) {
      return Image.file(File(authProvider.cachedAvatarPath!), fit: BoxFit.cover);
    }
    if (authProvider.profile!.avatarUrl != null) {
      return CachedNetworkImage(
        imageUrl: authProvider.profile!.avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (c, u) => fallback,
        errorWidget: (c, u, e) => fallback,
      );
    }
    return fallback;
  }

  Widget _buildAvatarRow(
      BuildContext context, AuthProvider authProvider, ThemeData theme) {
    return ListTile(
      title: const Text('头像'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: _buildAvatarImage(authProvider, theme, size: 48),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        ],
      ),
      onTap: () => _pickCropAndUploadAvatar(context),
    );
  }

  Widget _buildNicknameRow(
      BuildContext context, AuthProvider authProvider, ThemeData theme, String currentNickname) {
    return ListTile(
      title: const Text('昵称'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentNickname,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        ],
      ),
      onTap: () => _showEditNicknameDialog(context, currentNickname),
    );
  }

  Widget _buildFriendCodeRow(BuildContext context, String code, ThemeData theme) {
    return ListTile(
      title: const Text('好友码'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _copyFriendCode(context, code),
            child: Icon(Icons.copy, size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme,
      {required IconData icon, required String label, required String value}) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      title: Text(label),
      trailing: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _viewAvatar(BuildContext context, AuthProvider authProvider) {
    final localPath =
        authProvider.localAvatarPath ?? authProvider.cachedAvatarPath;
    final networkUrl = authProvider.profile?.avatarUrl;

    if (localPath != null || networkUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageView(
            imagePath: localPath ?? '',
            imageUrls: networkUrl != null ? [networkUrl] : null,
          ),
        ),
      );
    }
  }

  Future<void> _pickCropAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: Colors.indigo,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: '裁剪头像',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );

    if (croppedFile == null) return;
    if (!context.mounted) return;

    try {
      await context.read<AuthProvider>().updateAvatar(File(croppedFile.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像更新失败: $e')),
        );
      }
    }
  }

  void _showEditNicknameDialog(BuildContext context, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入新昵称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              context.read<AuthProvider>().updateNickname(newNickname);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _copyFriendCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('好友码已复制到剪贴板')),
    );
  }
}
