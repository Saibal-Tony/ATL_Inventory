import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _sortNewest = true;

  RealtimeChannel? _channel;

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => _isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => _isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => _isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => _isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => _isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _warn => _isDark ? AppColors.warning : AppColorsLight.warning;
  Color get _txtP =>
      _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => _isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    themeNotifier.addListener(_onThemeChange);
    _channel = _supabase
        .channel('public:requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'requests',
          callback: (_) => _fetchAll(),
        )
        .subscribe();
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final data = await _supabase
          .from('requests')
          .select()
          .order('request_date', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Date helpers ───────────────────────────────────────────────────────────
  String _monthName(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  String _dateLabel(String isoDate) {
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return '-';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  List<dynamic> _grouped() {
    final sorted = [..._requests];
    sorted.sort((a, b) {
      final da = DateTime.tryParse(a['request_date'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['request_date'] ?? '') ?? DateTime(2000);
      return _sortNewest ? db.compareTo(da) : da.compareTo(db);
    });

    final List<dynamic> result = [];
    String? lastLabel;
    for (final r in sorted) {
      final label = _dateLabel(r['request_date'] ?? '');
      if (label != lastLabel) {
        result.add(label);
        lastLabel = label;
      }
      result.add(r);
    }
    return result;
  }

  // ── Approve ────────────────────────────────────────────────────────────────
  void _approveRequest(Map<String, dynamic> req) {
    final items = List<Map<String, dynamic>>.from(req['items'] as List);

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
                  color: _accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: _accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Approve Request?',
                style: GoogleFonts.inter(
                  color: _txtP,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${req['student_name']} will receive ${items.length} component type${items.length > 1 ? 's' : ''}.\nInventory will be updated.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _txtM, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Show items summary
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _accent, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['part_name'],
                          style: GoogleFonts.inter(color: _txtP, fontSize: 12),
                        ),
                      ),
                      Text(
                        'x${item['qty_requested']}',
                        style: GoogleFonts.inter(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                        Navigator.pop(dCtx);
                        await _doApprove(req);
                      },
                      child: const Text('Approve All'),
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

  Future<void> _doApprove(Map<String, dynamic> req) async {
    try {
      final items = List<Map<String, dynamic>>.from(req['items'] as List);

      // Check availability for all items first
      for (final item in items) {
        final part = await _supabase
            .from('parts')
            .select('availability, part_name')
            .eq('id', item['part_id'])
            .single();
        final avail = (part['availability'] as num).toInt();
        final qty = item['qty_requested'] as int;
        if (qty > avail) {
          _snack(
            'Not enough stock for ${item['part_name']} — only $avail available',
            color: _danger,
          );
          return;
        }
      }

      // Update request status
      await _supabase
          .from('requests')
          .update({'status': 'approved'})
          .eq('id', req['id']);

      // Reduce inventory and build borrow items
      final borrowItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final part = await _supabase
            .from('parts')
            .select('availability')
            .eq('id', item['part_id'])
            .single();
        final avail = (part['availability'] as num).toInt();
        final qty = item['qty_requested'] as int;

        await _supabase
            .from('parts')
            .update({'availability': avail - qty})
            .eq('id', item['part_id']);

        borrowItems.add({
          'part_id': item['part_id'],
          'part_name': item['part_name'],
          'image_url': item['image_url'] ?? '',
          'qty_issued': qty,
          'qty_returned': 0,
          'is_returned': false,
        });
      }

      // Create single borrow record with all items
      await _supabase.from('borrows').insert({
        'id': const Uuid().v4(),
        'student_name': req['student_name'],
        'class': req['class'],
        'section': req['section'],
        'roll_no': req['roll_no'],
        'contact_no': req['contact_no'],
        'is_fully_returned': false,
        'items': borrowItems,
      });

      _snack('Request approved ✓', color: _accent);
      _fetchAll();
    } catch (e) {
      _snack('Error approving request', color: _danger);
    }
  }

  // ── Deny ───────────────────────────────────────────────────────────────────
  void _denyRequest(Map<String, dynamic> req) {
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
                child: Icon(Icons.cancel_outlined, color: _danger, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Deny Request?',
                style: GoogleFonts.inter(
                  color: _txtP,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This request from ${req['student_name']} will be rejected.',
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
                            .from('requests')
                            .update({'status': 'denied'})
                            .eq('id', req['id']);
                        _snack('Request denied', color: _danger);
                        _fetchAll();
                      },
                      child: const Text('Deny'),
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

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _deleteRequest(Map<String, dynamic> req) {
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
                'Delete Request?',
                style: GoogleFonts.inter(
                  color: _txtP,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This record will be permanently removed.',
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
                            .from('requests')
                            .delete()
                            .eq('id', req['id']);
                        _fetchAll();
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
    final grouped = _grouped();
    final pendingCount = _requests
        .where((r) => r['status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surf,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _txtP, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Component Requests',
              style: GoogleFonts.inter(
                color: _txtP,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: GoogleFonts.inter(
                    color: _isDark ? AppColors.background : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: _sortNewest ? 'Oldest first' : 'Newest first',
            icon: Icon(
              _sortNewest
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: _txtM,
              size: 20,
            ),
            onPressed: () => setState(() => _sortNewest = !_sortNewest),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            )
          : grouped.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, color: _txtM, size: 52),
                  const SizedBox(height: 14),
                  Text(
                    'No requests yet',
                    style: GoogleFonts.inter(color: _txtM, fontSize: 15),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final item = grouped[i];

                // ── Date separator ────────────────────────────────────
                if (item is String) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: _border)),
                        const SizedBox(width: 10),
                        Text(
                          item,
                          style: GoogleFonts.inter(
                            color: _txtM,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Divider(color: _border)),
                      ],
                    ),
                  );
                }

                // ── Request card ──────────────────────────────────────
                final req = item as Map<String, dynamic>;
                final status = req['status'] as String;
                final isPending = status == 'pending';
                final isApproved = status == 'approved';
                final items = List<Map<String, dynamic>>.from(
                  req['items'] as List,
                );

                final statusColor = isPending
                    ? _warn
                    : isApproved
                    ? _accent
                    : _danger;
                final statusLabel = isPending
                    ? 'Pending'
                    : isApproved
                    ? 'Approved'
                    : 'Denied';
                final statusIcon = isPending
                    ? Icons.hourglass_empty_rounded
                    : isApproved
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined;

                final reqDate = DateTime.tryParse(
                  req['request_date'] ?? '',
                )?.toLocal();
                final timeStr = reqDate != null
                    ? '${reqDate.hour.toString().padLeft(2, '0')}:${reqDate.minute.toString().padLeft(2, '0')}'
                    : '';

                return GestureDetector(
                  onLongPress: !isPending ? () => _deleteRequest(req) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPending
                            ? statusColor.withOpacity(0.4)
                            : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Student info ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (req['student_name'] as String)[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req['student_name'],
                                      style: GoogleFonts.inter(
                                        color: _txtP,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        _chip(
                                          Icons.class_outlined,
                                          'Class ${req['class']}-${req['section']}',
                                        ),
                                        _chip(
                                          Icons.numbers_outlined,
                                          'Roll ${req['roll_no']}',
                                        ),
                                        _chip(
                                          Icons.phone_outlined,
                                          req['contact_no'],
                                        ),
                                        if (timeStr.isNotEmpty)
                                          _chip(
                                            Icons.access_time_rounded,
                                            timeStr,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      color: statusColor,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      statusLabel,
                                      style: GoogleFonts.inter(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(color: _border, height: 1),

                        // ── Components list ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                          child: Text(
                            'REQUESTED COMPONENTS',
                            style: TextStyle(
                              color: _txtM,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: items.map((item) {
                              final imgUrl = item['image_url'] as String? ?? '';
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _surf,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: imgUrl.isNotEmpty
                                              ? Image.network(
                                                  imgUrl,
                                                  width: 36,
                                                  height: 36,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _imgPlaceholder(),
                                                )
                                              : _imgPlaceholder(),
                                        ),
                                        Positioned(
                                          bottom: -4,
                                          left: -4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'x${item['qty_requested']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      item['part_name'],
                                      style: GoogleFonts.inter(
                                        color: _txtP,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── Approve / Deny buttons ────────────────────
                        if (isPending)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: _danger,
                                    ),
                                    label: Text(
                                      'Deny',
                                      style: TextStyle(color: _danger),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _danger.withOpacity(0.5),
                                      ),
                                    ),
                                    onPressed: () => _denyRequest(req),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                    ),
                                    label: const Text('Approve All'),
                                    onPressed: () => _approveRequest(req),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (!isPending)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: Text(
                              isApproved
                                  ? 'Approved — added to borrow records'
                                  : 'Denied — long press to delete',
                              style: GoogleFonts.inter(
                                color: _txtM,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _txtM, size: 11),
      const SizedBox(width: 3),
      Text(label, style: GoogleFonts.inter(color: _txtM, fontSize: 11)),
    ],
  );

  Widget _imgPlaceholder() => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: _border,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(Icons.memory_outlined, color: _txtM, size: 18),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Student Request Dialog
// ─────────────────────────────────────────────────────────────────────────────
class StudentRequestDialog {
  static void show(
    BuildContext context,
    List<Map<String, dynamic>> parts,
    bool isDark,
  ) {
    final _supabase = Supabase.instance.client;
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    Map<String, dynamic>? selectedPart;
    final List<Map<String, dynamic>> cart = [];
    bool saving = false;

    final surf = isDark ? AppColors.surface : AppColorsLight.surface;
    final card = isDark ? AppColors.card : AppColorsLight.card;
    final accent = isDark ? AppColors.accent : AppColorsLight.accent;
    final danger = isDark ? AppColors.danger : AppColorsLight.danger;
    final txtP = isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
    final txtM = isDark ? AppColors.textMuted : AppColorsLight.textMuted;
    final border = isDark ? AppColors.border : AppColorsLight.border;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
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
                        Icons.edit_note_outlined,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Components',
                          style: GoogleFonts.inter(
                            color: txtP,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Admin will approve your request',
                          style: GoogleFonts.inter(color: txtM, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Component picker ────────────────────────────────────
                Text(
                  'ADD COMPONENTS',
                  style: GoogleFonts.inter(
                    color: txtM,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: selectedPart,
                      dropdownColor: surf,
                      isExpanded: true,
                      hint: Text(
                        'Select component',
                        style: GoogleFonts.inter(color: txtM, fontSize: 13),
                      ),
                      items: parts.map((p) {
                        final avail = (p['availability'] as num?)?.toInt() ?? 0;
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p['part_name']} ($avail available)',
                            style: GoogleFonts.inter(
                              color: avail > 0 ? txtP : danger,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setD(() => selectedPart = v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        style: TextStyle(color: txtP, fontSize: 13),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Qty',
                          labelStyle: TextStyle(color: txtM, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      onPressed: () {
                        if (selectedPart == null) {
                          _showSnack(context, 'Select a component', danger);
                          return;
                        }
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          _showSnack(context, 'Enter valid qty', danger);
                          return;
                        }
                        final avail =
                            (selectedPart!['availability'] as num?)?.toInt() ??
                            0;
                        if (qty > avail) {
                          _showSnack(context, 'Only $avail available', danger);
                          return;
                        }
                        final existing = cart.indexWhere(
                          (c) => c['part_id'] == selectedPart!['id'],
                        );
                        if (existing >= 0) {
                          final totalQty =
                              (cart[existing]['qty_requested'] as int) + qty;
                          if (totalQty > avail) {
                            _showSnack(
                              context,
                              'Only $avail available total',
                              danger,
                            );
                            return;
                          }
                          setD(
                            () => cart[existing]['qty_requested'] = totalQty,
                          );
                        } else {
                          setD(
                            () => cart.add({
                              'part_id': selectedPart!['id'],
                              'part_name': selectedPart!['part_name'],
                              'image_url': selectedPart!['image_url'] ?? '',
                              'qty_requested': qty,
                            }),
                          );
                        }
                        setD(() {
                          selectedPart = null;
                          qtyCtrl.text = '1';
                        });
                      },
                    ),
                  ],
                ),

                // ── Cart ────────────────────────────────────────────────
                if (cart.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'CART (${cart.length})',
                    style: GoogleFonts.inter(
                      color: txtM,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...cart.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['part_name'],
                              style: GoogleFonts.inter(
                                color: txtP,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'x${item['qty_requested']}',
                            style: GoogleFonts.inter(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setD(() => cart.remove(item)),
                            child: Icon(Icons.close, color: danger, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── Student details ─────────────────────────────────────
                Text(
                  'YOUR DETAILS',
                  style: GoogleFonts.inter(
                    color: txtM,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: txtP, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(color: txtM, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: classCtrl,
                        style: TextStyle(color: txtP, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Class',
                          labelStyle: TextStyle(color: txtM, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: sectionCtrl,
                        style: TextStyle(color: txtP, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Section',
                          labelStyle: TextStyle(color: txtM, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rollCtrl,
                        style: TextStyle(color: txtP, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Roll No',
                          labelStyle: TextStyle(color: txtM, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: contactCtrl,
                        style: TextStyle(color: txtP, fontSize: 13),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Contact No',
                          labelStyle: TextStyle(color: txtM, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Submit ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => Navigator.pop(dCtx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (cart.isEmpty) {
                                  _showSnack(
                                    context,
                                    'Add at least one component',
                                    danger,
                                  );
                                  return;
                                }
                                if (nameCtrl.text.trim().isEmpty) {
                                  _showSnack(
                                    context,
                                    'Enter your name',
                                    danger,
                                  );
                                  return;
                                }
                                if (classCtrl.text.trim().isEmpty) {
                                  _showSnack(context, 'Enter class', danger);
                                  return;
                                }
                                if (sectionCtrl.text.trim().isEmpty) {
                                  _showSnack(context, 'Enter section', danger);
                                  return;
                                }
                                if (rollCtrl.text.trim().isEmpty) {
                                  _showSnack(context, 'Enter roll no', danger);
                                  return;
                                }
                                if (contactCtrl.text.trim().isEmpty) {
                                  _showSnack(
                                    context,
                                    'Enter contact no',
                                    danger,
                                  );
                                  return;
                                }

                                setD(() => saving = true);

                                // Insert ONE request with all items as JSON
                                await _supabase.from('requests').insert({
                                  'id': const Uuid().v4(),
                                  'student_name': nameCtrl.text.trim(),
                                  'class': classCtrl.text.trim(),
                                  'section': sectionCtrl.text.trim(),
                                  'roll_no': rollCtrl.text.trim(),
                                  'contact_no': contactCtrl.text.trim(),
                                  'items': cart,
                                  'status': 'pending',
                                });

                                if (!dCtx.mounted) return;
                                Navigator.pop(dCtx);
                                _showSnack(
                                  context,
                                  'Request sent! Admin will review it ✓',
                                  accent,
                                );
                              },
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send Request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
