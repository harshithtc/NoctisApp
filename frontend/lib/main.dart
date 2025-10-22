import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/models/message.dart';
import 'data/models/user.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/connectivity_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/chat/chat_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print app configuration (debug only)
  AppConfig.printConfig();

  // Load environment variables from .env (only for mobile platforms)
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print("✓ .env loaded successfully (Mobile)");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠ .env not found (using --dart-define values): $e");
      }
    }
  } else {
    if (kDebugMode) {
      print("ℹ Running on Web - .env skipped (using --dart-define)");
    }
  }

  // Initialize Hive and register adapters
  await Hive.initFlutter();
  User.registerHiveAdapter();
  Message.registerHiveAdapters();

  // System UI configuration (mobile only)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Lock orientations to portrait (mobile only)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const NoctisApp());
}

class NoctisApp extends StatelessWidget {
  const NoctisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/chat': (context) => const ChatScreen(),
            },
          );
        },
      ),
    );
  }
}
