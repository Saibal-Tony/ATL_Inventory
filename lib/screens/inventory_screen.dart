import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'add_part_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import 'borrow_screen.dart';

class InventoryScreen extends StatefulWidget {
  final bool isAdmin;
  const InventoryScreen({super.key, required this.isAdmin});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _categories = ['All'];
  String _selectedCat = 'All';
  String _searchQuery = '';
  bool _loading = true;
  bool _isAdmin = false;

  RealtimeChannel? _channel;
  final _searchCtrl = TextEditingController();

  // ── Helpers ────────────────────────────────────────────────────────────────
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _isAdmin = widget.isAdmin;
    _setupRealtime();
    themeNotifier.addListener(_onThemeChange);
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _channel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Real-time ──────────────────────────────────────────────────────────────
  void _setupRealtime() {
    _fetchAll();
    _channel = _supabase
        .channel('public:parts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parts',
          callback: (_) => _fetchAll(),
        )
        .subscribe();
  }

  Future<void> _fetchAll() async {
    try {
      final data = await _supabase
          .from('parts')
          .select()
          .order('part_name', ascending: true);
      if (!mounted) return;
      setState(() {
        _all = List<Map<String, dynamic>>.from(data);
        _rebuildCategories();
        _applyFilters();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getPassword() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', 'admin_password')
          .single();
      return data['value'] as String? ?? 'aTal@2026';
    } catch (_) {
      return 'aTal@2026';
    }
  }

  void _rebuildCategories() {
    final cats =
        _all
            .map((p) => (p['category'] as String? ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    _categories = ['All', ...cats];
    if (!_categories.contains(_selectedCat)) _selectedCat = 'All';
  }

  void _applyFilters() {
    var list = _all;
    if (_selectedCat != 'All') {
      list = list
          .where((p) => (p['category'] as String? ?? '').trim() == _selectedCat)
          .toList();
    }
    final q = _searchQuery.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                (p['part_name'] ?? '').toString().toLowerCase().contains(q) ||
                (p['serial_no'] ?? '').toString().toLowerCase().contains(q) ||
                (p['category'] ?? '').toString().toLowerCase().contains(q) ||
                (p['box_no'] ?? '').toString().contains(q),
          )
          .toList();
    }
    _filtered = list;
  }

  // ── Admin toggle ───────────────────────────────────────────────────────────
  void _toggleAdmin() {
    if (_isAdmin) {
      setState(() => _isAdmin = false);
      _snack('Admin mode off');
      return;
    }
    final ctrl = TextEditingController();
    bool obs = true;
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: _surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin Mode',
                  style: GoogleFonts.inter(
                    color: _txtP,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  obscureText: obs,
                  autofocus: true,
                  style: TextStyle(color: _txtP),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obs
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _txtM,
                        size: 18,
                      ),
                      onPressed: () => setD(() => obs = !obs),
                    ),
                  ),
                  onSubmitted: (_) => _submitAdminPw(dCtx, ctrl.text),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitAdminPw(dCtx, ctrl.text),
                    child: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitAdminPw(BuildContext dCtx, String pw) async {
    Navigator.pop(dCtx);
    final currentPw = await _getPassword();
    if (pw == currentPw) {
      setState(() => _isAdmin = true);
      _snack('Admin mode on ✓', color: _accent);
    } else {
      _snack('Wrong password', color: _danger);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _confirmDelete(Map<String, dynamic> part) {
    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: _surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: _danger, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Component?',
                style: GoogleFonts.inter(
                  color: _txtP,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${part['part_name']}" will be removed permanently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _txtM, fontSize: 13),
              ),
              const SizedBox(height: 24),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(dCtx);
                        await _supabase
                            .from('parts')
                            .delete()
                            .eq('id', part['id']);
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: _txtP)),
        backgroundColor: color ?? _card,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSearch(),
            const SizedBox(height: 6),
            _buildCategoryChips(),
            const SizedBox(height: 4),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: _accent,
              foregroundColor: _isDark ? AppColors.background : Colors.white,
              tooltip: 'Add component',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPartScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _surf,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.18),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'lib/assets/logo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _card,
                  child: Center(
                    child: Text(
                      'ATL',
                      style: GoogleFonts.inter(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── App name + count ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "ATL" on first line, "Inventory" on second — both bold
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      color: _txtP,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                    children: const [
                      TextSpan(text: 'ATL\n'),
                      TextSpan(text: 'Inventory'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_filtered.length} component${_filtered.length != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(color: _txtM, fontSize: 10.5),
                ),
              ],
            ),
          ),

          // ── Admin badge ─────────────────────────────────────────────────
          if (_isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: _accent, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    'Admin',
                    style: GoogleFonts.inter(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Theme toggle ────────────────────────────────────────────────
          IconButton(
            icon: Icon(
              _isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
              color: _txtM,
              size: 19,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => themeNotifier.value = _isDark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),

          // ── QR scanner ──────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.qr_code_scanner_outlined, color: _txtM, size: 19),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRScannerScreen(
                  onScan: (v) {
                    setState(() {
                      _searchQuery = v;
                      _searchCtrl.text = v;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
          ),

          // ── Admin lock ──────────────────────────────────────────────────
          IconButton(
            icon: Icon(
              _isAdmin ? Icons.lock_open_outlined : Icons.lock_outline,
              color: _isAdmin ? _accent : _txtM,
              size: 19,
            ),
            onPressed: _toggleAdmin,
          ),

          // ── Borrow records (admin only) ────────────────────────────────
          if (_isAdmin)
            IconButton(
              icon: Icon(Icons.assignment_outlined, color: _txtM, size: 19),
              tooltip: 'Borrow records',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BorrowScreen()),
              ),
            ),
          // ── Logout ──────────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.logout_outlined, color: _txtM, size: 19),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: _txtP, fontSize: 14),
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _applyFilters();
        }),
        decoration: InputDecoration(
          hintText: 'Search by name, category, box no…',
          hintStyle: TextStyle(color: _txtM, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _txtM, size: 19),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: _txtM, size: 17),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchCtrl.clear();
                    _applyFilters();
                  }),
                )
              : null,
        ),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final sel = cat == _selectedCat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedCat = cat;
                _applyFilters();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel ? _accent : _surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _accent : _border),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: sel
                        ? (_isDark ? AppColors.background : Colors.white)
                        : _txtM,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, color: _txtM, size: 52),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No components yet',
              style: GoogleFonts.inter(color: _txtM, fontSize: 15),
            ),
            if (_isAdmin && _searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to add your first component',
                style: GoogleFonts.inter(color: _txtM, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _PartCard(
        part: _filtered[i],
        isAdmin: _isAdmin,
        isDark: _isDark,
        onEdit: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddPartScreen(part: _filtered[i])),
        ),
        onDelete: () => _confirmDelete(_filtered[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Part Card — compact, no wasted space
// ─────────────────────────────────────────────────────────────────────────────
class _PartCard extends StatelessWidget {
  final Map<String, dynamic> part;
  final bool isAdmin;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PartCard({
    required this.part,
    required this.isAdmin,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;

  @override
  Widget build(BuildContext context) {
    final total = (part['total_parts'] as num?)?.toInt() ?? 0;
    final avail = (part['availability'] as num?)?.toInt() ?? 0;
    final ratio = total > 0 ? (avail / total).clamp(0.0, 1.0) : 0.0;

    final Color statusColor = ratio > 0.5
        ? _accent
        : ratio > 0.2
        ? (isDark ? AppColors.warning : AppColorsLight.warning)
        : _danger;

    final imageUrl = part['image_url'] as String?;

    return GestureDetector(
      onTap: isAdmin ? onEdit : null,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                // condition dot top-right
                if ((part['condition'] as String?) != null &&
                    part['condition'] != 'Good')
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: part['condition'] == 'Damaged'
                            ? _danger.withOpacity(0.85)
                            : const Color(0xFFFFB300).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        part['condition'],
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info section — fills remaining space ──────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name + category + box
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part['part_name'] ?? 'Unnamed',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _txtP,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if ((part['category'] as String? ?? '')
                                .isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  part['category'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: _accent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              'Box ${part['box_no'] ?? '-'}',
                              style: GoogleFonts.inter(
                                color: _txtM,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Availability row — always at bottom
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _ArcPainter(ratio, statusColor, _border),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$avail / $total',
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'available',
                                style: GoogleFonts.inter(
                                  color: _txtM,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isAdmin) ...[
                          _miniBtn(
                            icon: Icons.edit_outlined,
                            color: _accent,
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 4),
                          _miniBtn(
                            icon: Icons.delete_outline,
                            color: _danger,
                            onTap: onDelete,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: _surf,
    child: Center(child: Icon(Icons.memory_outlined, color: _txtM, size: 32)),
  );

  Widget _miniBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Arc painter — passes border color explicitly, handles ratio=1.0
// ─────────────────────────────────────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final Color bgColor;
  const _ArcPainter(this.ratio, this.color, this.bgColor);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2.5;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi,
      false,
      bgPaint,
    );

    if (ratio > 0) {
      // cap at 0.999 to avoid full-circle rendering glitch
      final sweep = 2 * math.pi * ratio.clamp(0.0, 0.999);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        sweep,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.ratio != ratio || old.color != color;
}
