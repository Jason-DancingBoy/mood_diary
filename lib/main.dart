import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'providers/theme_provider.dart';
import 'services/message_scheduler.dart';
import 'services/image_manager.dart';

const String imageDirectoryName = 'mood_images';
const String boxName = 'mood_logs_box';
const String messageCacheBoxName = 'message_cache_box';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(boxName);
  await Hive.openBox(messageCacheBoxName);

  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory('${appDir.path}/$imageDirectoryName');
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  // 预热图片路径缓存
  ImageManager.warmupCache();

  // 初始化消息调度器
  await MessageScheduler.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        title: '心情日记',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
          scaffoldBackgroundColor: Colors.white,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
