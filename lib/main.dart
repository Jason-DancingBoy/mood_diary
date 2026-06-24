import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'pages/home_page.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/shared_mood_provider.dart';
import 'services/message_scheduler.dart';
import 'services/image_manager.dart';
import 'services/version_service.dart';
import 'services/notification_service.dart';
import 'services/friend_chat_service.dart';
import 'services/app_trace.dart';
import 'pages/friend_chat_by_id_page.dart';
import 'widgets/update_dialog.dart';
import 'utils/page_transitions.dart';

const String imageDirectoryName = 'mood_images';
const String boxName = 'mood_logs_box';
const String messageCacheBoxName = 'message_cache_box';

Future<void> _setupInfra() async {
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(boxName);
  await Hive.openBox(messageCacheBoxName);
  await Hive.openBox('friend_chat_meta_box');

  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory('${appDir.path}/$imageDirectoryName');
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  ImageManager.warmupCache();
  await MessageScheduler.initialize();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

void main() async {
  AppTrace.start(TraceNode.appColdStart);
  WidgetsFlutterBinding.ensureInitialized();
  await _setupInfra();
  AppTrace.end(TraceNode.appColdStart, success: true);

  final dsn = dotenv.env['SENTRY_DSN'] ?? '';
  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
      options.environment = kDebugMode ? 'development' : 'production';
    },
    appRunner: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTrace.end(TraceNode.appFirstFrame, success: true);
      });
      runApp(const MyApp());
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkVersion();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await NotificationService.init();
    NotificationService.onNotificationNavigate = (friendId) {
      NotificationService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => FriendChatByIdPage(friendId: friendId),
        ),
      );
    };

    FriendChatService.startGlobalSubscription();
  }

  Future<void> _checkVersion() async {
    try {
      final current = await VersionService.currentVersion;
      final latest = await VersionService.getLatestVersion();
      if (latest == null) return;
      if (VersionService.isNewer(current, latest.latestVersion)) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: !latest.forceUpdate,
          builder: (_) => UpdateDialog(versionInfo: latest),
        );
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => SharedMoodProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '心情日记',
            navigatorKey: NotificationService.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
              scaffoldBackgroundColor: Colors.white,
              pageTransitionsTheme: customPageTransitionsTheme,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
              scaffoldBackgroundColor: const Color(0xFF121212),
              pageTransitionsTheme: customPageTransitionsTheme,
            ),
            themeMode: themeProvider.followSystem
                ? ThemeMode.system
                : (themeProvider.nightMode ? ThemeMode.dark : ThemeMode.light),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
