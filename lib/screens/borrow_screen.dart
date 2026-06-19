import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _borrows = [];
  List<Map<String, dynamic>> _parts = [];
  bool _loading = true;

  RealtimeChannel? _channel;

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => _isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => _isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => _isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => _isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => _isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP => _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => _isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
    _tabCtrl.dispose();
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

  // ── Issue dialog ───────────────────────────────────────────────────────────
  void _showIssueDialog() {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    Map<String, dynamic>? selectedPart;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: _surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.assignment_outlined, color: _accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Issue Component', style: GoogleFonts.inter(color: _txtP, fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('Fill student details', style: GoogleFonts.inter(color: _txtM, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Component picker ───────────────────────────────────
                Text('Component', style: GoogleFonts.inter(color: _txtM, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
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
                      hint: Text('Select component', style: GoogleFonts.inter(color: _txtM, fontSize: 13)),
                      items: _parts.map((p) {
                        final avail = (p['availability'] as num?)?.toInt() ?? 0;
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p['part_name']} (${avail} available)',
                            style: GoogleFonts.inter(color: avail > 0 ? _txtP : _danger, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setD(() => selectedPart = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Quantity ───────────────────────────────────────────
                _field(qtyCtrl, 'Quantity', keyboardType: TextInputType.number),
                const SizedBox(height: 14),

                // ── Student info ───────────────────────────────────────
                Text('Student Details', style: GoogleFonts.inter(color: _accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 10),
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
                    Expanded(child: _field(contactCtrl, 'Contact No', keyboardType: TextInputType.phone)),
                  ],
                ),
                const SizedBox(height: 22),

                // ── Buttons ────────────────────────────────────────────
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
                                if (selectedPart == null) { _snack('Select a component', color: _danger); return; }
                                if (nameCtrl.text.trim().isEmpty) { _snack('Enter student name', color: _danger); return; }
                                if (classCtrl.text.trim().isEmpty) { _snack('Enter class', color: _danger); return; }
                                if (sectionCtrl.text.trim().isEmpty) { _snack('Enter section', color: _danger); return; }
                                if (rollCtrl.text.trim().isEmpty) { _snack('Enter roll no', color: _danger); return; }
                                if (contactCtrl.text.trim().isEmpty) { _snack('Enter contact no', color: _danger); return; }

                                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                                if (qty <= 0) { _snack('Enter valid quantity', color: _danger); return; }

                                final avail = (selectedPart!['availability'] as num?)?.toInt() ?? 0;
                                if (qty > avail) { _snack('Only $avail available', color: _danger); return; }

                                setD(() => saving = true);

                                // Insert borrow record
                                await _supabase.from('borrows').insert({
                                  'id': const Uuid().v4(),
                                  'part_id': selectedPart!['id'],
                                  'part_name': selectedPart!['part_name'],
                                  'student_name': nameCtrl.text.trim(),
                                  'class': classCtrl.text.trim(),
                                  'section': sectionCtrl.text.trim(),
                                  'roll_no': rollCtrl.text.trim(),
                                  'contact_no': contactCtrl.text.trim(),
                                  'qty_issued': qty,
                                  'qty_returned': 0,
                                  'is_returned': false,
                                });

                                // Reduce availability
                                await _supabase.from('parts').update({
                                  'availability': avail - qty,
                                }).eq('id', selectedPart!['id']);

                                if (!dCtx.mounted) return;
                                Navigator.pop(dCtx);
                                _snack('Component issued ✓', color: _accent);
                                _fetchAll();
                              },
                        child: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final qtyIssued = (borrow['qty_issued'] as num).toInt();
    final qtyReturned = (borrow['qty_returned'] as num).toInt();
    final qtyPending = qtyIssued - qtyReturned;
    final returnCtrl = TextEditingController(text: qtyPending.toString());
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: _surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.assignment_return_outlined, color: _accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Return Component', style: GoogleFonts.inter(color: _txtP, fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(borrow['part_name'], style: GoogleFonts.inter(color: _txtM, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Info ──────────────────────────────────────────────
                _infoRow('Student', borrow['student_name']),
                _infoRow('Issued', '$qtyIssued'),
                _infoRow('Already returned', '$qtyReturned'),
                _infoRow('Pending', '$qtyPending'),
                const SizedBox(height: 16),

                _field(returnCtrl, 'Quantity returning now', keyboardType: TextInputType.number),
                const SizedBox(height: 20),

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
                                final qty = int.tryParse(returnCtrl.text.trim()) ?? 0;
                                if (qty <= 0) { _snack('Enter valid quantity', color: _danger); return; }
                                if (qty > qtyPending) { _snack('Only $qtyPending pending', color: _danger); return; }

                                setD(() => saving = true);

                                final newReturned = qtyReturned + qty;
                                final isFullyReturned = newReturned >= qtyIssued;

                                // Update borrow record
                                await _supabase.from('borrows').update({
                                  'qty_returned': newReturned,
                                  'is_returned': isFullyReturned,
                                }).eq('id', borrow['id']);

                                // Increase availability
                                final part = await _supabase
                                    .from('parts')
                                    .select('availability')
                                    .eq('id', borrow['part_id'])
                                    .single();
                                final currentAvail = (part['availability'] as num).toInt();
                                await _supabase.from('parts').update({
                                  'availability': currentAvail + qty,
                                }).eq('id', borrow['part_id']);

                                if (!dCtx.mounted) return;
                                Navigator.pop(dCtx);
                                _snack('Return recorded ✓', color: _accent);
                                _fetchAll();
                              },
                        child: saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.inter(color: _txtM, fontSize: 12)),
          ),
          Text(value, style: GoogleFonts.inter(color: _txtP, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: _txtP, fontSize: 13),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _txtM, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    final pending = _borrows.where((b) => !(b['is_returned'] as bool)).toList();
    final returned = _borrows.where((b) => b['is_returned'] as bool).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surf,
        title: Text('Borrow Records', style: GoogleFonts.inter(color: _txtP, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _txtM,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Returned (${returned.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: _isDark ? AppColors.background : Colors.white,
        icon: const Icon(Icons.assignment_add),
        label: Text('Issue', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        onPressed: _showIssueDialog,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(pending, showReturn: true),
                _buildList(returned, showReturn: false),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, {required bool showReturn}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, color: _txtM, size: 52),
            const SizedBox(height: 14),
            Text(
              showReturn ? 'No pending borrows' : 'No returned items yet',
              style: GoogleFonts.inter(color: _txtM, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      itemCount: list.length,
      itemBuilder: (_, i) => _BorrowCard(
        borrow: list[i],
        isDark: _isDark,
        showReturn: showReturn,
        onReturn: () => _showReturnDialog(list[i]),
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
  final bool showReturn;
  final VoidCallback onReturn;

  const _BorrowCard({
    required this.borrow,
    required this.isDark,
    required this.showReturn,
    required this.onReturn,
  });

  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP => isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  Widget build(BuildContext context) {
    final qtyIssued = (borrow['qty_issued'] as num).toInt();
    final qtyReturned = (borrow['qty_returned'] as num).toInt();
    final qtyPending = qtyIssued - qtyReturned;
    final isReturned = borrow['is_returned'] as bool;
    final statusColor = isReturned ? _accent : _danger;

    final issueDate = DateTime.tryParse(borrow['issue_date'] ?? '');
    final dateStr = issueDate != null
        ? '${issueDate.day}/${issueDate.month}/${issueDate.year}'
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: component + status ───────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  borrow['part_name'] ?? '-',
                  style: GoogleFonts.inter(color: _txtP, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isReturned ? Icons.check_circle_outline : Icons.pending_outlined, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      isReturned ? 'Returned' : '$qtyPending pending',
                      style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Student info ──────────────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _chip(Icons.person_outline, borrow['student_name'] ?? '-'),
              _chip(Icons.class_outlined, '${borrow['class']} - ${borrow['section']}'),
              _chip(Icons.numbers_outlined, 'Roll ${borrow['roll_no']}'),
              _chip(Icons.phone_outlined, borrow['contact_no'] ?? '-'),
              _chip(Icons.calendar_today_outlined, dateStr),
            ],
          ),
          const SizedBox(height: 10),

          // ── Qty row + return button ───────────────────────────────
          Row(
            children: [
              // Qty bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issued: $qtyIssued  ·  Returned: $qtyReturned  ·  Pending: $qtyPending',
                      style: GoogleFonts.inter(color: _txtM, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: qtyIssued > 0 ? qtyReturned / qtyIssued : 0,
                        backgroundColor: _danger.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(_accent),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              if (showReturn) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_return_outlined, size: 14),
                  label: const Text('Return'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: onReturn,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _txtM, size: 12),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(color: _txtM, fontSize: 11)),
      ],
    );
  }
}