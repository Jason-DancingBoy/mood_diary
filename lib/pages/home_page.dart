import 'package:flutter/material.dart';
import '../services/friend_chat_service.dart';
import 'mood_list_page.dart';
import 'profile_page.dart';
import 'chat_list_page.dart';
import 'message_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  static const List<Widget> _pages = <Widget>[
    MoodListPage(),
    ChatListPage(),
    MessagePage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    FriendChatService.unreadFriendIds.addListener(_onUnreadChanged);
  }

  void _onUnreadChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildChatTabIcon(bool selected) {
    final unreadCount = FriendChatService.unreadFriendIds.value.length;
    final icon = Icon(selected ? Icons.psychology : Icons.psychology_outlined);
    if (unreadCount == 0) return icon;
    return Badge(
      label: Text('$unreadCount'),
      child: icon,
    );
  }

  @override
  void dispose() {
    FriendChatService.unreadFriendIds.removeListener(_onUnreadChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '记录',
          ),
          NavigationDestination(
            icon: _buildChatTabIcon(false),
            selectedIcon: _buildChatTabIcon(true),
            label: '对话',
          ),
          const NavigationDestination(
            icon: Icon(Icons.mail_outlined),
            selectedIcon: Icon(Icons.mail),
            label: '收件箱',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
