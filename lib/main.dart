import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';

const kSupabaseUrl = 'https://prtdtgxrflklxribomoy.supabase.co';
const kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBydGR0Z3hyZmxrbHhyaWJvbW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNzIxNzEsImV4cCI6MjA5Njg0ODE3MX0.NhOd5liN3rU-3OI6rFMZxXetBHe_3HSmT1t-POoxDE0';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

class AppColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF161B27);
  static const card = Color(0xFF1E2533);
  static const border = Color(0xFF2A3142);
  static const accent = Color(0xFF00D4AA);
  static const danger = Color(0xFFFF5757);
  static const warning = Color(0xFFFFB300);
  static const textPrimary = Color(0xFFE6EAF0);
  static const textMuted = Color(0xFF8892A4);
}

class AppColorsLight {
  static const background = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFEDF0F7);
  static const border = Color(0xFFDDE1EA);
  static const accent = Color(0xFF009E7F);
  static const danger = Color(0xFFE53935);
  static const warning = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFF1A1F2E);
  static const textMuted = Color(0xFF64748B);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  runApp(const ATLInventoryApp());
}

class ATLInventoryApp extends StatelessWidget {
  const ATLInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final isDark = mode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? AppColors.background : AppColorsLight.background,
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ATL Inventory',
          themeMode: mode,
          theme: _buildTheme(dark: false),
          darkTheme: _buildTheme(dark: true),
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme({required bool dark}) {
    final bg = dark ? AppColors.background : AppColorsLight.background;
    final surface = dark ? AppColors.surface : AppColorsLight.surface;
    final cardC = dark ? AppColors.card : AppColorsLight.card;
    final accent = dark ? AppColors.accent : AppColorsLight.accent;
    final border = dark ? AppColors.border : AppColorsLight.border;
    final txtP = dark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = dark ? AppColors.textMuted : AppColorsLight.textMuted;
    final danger = dark ? AppColors.danger : AppColorsLight.danger;
    final base = dark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: dark ? AppColors.background : Colors.white,
        secondary: accent,
        onSecondary: dark ? AppColors.background : Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: txtP,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: txtP, displayColor: txtP),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: txtM),
        titleTextStyle: GoogleFonts.inter(color: txtP, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      cardColor: cardC,
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardC,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
        labelStyle: TextStyle(color: txtM),
        hintStyle: TextStyle(color: txtM),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: dark ? AppColors.background : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txtM,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: cardC,
        contentTextStyle: GoogleFonts.inter(color: txtP),
      ),
    );
  }
}
