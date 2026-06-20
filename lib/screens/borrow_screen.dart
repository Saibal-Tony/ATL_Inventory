import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../services/pdf_export_service.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _borrows = [];
  List<Map<String, dynamic>> _parts = [];
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
  Color get _txtP =>
      _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => _isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    themeNotifier.addListener(_onThemeChange);
    _channel = _supabase
        .channel('public:borrows')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'borrows',
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
      final borrows = await _supabase
          .from('borrows')
          .select()
          .order('issue_date', ascending: false);
      final parts = await _supabase
          .from('parts')
          .select()
          .order('part_name', ascending: true);
      if (!mounted) return;
      setState(() {
        _borrows = List<Map<String, dynamic>>.from(borrows);
        _parts = List<Map<String, dynamic>>.from(parts);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Date label ─────────────────────────────────────────────────────────────
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

  // ── Build grouped list ─────────────────────────────────────────────────────
  List<dynamic> _grouped() {
    final sorted = [..._borrows];
    sorted.sort((a, b) {
      final da = DateTime.tryParse(a['issue_date'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['issue_date'] ?? '') ?? DateTime(2000);
      return _sortNewest ? db.compareTo(da) : da.compareTo(db);
    });

    final List<dynamic> result = [];
    String? lastLabel;
    for (final b in sorted) {
      final label = _dateLabel(b['issue_date'] ?? '');
      if (label != lastLabel) {
        result.add(label); // date separator
        lastLabel = label;
      }
      result.add(b);
    }
    return result;
  }

  // ── Issue dialog ───────────────────────────────────────────────────────────
  void _showIssueDialog() {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    // Cart
    final List<Map<String, dynamic>> cart = [];
    Map<String, dynamic>? selectedPart;
    final qtyCtrl = TextEditingController(text: '1');
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: _surf,
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
                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Issue Components',
                      style: GoogleFonts.inter(
                        color: _txtP,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Student details ─────────────────────────────────────
                _sectionLabel('STUDENT DETAILS'),
                const SizedBox(height: 8),
                _field(nameCtrl, 'Student Name'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field(classCtrl, 'Class')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(sectionCtrl, 'Section')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field(rollCtrl, 'Roll No')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        contactCtrl,
                        'Contact No',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Add to cart ─────────────────────────────────────────
                _sectionLabel('ADD COMPONENTS'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: selectedPart,
                      dropdownColor: _surf,
                      isExpanded: true,
                      hint: Text(
                        'Select component',
                        style: GoogleFonts.inter(color: _txtM, fontSize: 13),
                      ),
                      items: _parts.map((p) {
                        final avail = (p['availability'] as num?)?.toInt() ?? 0;
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p['part_name']} ($avail available)',
                            style: GoogleFonts.inter(
                              color: avail > 0 ? _txtP : _danger,
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
                      child: _field(
                        qtyCtrl,
                        'Qty',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      onPressed: () {
                        if (selectedPart == null) {
                          _snack('Select a component', color: _danger);
                          return;
                        }
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          _snack('Enter valid qty', color: _danger);
                          return;
                        }
                        final avail =
                            (selectedPart!['availability'] as num?)?.toInt() ??
                            0;
                        if (qty > avail) {
                          _snack('Only $avail available', color: _danger);
                          return;
                        }
                        // Check if already in cart
                        final existing = cart.indexWhere(
                          (c) => c['part_id'] == selectedPart!['id'],
                        );
                        if (existing >= 0) {
                          final totalQty =
                              (cart[existing]['qty_issued'] as int) + qty;
                          if (totalQty > avail) {
                            _snack(
                              'Only $avail available total',
                              color: _danger,
                            );
                            return;
                          }
                          setD(() => cart[existing]['qty_issued'] = totalQty);
                        } else {
                          setD(
                            () => cart.add({
                              'part_id': selectedPart!['id'],
                              'part_name': selectedPart!['part_name'],
                              'image_url': selectedPart!['image_url'] ?? '',
                              'qty_issued': qty,
                              'qty_returned': 0,
                              'is_returned': false,
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

                // ── Cart items ──────────────────────────────────────────
                if (cart.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _sectionLabel('CART (${cart.length})'),
                  const SizedBox(height: 8),
                  ...cart.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['part_name'],
                              style: GoogleFonts.inter(
                                color: _txtP,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'x${item['qty_issued']}',
                            style: GoogleFonts.inter(
                              color: _accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setD(() => cart.remove(item)),
                            child: Icon(Icons.close, color: _danger, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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
                                if (nameCtrl.text.trim().isEmpty) {
                                  _snack('Enter student name', color: _danger);
                                  return;
                                }
                                if (classCtrl.text.trim().isEmpty) {
                                  _snack('Enter class', color: _danger);
                                  return;
                                }
                                if (sectionCtrl.text.trim().isEmpty) {
                                  _snack('Enter section', color: _danger);
                                  return;
                                }
                                if (rollCtrl.text.trim().isEmpty) {
                                  _snack('Enter roll no', color: _danger);
                                  return;
                                }
                                if (contactCtrl.text.trim().isEmpty) {
                                  _snack('Enter contact no', color: _danger);
                                  return;
                                }
                                if (cart.isEmpty) {
                                  _snack(
                                    'Add at least one component',
                                    color: _danger,
                                  );
                                  return;
                                }

                                setD(() => saving = true);

                                // Insert borrow record
                                await _supabase.from('borrows').insert({
                                  'id': const Uuid().v4(),
                                  'student_name': nameCtrl.text.trim(),
                                  'class': classCtrl.text.trim(),
                                  'section': sectionCtrl.text.trim(),
                                  'roll_no': rollCtrl.text.trim(),
                                  'contact_no': contactCtrl.text.trim(),
                                  'is_fully_returned': false,
                                  'items': cart,
                                });

                                // Reduce availability for each part
                                for (final item in cart) {
                                  final part = _parts.firstWhere(
                                    (p) => p['id'] == item['part_id'],
                                    orElse: () => {},
                                  );
                                  if (part.isNotEmpty) {
                                    final avail = (part['availability'] as num)
                                        .toInt();
                                    await _supabase
                                        .from('parts')
                                        .update({
                                          'availability':
                                              avail -
                                              (item['qty_issued'] as int),
                                        })
                                        .eq('id', item['part_id']);
                                  }
                                }

                                if (!dCtx.mounted) return;
                                Navigator.pop(dCtx);
                                _snack('Components issued ✓', color: _accent);
                                _fetchAll();
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
                            : const Text('Issue'),
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

  // ── Return dialog ──────────────────────────────────────────────────────────
  void _showReturnDialog(Map<String, dynamic> borrow) {
    final items = List<Map<String, dynamic>>.from(
      (borrow['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    final controllers = {
      for (var item in items)
        item['part_id'] as String: TextEditingController(
          text: ((item['qty_issued'] as int) - (item['qty_returned'] as int))
              .toString(),
        ),
    };
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: _surf,
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_return_outlined,
                        color: _accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Components',
                          style: GoogleFonts.inter(
                            color: _txtP,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          borrow['student_name'],
                          style: GoogleFonts.inter(color: _txtM, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                ...items.map((item) {
                  final issued = item['qty_issued'] as int;
                  final returned = item['qty_returned'] as int;
                  final pending = issued - returned;
                  final isReturned = item['is_returned'] as bool;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isReturned ? _accent.withOpacity(0.3) : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['part_name'],
                                style: GoogleFonts.inter(
                                  color: _txtP,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isReturned)
                              Icon(Icons.check_circle, color: _accent, size: 16)
                            else
                              Text(
                                '$pending pending',
                                style: GoogleFonts.inter(
                                  color: _danger,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        if (!isReturned) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controllers[item['part_id']],
                                  style: TextStyle(color: _txtP, fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Returning (max $pending)',
                                    labelStyle: TextStyle(
                                      color: _txtM,
                                      fontSize: 11,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
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
                                setD(() => saving = true);

                                final updatedItems =
                                    List<Map<String, dynamic>>.from(items);

                                for (int i = 0; i < updatedItems.length; i++) {
                                  final item = updatedItems[i];
                                  if (item['is_returned'] as bool) continue;

                                  final issued = item['qty_issued'] as int;
                                  final alreadyReturned =
                                      item['qty_returned'] as int;
                                  final pending = issued - alreadyReturned;
                                  final ctrl = controllers[item['part_id']];
                                  final qty =
                                      int.tryParse(ctrl?.text.trim() ?? '0') ??
                                      0;
                                  if (qty <= 0) continue;
                                  final actualQty = qty > pending
                                      ? pending
                                      : qty;

                                  final newReturned =
                                      alreadyReturned + actualQty;
                                  updatedItems[i] = {
                                    ...item,
                                    'qty_returned': newReturned,
                                    'is_returned': newReturned >= issued,
                                  };

                                  // Update part availability
                                  final part = _parts.firstWhere(
                                    (p) => p['id'] == item['part_id'],
                                    orElse: () => {},
                                  );
                                  if (part.isNotEmpty) {
                                    final avail = (part['availability'] as num)
                                        .toInt();
                                    await _supabase
                                        .from('parts')
                                        .update({
                                          'availability': avail + actualQty,
                                        })
                                        .eq('id', item['part_id']);
                                  }
                                }

                                final allReturned = updatedItems.every(
                                  (i) => i['is_returned'] as bool,
                                );

                                await _supabase
                                    .from('borrows')
                                    .update({
                                      'items': updatedItems,
                                      'is_fully_returned': allReturned,
                                    })
                                    .eq('id', borrow['id']);

                                if (!dCtx.mounted) return;
                                Navigator.pop(dCtx);
                                _snack('Return recorded ✓', color: _accent);
                                _fetchAll();
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
                            : const Text('Confirm Return'),
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

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _confirmDelete(Map<String, dynamic> borrow) {
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
                'Delete Record?',
                style: GoogleFonts.inter(
                  color: _txtP,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Record for "${borrow['student_name']}" will be removed.',
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
                            .from('borrows')
                            .delete()
                            .eq('id', borrow['id']);
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

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: _txtM,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: _txtP, fontSize: 13),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _txtM, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surf,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _txtP, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Borrow Records',
          style: GoogleFonts.inter(
            color: _txtP,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
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
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: _txtM, size: 20),
            tooltip: 'Export PDF',
            onPressed: () => PdfExportService.exportBorrows(context, _borrows),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: _isDark ? AppColors.background : Colors.white,
        icon: const Icon(Icons.assignment_add),
        label: Text(
          'Issue',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        onPressed: _showIssueDialog,
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
                  Icon(Icons.assignment_outlined, color: _txtM, size: 52),
                  const SizedBox(height: 14),
                  Text(
                    'No borrow records yet',
                    style: GoogleFonts.inter(color: _txtM, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap Issue to add one',
                    style: GoogleFonts.inter(color: _txtM, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final item = grouped[i];

                // ── Date separator ──────────────────────────────────
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

                // ── Borrow card ─────────────────────────────────────
                final borrow = item as Map<String, dynamic>;
                final isFullyReturned = borrow['is_fully_returned'] as bool;

                return GestureDetector(
                  onLongPress: isFullyReturned
                      ? () => _confirmDelete(borrow)
                      : null,
                  child: _BorrowCard(
                    borrow: borrow,
                    isDark: _isDark,
                    parts: _parts,
                    onReturn: () => _showReturnDialog(borrow),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Borrow Card
// ─────────────────────────────────────────────────────────────────────────────
class _BorrowCard extends StatelessWidget {
  final Map<String, dynamic> borrow;
  final bool isDark;
  final List<Map<String, dynamic>> parts;
  final VoidCallback onReturn;

  const _BorrowCard({
    required this.borrow,
    required this.isDark,
    required this.parts,
    required this.onReturn,
  });

  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;
  Color get _warn => isDark ? AppColors.warning : AppColorsLight.warning;

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(borrow['items'] as List);
    final isFullyReturned = borrow['is_fully_returned'] as bool;
    final statusColor = isFullyReturned ? _accent : _danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyReturned ? _accent.withOpacity(0.3) : _border,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Student info header ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (borrow['student_name'] as String).isNotEmpty
                          ? (borrow['student_name'] as String)[0].toUpperCase()
                          : '?',
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
                        borrow['student_name'],
                        style: TextStyle(
                          color: _txtP,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        children: [
                          _tag('Class ${borrow['class']}-${borrow['section']}'),
                          _tag('Roll ${borrow['roll_no']}'),
                          _tag(borrow['contact_no']),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFullyReturned
                            ? Icons.check_circle_outline
                            : Icons.pending_outlined,
                        color: statusColor,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isFullyReturned ? 'Returned' : 'Pending',
                        style: TextStyle(
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

          // ── Components ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'COMPONENTS',
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
                final issued = item['qty_issued'] as int;
                final returned = item['qty_returned'] as int;
                final isItemReturned = item['is_returned'] as bool;
                final imgUrl = item['image_url'] as String? ?? '';
                final itemColor = isItemReturned ? _accent : _danger;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _surf,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: itemColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Component image with qty badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
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
                          // Qty badge bottom-left
                          Positioned(
                            bottom: -4,
                            left: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: itemColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'x$issued',
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['part_name'],
                            style: TextStyle(
                              color: _txtP,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isItemReturned
                                ? 'Returned'
                                : '$returned/$issued returned',
                            style: TextStyle(color: itemColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Return button (if not fully returned) ─────────────────────
          if (!isFullyReturned)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.assignment_return_outlined,
                    size: 15,
                    color: _accent,
                  ),
                  label: Text(
                    'Return Components',
                    style: TextStyle(color: _accent, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _accent.withOpacity(0.5)),
                  ),
                  onPressed: onReturn,
                ),
              ),
            ),

          if (isFullyReturned)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                'Long press to delete this record',
                style: TextStyle(color: _txtM, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 36,
    height: 36,
    color: _border,
    child: Icon(Icons.memory_outlined, color: _txtM, size: 18),
  );

  Widget _tag(String text) =>
      Text(text, style: TextStyle(color: _txtM, fontSize: 11));
}
