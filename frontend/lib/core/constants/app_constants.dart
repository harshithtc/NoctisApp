class AppConstants {
  // App Info
  static const String appName = 'NoctisApp';
  static const String appVersion = '1.0.0';
  
  // Encryption
  static const int encryptionKeyLength = 32;
  static const int ivLength = 16;
  
  // Password Requirements
  static const int passwordMinLength = 8;
  static const String passwordPattern = 
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]';
  
  // OTP
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 10;
  
  // Media Limits
  static const int maxImageSizeKB = 500;
  static const int maxVideoSizeMB = 100;
  static const int maxAudioDurationMinutes = 5;
  static const int maxFileSizeMB = 100;
  
  // Image Compression
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1440;
  static const int imageQuality = 85;
  
  // Video Compression
  static const int maxVideoWidth = 1920;
  static const int maxVideoHeight = 1080;
  
  // Cache Settings
  static const int defaultCacheSizeMB = 500;
  static const int maxCacheSizeMB = 5000;
  static const int minCacheSizeMB = 100;
  
  // Pagination
  static const int messagesPerPage = 50;
  static const int callsPerPage = 20;
  
  // Self-destruct timers (in seconds)
  static const List<int> selfDestructTimers = [
    5, 10, 30, 60, 300, 3600, 86400
  ];
  
  static const List<String> selfDestructLabels = [
    '5s', '10s', '30s', '1m', '5m', '1h', '1d'
  ];
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Debounce durations
  static const Duration typingDebounce = Duration(milliseconds: 500);
  static const Duration searchDebounce = Duration(milliseconds: 300);
}
