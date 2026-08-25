import 'package:flutter/material.dart';
import 'constants.dart';

class AppColors {
  static const ink = Color(0xFF111111);
  static const inkMuted = Color(0xFF666666);
  static const paper = Color(0xFFFDF6EC);
  static const green = Color(0xFF1B7A43);
  static const greenDark = Color(0xFF0B3D2E);
  static const greenLight = Color(0xFF95D5B2);
  static const yellow = Color(0xFFFFC700);
  static const red = Color(0xFFFF4B4B);
  static const blue = Color(0xFF4D96FF);
  static const surface = Colors.white;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: false,
    primaryColor: AppColors.green,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: const ColorScheme.light(
      primary: AppColors.green,
      secondary: AppColors.yellow,
      error: AppColors.red,
      surface: AppColors.surface,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.35,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.35,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: AppColors.ink, width: kBorderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: AppColors.ink, width: kBorderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: AppColors.ink, width: kBorderWidth + 0.5),
      ),
      hintStyle: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black45),
    ),
  );
}
