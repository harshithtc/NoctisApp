class ApiConstants {
  // Base URLs - Change for production
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8000',
  );

  // API version
  static const String apiVersion = '/api/v1';

  // Auth
  static const String register = '$apiVersion/auth/register';
  static const String verifyEmail = '$apiVersion/auth/verify-email';
  static const String resendVerification = '$apiVersion/auth/resend-verification';
  static const String login = '$apiVersion/auth/login';
  static const String logout = '$apiVersion/auth/logout';
  static const String refreshToken = '$apiVersion/auth/refresh-token';
  static const String changePassword = '$apiVersion/auth/change-password';
  static const String resetPassword = '$apiVersion/auth/reset-password';

  // Messages
  static const String messages = '$apiVersion/messages';
  static String messageById(String id) => '$messages/$id';
  static String messageReact(String id) => '$messages/$id/react';
  static String messageMarkRead(String id) => '$messages/$id/mark-read';

  // WebSocket
  static const String chatWs = '/ws/chat';

  // Media
  static const String media = '$apiVersion/media';
  static const String uploadImage = '$media/upload/image';
  static const String uploadVideo = '$media/upload/video';

  // Calls
  static const String calls = '$apiVersion/calls';
  static String callById(String id) => '$calls/$id';
  static const String callsInitiate = '$calls/initiate';
  static String callsAnswer(String id) => '$calls/$id/answer';
  static String callsEnd(String id) => '$calls/$id/end';
  static String callsStatus(String id) => '$calls/$id/status';
  static const String callsHistory = '$calls/history';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
