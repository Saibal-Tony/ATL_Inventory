import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'add_part_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';

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

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _isAdmin = widget.isAdmin;
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Real-time subscription — fires for INSERT / UPDATE / DELETE ───────────
  void _setupRealtime() {
    _fetchAll(); // initial load

    _channel = _supabase
        .channel('public:parts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parts',
          callback: (_) => _fetchAll(), // re-fetch on any change
        )
        .subscribe();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
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
      _snack('Admin mode off', color: AppColors.textMuted);
      return;
    }

    final ctrl = TextEditingController();
    bool obs = true;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Mode',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  obscureText: obs,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obs
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () => setD(() => obs = !obs),
                    ),
                  ),
                  onSubmitted: (_) => _submitAdminPassword(dCtx, ctrl.text),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitAdminPassword(dCtx, ctrl.text),
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

  void _submitAdminPassword(BuildContext dCtx, String pw) {
    Navigator.pop(dCtx);
    if (pw == 'aTal@2026') {
      setState(() => _isAdmin = true);
      _snack('Admin mode on', color: AppColors.accent);
    } else {
      _snack('Wrong password', color: AppColors.danger);
    }
  }

  // ── Delete part ────────────────────────────────────────────────────────────
  void _confirmDelete(Map<String, dynamic> part) {
    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: AppColors.surface,
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
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Component?',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${part['part_name']}" will be removed permanently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
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
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () async {
                        Navigator.pop(dCtx);
                        await _supabase
                            .from('parts')
                            .delete()
                            .eq('id', part['id']);
                        // real-time subscription refreshes the list automatically
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
        content: Text(
          msg,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        backgroundColor: color ?? AppColors.card,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              tooltip: 'Add component',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPartScreen()),
                );
                // real-time subscription refreshes — no manual reload needed
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          // title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATL Inventory',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_filtered.length} component${_filtered.length != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // admin badge
          if (_isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.accent,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // QR scanner
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_outlined,
              color: AppColors.textMuted,
              size: 22,
            ),
            tooltip: 'Scan box QR',
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

          // lock / unlock
          IconButton(
            icon: Icon(
              _isAdmin ? Icons.lock_open_outlined : Icons.lock_outline,
              color: _isAdmin ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
            tooltip: _isAdmin ? 'Exit admin' : 'Admin login',
            onPressed: _toggleAdmin,
          ),

          // logout
          IconButton(
            icon: const Icon(
              Icons.logout_outlined,
              color: AppColors.textMuted,
              size: 22,
            ),
            tooltip: 'Switch role',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _applyFilters();
        }),
        decoration: InputDecoration(
          hintText: 'Search by name, category, box no…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textMuted,
            size: 19,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textMuted,
                    size: 17,
                  ),
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

  // ── Category chip row ──────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  color: sel ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: sel ? AppColors.background : AppColors.textMuted,
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No components yet',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 15,
              ),
            ),
            if (_isAdmin && _searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to add your first component',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _PartCard(
        part: _filtered[i],
        isAdmin: _isAdmin,
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
//  Part card
// ─────────────────────────────────────────────────────────────────────────────
class _PartCard extends StatelessWidget {
  final Map<String, dynamic> part;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PartCard({
    required this.part,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final total = (part['total_parts'] as num?)?.toInt() ?? 0;
    final avail = (part['availability'] as num?)?.toInt() ?? 0;
    final ratio = total > 0 ? (avail / total).clamp(0.0, 1.0) : 0.0;
    final statusColor = ratio > 0.5
        ? AppColors.accent
        : ratio > 0.2
        ? AppColors.warning
        : AppColors.danger;
    final imageUrl = part['image_url'] as String?;
    final boxNo = part['box_no'];

    return GestureDetector(
      onTap: isAdmin ? onEdit : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────────────
            SizedBox(
              height: 108,
              width: double.infinity,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      part['part_name'] ?? 'Unnamed',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),

                    if (boxNo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Box $boxNo',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // ── Availability row ──────────────────────────────────
                    Row(
                      children: [
                        // Arc indicator (the signature element)
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _ArcPainter(ratio, statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$avail',
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'of $total',
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Admin action buttons
                        if (isAdmin) ...[
                          _miniBtn(
                            icon: Icons.edit_outlined,
                            color: AppColors.accent,
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 4),
                          _miniBtn(
                            icon: Icons.delete_outline,
                            color: AppColors.danger,
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

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(
          Icons.memory_outlined,
          color: AppColors.textMuted,
          size: 34,
        ),
      ),
    );
  }

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
//  Arc painter — circular progress ring showing availability ratio
// ─────────────────────────────────────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double ratio;
  final Color color;
  const _ArcPainter(this.ratio, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi,
      false,
      bgPaint,
    );

    // Foreground arc
    if (ratio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.ratio != ratio || old.color != color;
}
