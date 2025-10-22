import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration - passed via --dart-define
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: kDebugMode 
      ? 'http://localhost:8000'
      : 'https://api.example.com', // fallback for production
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: kDebugMode
      ? 'ws://localhost:8000'
      : 'wss://api.example.com',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '', // No default for security
  );

  // App Configuration
  static const String appName = 'NoctisApp';
  static const String appVersion = '1.0.0';

  // Feature Flags
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  // Environment Detection
  static bool get isProduction => const bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: false,
  );

  static bool get isDevelopment => !isProduction;

  // Debug Info
  static void printConfig() {
    if (kDebugMode) {
      print('=== App Configuration ===');
      print('API URL: $apiUrl');
      print('WS URL: $wsUrl');
      print('Environment: ${isProduction ? "Production" : "Development"}');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('========================');
    }
  }
}
