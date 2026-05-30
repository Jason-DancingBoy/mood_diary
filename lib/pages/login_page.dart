import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerNicknameController = TextEditingController();
  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _rememberMe = false;

  static const _keyEmail = 'saved_email';
  static const _keyPassword = 'saved_password';
  static const _keyRemember = 'remember_me';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_keyRemember) ?? false;
    if (remember) {
      final email = prefs.getString(_keyEmail) ?? '';
      final password = prefs.getString(_keyPassword) ?? '';
      _loginEmailController.text = email;
      _loginPasswordController.text = password;
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemember, true);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
  }

  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRemember);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerNicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邮箱和密码')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.login(email, password);

    if (!mounted) return;
    if (authProvider.isLoggedIn) {
      if (_rememberMe) {
        await _saveCredentials(email, password);
      }
      Navigator.of(context).pop();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  Future<void> _handleRegister() async {
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();
    final nickname = _registerNicknameController.text.trim();

    if (email.isEmpty || password.isEmpty || nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写所有字段')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码至少6位')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.register(email, password, nickname);

    if (!mounted) return;
    if (authProvider.isLoggedIn) {
      Navigator.of(context).pop();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账号'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '登录'),
            Tab(text: '注册'),
          ],
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('请稍候...'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLoginTab(theme),
              _buildRegisterTab(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.psychology, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '欢迎回到心情日记',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可以使用好友分享功能',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPasswordController,
            obscureText: _loginObscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _loginObscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _loginObscure = !_loginObscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _rememberMe,
            onChanged: (val) {
              setState(() => _rememberMe = val ?? false);
              if (!_rememberMe) _clearSavedCredentials();
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('记住密码', style: TextStyle(fontSize: 14)),
            dense: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _handleLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('登录', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.person_add, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '创建新账号',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '注册后即可与好友分享心情',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _registerNicknameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '昵称',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _registerPasswordController,
            obscureText: _registerObscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            decoration: InputDecoration(
              labelText: '密码（至少6位）',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _registerObscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _registerObscure = !_registerObscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _handleRegister,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('注册', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
