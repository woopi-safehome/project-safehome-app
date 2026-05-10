import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryLight,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.secondaryLight,
          onSecondaryContainer: AppColors.secondaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.background,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          error: AppColors.danger,
          onError: Colors.white,
          errorContainer: AppColors.dangerBg,
          onErrorContainer: AppColors.danger,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.textPrimary,
          onInverseSurface: Colors.white,
          inversePrimary: AppColors.primaryLight,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondary,
            side: const BorderSide(color: AppColors.secondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
      );
}
