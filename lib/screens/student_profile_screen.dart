import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'student_home_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => _isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _accent => _isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => _isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP => _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => _isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    _sectionCtrl.dispose();
    _rollCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Enter your name', color: _danger); return; }
    if (_classCtrl.text.trim().isEmpty) { _snack('Enter your class', color: _danger); return; }
    if (_sectionCtrl.text.trim().isEmpty) { _snack('Enter your section', color: _danger); return; }
    if (_rollCtrl.text.trim().isEmpty) { _snack('Enter your roll no', color: _danger); return; }
    if (_phoneCtrl.text.trim().isEmpty) { _snack('Enter your phone no', color: _danger); return; }

    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser!;
      await _supabase.from('student_profiles').upsert({
        'id': user.id,
        'full_name': _nameCtrl.text.trim(),
        'class': _classCtrl.text.trim(),
        'section': _sectionCtrl.text.trim(),
        'roll_no': _rollCtrl.text.trim(),
        'phone_no': _phoneCtrl.text.trim(),
        'email': user.email ?? '',
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
      );
    } catch (e) {
      _snack('Error saving profile', color: _danger);
    }

    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_outline_rounded, color: _accent, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text('Complete Your Profile', style: GoogleFonts.inter(color: _txtP, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Please fill the details below', style: GoogleFonts.inter(color: _txtM, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Fields ─────────────────────────────────────────────────────
              _field(_nameCtrl, 'Full Name', Icons.person_outline),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field(_classCtrl, 'Class', Icons.class_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _field(_sectionCtrl, 'Section', Icons.sort_by_alpha_outlined)),
              ]),
              const SizedBox(height: 14),
              _field(_rollCtrl, 'Roll No', Icons.numbers_outlined),
              const SizedBox(height: 14),
              _field(_phoneCtrl, 'Phone No', Icons.phone_outlined, keyboardType: TextInputType.phone),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save & Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: _txtP),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _txtM, size: 18),
      ),
    );
  }
}
