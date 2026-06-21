import 'package:flutter/material.dart';
import '../main.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeNotifier.value == ThemeMode.dark
          ? AppColors.background
          : AppColorsLight.background,
      body: const Center(child: Text('Student Home — Coming Soon')),
    );
  }
}
