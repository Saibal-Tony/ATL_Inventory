import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry screen — Camera or Generator
// ─────────────────────────────────────────────────────────────────────────────
class QRScannerScreen extends StatelessWidget {
  final void Function(String) onScan;
  const QRScannerScreen({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? AppColors.background : AppColorsLight.background;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Glow blob ─────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.12),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Back button ───────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: txtP,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Bracket + title ───────────────────────────────────────
                _QRBracket(accent: accent),
                const SizedBox(height: 28),
                Text(
                  'QR',
                  style: GoogleFonts.inter(
                    color: txtP,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),

                const Spacer(flex: 3),

                // ── Two mode cards ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          icon: Icons.camera_alt_outlined,
                          label: 'Camera',
                          accent: accent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _CameraScreen(onScan: onScan),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ModeCard(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Generator',
                          accent: accent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const _GeneratorScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QR bracket corners
// ─────────────────────────────────────────────────────────────────────────────
class _QRBracket extends StatelessWidget {
  final Color accent;
  const _QRBracket({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 80,
      child: CustomPaint(painter: _BracketPainter(accent)),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 20.0;
    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(len, 0), paint);
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mode card
// ─────────────────────────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 38),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: txtP,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Camera scan screen
// ─────────────────────────────────────────────────────────────────────────────
class _CameraScreen extends StatefulWidget {
  final void Function(String) onScan;
  const _CameraScreen({required this.onScan});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: txtP, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan Box QR',
          style: GoogleFonts.inter(color: txtP, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (BarcodeCapture capture) {
              if (_scanned) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null) {
                _scanned = true;
                Navigator.pop(context);
                Navigator.pop(context);
                widget.onScan(code);
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Point at a box QR code',
                style: GoogleFonts.inter(
                  color: txtM,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Generator screen
// ─────────────────────────────────────────────────────────────────────────────
class _GeneratorScreen extends StatefulWidget {
  const _GeneratorScreen();

  @override
  State<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<_GeneratorScreen> {
  final _ctrl = TextEditingController();
  final _qrKey = GlobalKey();
  String _qrData = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveQR(Color accent) async {
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_$_qrData.png');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('QR saved to gallery ✓'),
            backgroundColor: accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save QR')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? AppColors.background : AppColorsLight.background;
    final card = isDark ? AppColors.card : AppColorsLight.card;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;
    final border = isDark ? AppColors.border : AppColorsLight.border;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surface : AppColorsLight.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: txtP, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Generate QR',
          style: GoogleFonts.inter(color: txtP, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            // ── Input ─────────────────────────────────────────────────────
            TextField(
              controller: _ctrl,
              style: TextStyle(color: txtP),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Box number or label',
                hintText: 'e.g. 1, Box A, Arduino Box',
                prefixIcon: Icon(
                  Icons.inventory_2_outlined,
                  color: txtM,
                  size: 18,
                ),
              ),
              onChanged: (v) => setState(() => _qrData = v.trim()),
            ),

            const SizedBox(height: 32),

            if (_qrData.isNotEmpty) ...[
              // ── QR code ─────────────────────────────────────────────────
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Box: $_qrData',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save or print this QR and stick it on the box',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: txtM, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // ── Buttons ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy label'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied "$_qrData" to clipboard',
                              style: GoogleFonts.inter(color: txtP),
                            ),
                            backgroundColor: card,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Save QR'),
                      onPressed: () => _saveQR(accent),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── Placeholder ───────────────────────────────────────────────
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: txtM, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'Enter a box number above',
                      style: GoogleFonts.inter(color: txtM, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
