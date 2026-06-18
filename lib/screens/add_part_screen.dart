import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';

class AddPartScreen extends StatefulWidget {
  final Map<String, dynamic>? part;
  const AddPartScreen({super.key, this.part});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final _supabase     = Supabase.instance.client;
  final _nameCtrl     = TextEditingController();
  final _serialCtrl   = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _boxCtrl      = TextEditingController();
  final _totalCtrl    = TextEditingController();
  final _notesCtrl    = TextEditingController();

  int    _availability    = 0;
  File?  _newImageFile;
  String? _existingImageUrl;
  bool   _saving          = false;
  String _condition       = 'Good';

  static const _conditions = ['Good', 'Fair', 'Damaged'];

  bool get _isEditing => widget.part != null;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg     => _isDark ? AppColors.background  : AppColorsLight.background;
  Color get _surf   => _isDark ? AppColors.surface     : AppColorsLight.surface;
  Color get _card   => _isDark ? AppColors.card        : AppColorsLight.card;
  Color get _border => _isDark ? AppColors.border      : AppColorsLight.border;
  Color get _accent => _isDark ? AppColors.accent      : AppColorsLight.accent;
  Color get _danger => _isDark ? AppColors.danger      : AppColorsLight.danger;
  Color get _txtP   => _isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM   => _isDark ? AppColors.textMuted   : AppColorsLight.textMuted;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
    if (_isEditing) {
      final p = widget.part!;
      _nameCtrl.text     = p['part_name']  ?? '';
      _serialCtrl.text   = p['serial_no']  ?? '';
      _categoryCtrl.text = p['category']   ?? '';
      _boxCtrl.text      = p['box_no']?.toString()      ?? '';
      _totalCtrl.text    = p['total_parts']?.toString() ?? '';
      _notesCtrl.text    = p['notes']      ?? '';
      _availability      = (p['availability'] as num?)?.toInt() ?? 0;
      _existingImageUrl  = p['image_url']  as String?;
      _condition         = p['condition']  ?? 'Good';
    }
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _categoryCtrl.dispose();
    _boxCtrl.dispose();
    _totalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Image ──────────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    final picked = await ImagePicker()
        .pickImage(source: src, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _newImageFile = File(picked.path));
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2))),
          Text('Add Photo',
              style: GoogleFonts.inter(
                  color: _txtP, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _sheetTile(Icons.camera_alt_outlined,  'Camera',
              () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          _sheetTile(Icons.photo_library_outlined, 'Gallery',
              () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          if (_newImageFile != null || (_existingImageUrl?.isNotEmpty ?? false))
            _sheetTile(Icons.delete_outline, 'Remove photo', () {
              Navigator.pop(context);
              setState(() { _newImageFile = null; _existingImageUrl = null; });
            }, color: _danger),
        ]),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? _accent),
      title: Text(label,
          style: GoogleFonts.inter(color: color ?? _txtP)),
      onTap: onTap,
    );
  }

  // ── Upload ─────────────────────────────────────────────────────────────────
  Future<String?> _uploadImage(String partId) async {
    if (_newImageFile == null) return _existingImageUrl;
    try {
      final path = 'parts/$partId.jpg';
      await _supabase.storage.from('part-images').upload(
            path, _newImageFile!,
            fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('part-images').getPublicUrl(path);
    } catch (_) {
      return _existingImageUrl;
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Component name is required', error: true); return; }

    setState(() => _saving = true);
    try {
      final id = _isEditing ? widget.part!['id'] as String : const Uuid().v4();
      final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
      final avail = _availability.clamp(0, total == 0 ? 9999 : total);
      final imageUrl = await _uploadImage(id);

      await _supabase.from('parts').upsert({
        'id':           id,
        'part_name':    name,
        'serial_no':    _serialCtrl.text.trim(),
        'category':     _categoryCtrl.text.trim(),
        'box_no':       int.tryParse(_boxCtrl.text.trim()) ?? 0,
        'total_parts':  total,
        'current_count': avail,
        'availability': avail,
        'image_url':    imageUrl ?? '',
        'notes':        _notesCtrl.text.trim(),
        'condition':    _condition,
        'last_updated': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _snack(_isEditing ? 'Component updated!' : 'Component added!');
      Navigator.pop(context);
    } catch (e) {
      _snack('Save failed: $e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: _txtP)),
        backgroundColor: error ? _danger : _accent,
      ));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surf,
        title: Text(
          _isEditing ? 'Edit Component' : 'Add Component',
          style: GoogleFonts.inter(color: _txtP, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_outlined, color: _txtP, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        // Theme toggle in add screen too
        actions: [
          IconButton(
            icon: Icon(
                _isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                color: _txtM, size: 20),
            onPressed: () => themeNotifier.value =
                _isDark ? ThemeMode.light : ThemeMode.dark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Image ──────────────────────────────────────────────────────
          _buildImageArea(),
          const SizedBox(height: 24),

          // ── Section: Basic Info ────────────────────────────────────────
          _sectionHeader('Basic Info'),
          _label('Component Name *'),
          _textField(_nameCtrl, hint: 'e.g. Arduino Uno R3'),
          _label('Serial Number'),
          _textField(_serialCtrl, hint: 'e.g. ARD-001'),
          _label('Category'),
          _textField(_categoryCtrl, hint: 'e.g. Microcontrollers'),

          const SizedBox(height: 20),

          // ── Section: Storage ───────────────────────────────────────────
          _sectionHeader('Storage'),
          Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Box No.'),
              _textField(_boxCtrl, hint: '3',
                  inputType: TextInputType.number),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Total Qty'),
              _textField(_totalCtrl, hint: '10',
                  inputType: TextInputType.number),
            ])),
          ]),

          const SizedBox(height: 20),

          // ── Section: Availability ──────────────────────────────────────
          _sectionHeader('Availability'),
          _label('Available Count'),
          const SizedBox(height: 6),
          _buildAvailabilityStepper(),

          const SizedBox(height: 20),

          // ── Section: Condition ─────────────────────────────────────────
          _sectionHeader('Condition'),
          const SizedBox(height: 8),
          _buildConditionSelector(),

          const SizedBox(height: 20),

          // ── Section: Notes ─────────────────────────────────────────────
          _sectionHeader('Notes'),
          _label('Additional Notes'),
          _textField(_notesCtrl,
              hint: 'e.g. Missing one pin, kept in zip bag',
              maxLines: 3),

          const SizedBox(height: 32),

          // ── Save button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _isDark ? AppColors.background : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _isDark
                              ? AppColors.background
                              : Colors.white))
                  : Text(
                      _isEditing ? 'Update Component' : 'Save Component',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Image area ─────────────────────────────────────────────────────────────
  Widget _buildImageArea() {
    final hasImage = _newImageFile != null ||
        (_existingImageUrl?.isNotEmpty ?? false);
    return GestureDetector(
      onTap: _showImageOptions,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: hasImage ? _accent.withOpacity(0.5) : _border,
              width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(fit: StackFit.expand, children: [
                _newImageFile != null
                    ? Image.file(_newImageFile!, fit: BoxFit.cover)
                    : Image.network(_existingImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder()),
                Positioned(
                  right: 10, bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _bg.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_outlined, color: _accent, size: 16),
                  ),
                ),
              ])
            : _imgPlaceholder(),
      ),
    );
  }

  Widget _imgPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: _txtM, size: 40),
          const SizedBox(height: 8),
          Text('Tap to add photo',
              style: GoogleFonts.inter(color: _txtM, fontSize: 13)),
        ],
      );

  // ── Availability stepper ───────────────────────────────────────────────────
  Widget _buildAvailabilityStepper() {
    final total = int.tryParse(_totalCtrl.text.trim()) ?? 9999;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        _stepBtn(
          icon: Icons.remove,
          active: _availability > 0,
          onTap: () { if (_availability > 0) setState(() => _availability--); },
        ),
        Expanded(
          child: Text('$_availability',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: _txtP, fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        _stepBtn(
          icon: Icons.add,
          accent: true,
          active: _availability < total,
          onTap: () {
            if (_availability < total) setState(() => _availability++);
          },
        ),
      ]),
    );
  }

  // ── Condition selector ─────────────────────────────────────────────────────
  Widget _buildConditionSelector() {
    final colors = {
      'Good':    const Color(0xFF00D4AA),
      'Fair':    const Color(0xFFFFB300),
      'Damaged': const Color(0xFFFF5757),
    };
    return Row(children: _conditions.map((c) {
      final sel = _condition == c;
      final col = colors[c]!;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _condition = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(
                right: c != _conditions.last ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? col.withOpacity(0.15) : _surf,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? col : _border, width: sel ? 1.5 : 1),
            ),
            child: Column(children: [
              Icon(
                c == 'Good'
                    ? Icons.check_circle_outline
                    : c == 'Fair'
                        ? Icons.warning_amber_outlined
                        : Icons.cancel_outlined,
                color: sel ? col : _txtM,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(c,
                  style: GoogleFonts.inter(
                      color: sel ? col : _txtM,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }).toList());
  }

  Widget _stepBtn({
    required IconData icon,
    required bool active,
    bool accent = false,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: active
                ? (accent ? _accent.withOpacity(0.12) : _card)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? _border : Colors.transparent),
          ),
          child: Icon(icon,
              color: active
                  ? (accent ? _accent : _txtM)
                  : _border,
              size: 20),
        ),
      );

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.inter(
                  color: _accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: GoogleFonts.inter(
                color: _txtM,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      );

  Widget _textField(
    TextEditingController ctrl, {
    String? hint,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: inputType,
        maxLines: maxLines,
        style: TextStyle(color: _txtP, fontSize: 14),
        inputFormatters: inputType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _txtM, fontSize: 13),
          filled: true,
          fillColor: _surf,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accent, width: 1.5),
          ),
        ),
      );
}