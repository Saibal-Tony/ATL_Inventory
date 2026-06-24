import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'student_profile_screen.dart';
import 'student_home_screen.dart';

class StudentAuthScreen extends StatefulWidget {
  const StudentAuthScreen({super.key});

  @override
  State<StudentAuthScreen> createState() => _StudentAuthScreenState();
}

class _StudentAuthScreenState extends State<StudentAuthScreen> {
  final _supabase = Supabase.instance.client;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => _isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => _isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => _isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => _isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => _isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP =>
      _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => _isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Check if profile exists ────────────────────────────────────────────────
  Future<bool> _hasProfile(String userId) async {
    try {
      final data = await _supabase
          .from('student_profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return data != null;
    } catch (_) {
      return false;
    }
  }

  // ── Navigate after auth ────────────────────────────────────────────────────
  Future<void> _navigateAfterAuth(String userId) async {
    // Sign out any existing admin session first (clean slate)
    final hasProfile = await _hasProfile(userId);
    if (!mounted) return;
    if (hasProfile) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
      );
    }
  }

  // ── Email/Password auth ────────────────────────────────────────────────────
  Future<void> _emailAuth() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      _snack('Please fill all fields', color: _danger);
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        final res = await _supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
        if (res.user != null) await _navigateAfterAuth(res.user!.id);
      } else {
        final res = await _supabase.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
        if (res.user != null) {
          // Check if email confirmation required
          if (res.session == null) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EmailVerifyScreen(email: _emailCtrl.text.trim()),
              ),
            );
          } else {
            await _navigateAfterAuth(res.user!.id);
          }
        }
      }
    } on AuthException catch (e) {
      _snack(e.message, color: _danger);
    } catch (e) {
      _snack('Something went wrong', color: _danger);
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Google Sign In ─────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      const webClientId =
          '1006263888737-6e2hk96muhe23qk7i79u4pml24f7thru.apps.googleusercontent.com';
      const androidClientId =
          '1006263888737-g3lltq3oe7ensi179ocks7je5hh49cun.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: androidClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        _snack('Google Sign-In failed', color: _danger);
        setState(() => _loading = false);
        return;
      }

      final res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (res.user != null) await _navigateAfterAuth(res.user!.id);
    } catch (e) {
      _snack('Google Sign-In failed: $e', color: _danger);
    }

    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? _card),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back ──────────────────────────────────────────────────────
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _txtP,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),

              // ── Logo + Title ───────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _surf,
                        border: Border.all(color: _accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(0.25),
                            blurRadius: 24,
                            spreadRadius: 2,
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
                                color: _accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Welcome Back!' : 'Student Login',
                      style: GoogleFonts.inter(
                        color: _txtP,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'Login to your account'
                          : 'Choose how you want to continue',
                      style: GoogleFonts.inter(color: _txtM, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Google Sign In ─────────────────────────────────────────────
              GestureDetector(
                onTap: _loading ? null : _googleSignIn,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          color: _txtP,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Divider ────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: _border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: GoogleFonts.inter(color: _txtM, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: _border)),
                ],
              ),

              const SizedBox(height: 16),

              // ── Email ──────────────────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                style: TextStyle(color: _txtP),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: _txtM,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Password ───────────────────────────────────────────────────
              TextField(
                controller: _passwordCtrl,
                style: TextStyle(color: _txtP),
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: _txtM, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _txtM,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _emailAuth(),
              ),

              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _emailAuth,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLogin ? 'Login' : 'Create Account'),
                ),
              ),

              const SizedBox(height: 16),

              // ── Toggle login/register ──────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isLogin = !_isLogin),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : 'Already have an account? ',
                          style: TextStyle(color: _txtM),
                        ),
                        TextSpan(
                          text: _isLogin ? 'Sign up' : 'Login',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Email Verify Screen
// ─────────────────────────────────────────────────────────────────────────────
class EmailVerifyScreen extends StatelessWidget {
  final String email;
  const EmailVerifyScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? AppColors.background : AppColorsLight.background;
    final surf = isDark ? AppColors.surface : AppColorsLight.surface;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  color: _accent(isDark),
                  size: 48,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Verify Your Email',
                style: GoogleFonts.inter(
                  color: txtP,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We have sent a verification link to',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: txtM, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your inbox and confirm your email to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: txtM, fontSize: 13),
              ),
              const SizedBox(height: 36),

              // ── Resend ─────────────────────────────────────────────────────
              _ResendButton(email: email, isDark: isDark),

              const SizedBox(height: 16),

              // ── Back to login ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentAuthScreen(),
                    ),
                  ),
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accent(bool isDark) =>
      isDark ? AppColors.accent : AppColorsLight.accent;
}

class _ResendButton extends StatefulWidget {
  final String email;
  final bool isDark;
  const _ResendButton({required this.email, required this.isDark});

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDark ? AppColors.accent : AppColorsLight.accent;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _sending
            ? null
            : () async {
                setState(() => _sending = true);
                try {
                  await Supabase.instance.client.auth.resend(
                    type: OtpType.signup,
                    email: widget.email,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Verification email resent ✓'),
                        backgroundColor: accent,
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to resend email')),
                    );
                  }
                }
                if (mounted) setState(() => _sending = false);
              },
        child: _sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Resend Email'),
      ),
    );
  }
}
