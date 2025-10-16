import 'package:flutter/material.dart';

/// Chat-specific theme extension to centralize bubble colors and badges.
@immutable
class ChatBubbleTheme extends ThemeExtension<ChatBubbleTheme> {
  final Color sentBubble;
  final Color receivedBubble;
  final Color sentText;
  final Color receivedText;

  const ChatBubbleTheme({
    required this.sentBubble,
    required this.receivedBubble,
    required this.sentText,
    required this.receivedText,
  });

  @override
  ChatBubbleTheme copyWith({
    Color? sentBubble,
    Color? receivedBubble,
    Color? sentText,
    Color? receivedText,
  }) {
    return ChatBubbleTheme(
      sentBubble: sentBubble ?? this.sentBubble,
      receivedBubble: receivedBubble ?? this.receivedBubble,
      sentText: sentText ?? this.sentText,
      receivedText: receivedText ?? this.receivedText,
    );
  }

  @override
  ChatBubbleTheme lerp(ThemeExtension<ChatBubbleTheme>? other, double t) {
    if (other is! ChatBubbleTheme) return this;
    return ChatBubbleTheme(
      sentBubble: Color.lerp(sentBubble, other.sentBubble, t) ?? sentBubble,
      receivedBubble: Color.lerp(receivedBubble, other.receivedBubble, t) ?? receivedBubble,
      sentText: Color.lerp(sentText, other.sentText, t) ?? sentText,
      receivedText: Color.lerp(receivedText, other.receivedText, t) ?? receivedText,
    );
  }
}

/// App-wide theme with light and dark variants.
/// Modernized for Material 3 and cross-platform polish.
class AppTheme {
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1976D2);
  static const Color lightSecondary = Color(0xFF2196F3);
  static const Color lightSentBubble = Color(0xFFE3F2FD);
  static const Color lightReceivedBubble = Color(0xFFF5F5F5);
  static const Color lightText = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);

  // Dark Theme Colors (OLED-leaning)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF00BCD4);
  static const Color darkSecondary = Color(0xFF00E5FF);
  static const Color darkSentBubble = Color(0xFF1976D2);
  static const Color darkReceivedBubble = Color(0xFF424242);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Common Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Shared radius
  static const double _radius = 12;

  // -------------------------
  // Light Theme (Material 3)
  // -------------------------
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightSecondary,
      surface: lightCard,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightText,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: lightCard,
      foregroundColor: lightText,
      centerTitle: true,
      iconTheme: IconThemeData(color: lightText),
      titleTextStyle: TextStyle(
        color: lightText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFBDBDBD)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        foregroundColor: lightPrimary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lightPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightText),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: lightText),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightText),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightText),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: lightText),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: lightText),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: lightText),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: lightText),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: lightTextSecondary),
    ),
    // Extras for M3 polish
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: Color(0xFFE3F2FD),
      elevation: 1,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF0F0F0),
      selectedColor: const Color(0xFFE3F2FD),
      disabledColor: const Color(0xFFECECEC),
      labelStyle: const TextStyle(color: lightText),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      side: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF263238),
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Inter'),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: lightPrimary,
      linearMinHeight: 4,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
      waitDuration: const Duration(milliseconds: 600),
      showDuration: const Duration(seconds: 4),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      ChatBubbleTheme(
        sentBubble: lightSentBubble,
        receivedBubble: lightReceivedBubble,
        sentText: lightText,
        receivedText: lightText,
      ),
    ],
  );

  // -------------------------
  // Dark Theme (Material 3)
  // -------------------------
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkSecondary,
      surface: darkCard,
      error: error,
      onPrimary: darkBackground,
      onSecondary: darkBackground,
      onSurface: darkText,
      onError: darkBackground,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: darkCard,
      foregroundColor: darkText,
      centerTitle: true,
      iconTheme: IconThemeData(color: darkText),
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 2,
      shadowColor: Colors.white.withValues(alpha: .05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF2E2E2E)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        foregroundColor: darkPrimary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: darkPrimary,
      foregroundColor: darkBackground,
      elevation: 4,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkText),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkText),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkText),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkText),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: darkText),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: darkText),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: darkTextSecondary),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: Color(0xFF0F2A3A),
      elevation: 1,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1F1F1F),
      selectedColor: const Color(0xFF0F2A3A),
      disabledColor: const Color(0xFF1A1A1A),
      labelStyle: const TextStyle(color: darkText),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      side: const BorderSide(color: Color(0xFF2A2A2A)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A2A),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF0F2A3A),
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Inter'),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: darkPrimary,
      linearMinHeight: 4,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
      waitDuration: const Duration(milliseconds: 600),
      showDuration: const Duration(seconds: 4),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      ChatBubbleTheme(
        sentBubble: darkSentBubble,
        receivedBubble: darkReceivedBubble,
        sentText: darkText,
        receivedText: darkText,
      ),
    ],
  );
}
