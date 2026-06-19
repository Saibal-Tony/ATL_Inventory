import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'inventory_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // ── Get current password (falls back to default) ──────────────────────────
  Future<String> _getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_password') ?? 'aTal@2026';
  }

  Future<void> _savePassword(String pw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_password', pw);
  }

  void _studentLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const InventoryScreen(isAdmin: false)),
    );
  }

  // ── Normal admin login ─────────────────────────────────────────────────────
  void _adminLogin(BuildContext context) async {
    final currentPw = await _getPassword();
    final ctrl = TextEditingController();
    bool obscure = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? AppColors.surface : AppColorsLight.surface;
          final accent = isDark ? AppColors.accent : AppColorsLight.accent;
          final txtP = isDark
              ? AppColors.textPrimary
              : AppColorsLight.textPrimary;
          final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;

          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Login',
                            style: GoogleFonts.inter(
                              color: txtP,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Enter your password',
                            style: GoogleFonts.inter(color: txtM, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    autofocus: true,
                    style: TextStyle(color: txtP),
                    onSubmitted: (_) =>
                        _checkPw(dCtx, context, ctrl.text, currentPw),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: txtM,
                          size: 18,
                        ),
                        onPressed: () => setD(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _checkPw(dCtx, context, ctrl.text, currentPw),
                          child: const Text('Unlock'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _checkPw(
    BuildContext dCtx,
    BuildContext sCtx,
    String pw,
    String currentPw,
  ) {
    Navigator.pop(dCtx);
    if (pw == currentPw) {
      Navigator.pushReplacement(
        sCtx,
        MaterialPageRoute(builder: (_) => const InventoryScreen(isAdmin: true)),
      );
    } else {
      ScaffoldMessenger.of(sCtx).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password — try again'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ── Long press — change password ──────────────────────────────────────────
  void _changePassword(BuildContext context) async {
    final currentPw = await _getPassword();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obsOld = true, obsNew = true, obsConfirm = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? AppColors.surface : AppColorsLight.surface;
          final accent = isDark ? AppColors.accent : AppColorsLight.accent;
          final txtP = isDark
              ? AppColors.textPrimary
              : AppColorsLight.textPrimary;
          final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;
          final danger = isDark ? AppColors.danger : AppColorsLight.danger;

          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.lock_reset_outlined,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Password',
                            style: GoogleFonts.inter(
                              color: txtP,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Admin only',
                            style: GoogleFonts.inter(color: txtM, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── Current password ─────────────────────────────────
                  TextField(
                    controller: oldCtrl,
                    obscureText: obsOld,
                    style: TextStyle(color: txtP),
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obsOld
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: txtM,
                          size: 18,
                        ),
                        onPressed: () => setD(() => obsOld = !obsOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── New password ─────────────────────────────────────
                  TextField(
                    controller: newCtrl,
                    obscureText: obsNew,
                    style: TextStyle(color: txtP),
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obsNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: txtM,
                          size: 18,
                        ),
                        onPressed: () => setD(() => obsNew = !obsNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Confirm new password ─────────────────────────────
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obsConfirm,
                    style: TextStyle(color: txtP),
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obsConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: txtM,
                          size: 18,
                        ),
                        onPressed: () => setD(() => obsConfirm = !obsConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Buttons ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (oldCtrl.text != currentPw) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Current password is wrong',
                                  ),
                                  backgroundColor: danger,
                                ),
                              );
                              return;
                            }
                            if (newCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'New password cannot be empty',
                                  ),
                                  backgroundColor: danger,
                                ),
                              );
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Passwords do not match'),
                                  backgroundColor: danger,
                                ),
                              );
                              return;
                            }
                            await _savePassword(newCtrl.text);
                            if (!dCtx.mounted) return;
                            Navigator.pop(dCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Password changed successfully ✓',
                                ),
                                backgroundColor: accent,
                              ),
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColorsLight.background;
    final surface = isDark ? AppColors.surface : AppColorsLight.surface;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final border = isDark ? AppColors.border : AppColorsLight.border;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Theme toggle ───────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    themeNotifier.value = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDark
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_outlined,
                          color: accent,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDark ? 'Light mode' : 'Dark mode',
                          style: GoogleFonts.inter(
                            color: txtM,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Branding ───────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surface,
                        border: Border.all(color: accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.25),
                            blurRadius: 32,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'lib/assets/logo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              'ATL',
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ATL Inventory',
                      style: GoogleFonts.inter(
                        color: txtP,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Atal Tinkering Lab  ·  Component Tracker',
                      style: GoogleFonts.inter(color: txtM, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              Text(
                'CONTINUE AS',
                style: GoogleFonts.inter(
                  color: txtM,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              _RoleCard(
                icon: Icons.school_outlined,
                title: 'Student',
                subtitle: 'Browse and search available components',
                accent: false,
                onTap: () => _studentLogin(context),
                onLongPress: null,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'Add, edit and manage inventory',
                accent: true,
                onTap: () => _adminLogin(context),
                onLongPress: () => _changePassword(context), // 🔐 hidden
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentCol = isDark ? AppColors.accent : AppColorsLight.accent;
    final surface = isDark ? AppColors.surface : AppColorsLight.surface;
    final cardC = isDark ? AppColors.card : AppColorsLight.card;
    final border = isDark ? AppColors.border : AppColorsLight.border;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent ? accentCol.withOpacity(0.07) : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent ? accentCol : border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent ? accentCol.withOpacity(0.14) : cardC,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent ? accentCol : txtM, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: txtP,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: txtM, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: accent ? accentCol : txtM,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
