import 'package:flutter/material.dart';

class AppTheme {
  // ── 核心配色 ──
  static const Color primary    = Color(0xFF1A73E8); // 智慧蓝
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color secondary  = Color(0xFF34A853); // 生机绿
  static const Color accent     = Color(0xFFFA7B17); // 活力橙（点缀）

  static const Color bg         = Color(0xFFF8F9FA); // 极浅灰背景
  static const Color surface    = Colors.white;

  static const Color titleColor = Color(0xFF1A1A2E);
  static const Color bodyColor  = Color(0xFF5F6368);
  static const Color hintColor  = Color(0xFFAEAEB2);
  static const Color borderColor = Color(0xFFE8EAED);
  static const Color errorColor = Color(0xFFEA4335);
  static const Color successColor = Color(0xFF34A853);

  // 毛玻璃用透明白
  static const Color glassWhite = Color(0xF0FFFFFF);

  // ── 圆角体系 ──
  static const double radiusXL  = 28.0;
  static const double radiusL   = 24.0;
  static const double radiusM   = 16.0;
  static const double radiusS   = 12.0;
  static const double radiusXS  = 8.0;

  // ── 渐变 ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A73E8), Color(0xFF1557B0), Color(0xFF0D47A1)],
    stops: [0.0, 0.6, 1.0],
  );

  static ThemeData get light {
    const seed = Color(0xFF1A73E8);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: primary,
        secondary: secondary,
        surface: surface,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: -1.0, height: 1.2),
        displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: titleColor, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: titleColor, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: titleColor),
        headlineSmall:  TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor),
        titleLarge:  TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: titleColor, letterSpacing: -0.2),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor),
        titleSmall:  TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: bodyColor),
        bodyLarge:   TextStyle(fontSize: 15, color: bodyColor, height: 1.65),
        bodyMedium:  TextStyle(fontSize: 13, color: bodyColor, height: 1.55),
        bodySmall:   TextStyle(fontSize: 12, color: hintColor, height: 1.4),
        labelLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
      ),

      // AppBar — 透明，字深色，iOS 风格
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: titleColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primary),
        surfaceTintColor: Colors.transparent,
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        hintStyle: const TextStyle(color: hintColor, fontSize: 14),
        labelStyle: const TextStyle(color: bodyColor, fontSize: 14),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: const BorderSide(color: Color(0xFFEEEFF2)),
        ),
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
      ),

      // NavigationBar（Material3 替代 BottomNavigationBar）
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary);
          }
          return const TextStyle(fontSize: 12, color: hintColor);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: hintColor, size: 24);
        }),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.1),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: titleColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // 全局 SnackBar 统一风格
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: titleColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0F1F5),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
