import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../services/supabase_service.dart';
import 'friend_chat_page.dart';

/// 通过 friendId 查询好友信息后，跳转到聊天页
class FriendChatByIdPage extends StatefulWidget {
  final String friendId;
  const FriendChatByIdPage({super.key, required this.friendId});

  @override
  State<FriendChatByIdPage> createState() => _FriendChatByIdPageState();
}

class _FriendChatByIdPageState extends State<FriendChatByIdPage> {
  Friend? _friend;

  @override
  void initState() {
    super.initState();
    _loadFriend();
  }

  Future<void> _loadFriend() async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, nickname, avatar_url')
          .eq('id', widget.friendId)
          .single();

      if (!mounted) return;
      final data = response;
      final friend = Friend(
        id: '',
        userId: data['id'] as String,
        nickname: data['nickname'] as String,
        avatarUrl: data['avatar_url'] as String?,
        status: FriendStatus.accepted,
        createdAt: DateTime.now(),
      );
      setState(() => _friend = friend);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_friend == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FriendChatPage(friend: _friend!)),
      );
    });
    return const SizedBox.shrink();
  }
}
