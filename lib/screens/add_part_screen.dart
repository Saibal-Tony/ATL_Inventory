import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';

class AddPartScreen extends StatefulWidget {
  /// Pass an existing part map to edit; null to create a new one.
  final Map<String, dynamic>? part;
  const AddPartScreen({super.key, this.part});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final _supabase = Supabase.instance.client;

  final _nameCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _boxCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  int _availability = 0;
  File? _newImageFile; // newly picked file
  String? _existingImageUrl; // url from Supabase Storage (edit mode)
  bool _saving = false;

  bool get _isEditing => widget.part != null;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.part!;
      _nameCtrl.text = p['part_name'] ?? '';
      _serialCtrl.text = p['serial_no'] ?? '';
      _categoryCtrl.text = p['category'] ?? '';
      _boxCtrl.text = p['box_no']?.toString() ?? '';
      _totalCtrl.text = p['total_parts']?.toString() ?? '';
      _availability = (p['availability'] as num?)?.toInt() ?? 0;
      _existingImageUrl = p['image_url'] as String?;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _categoryCtrl.dispose();
    _boxCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource src) async {
    final picked = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _newImageFile = File(picked.path));
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Add Photo',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.accent,
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.inter(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.accent,
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.inter(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_newImageFile != null ||
                (_existingImageUrl?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Remove photo',
                  style: GoogleFonts.inter(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _newImageFile = null;
                    _existingImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Upload image to Supabase Storage ──────────────────────────────────────
  Future<String?> _uploadImage(String partId) async {
    if (_newImageFile == null) return _existingImageUrl;
    try {
      final path = 'parts/$partId.jpg';
      await _supabase.storage
          .from('part-images')
          .upload(
            path,
            _newImageFile!,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from('part-images').getPublicUrl(path);
    } catch (e) {
      // Image upload failed — keep going without it
      return _existingImageUrl;
    }
  }

  // ── Save to Supabase ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Component name is required', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final id = _isEditing ? widget.part!['id'] as String : const Uuid().v4();

      final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
      final avail = _availability.clamp(0, total == 0 ? 9999 : total);
      final imageUrl = await _uploadImage(id);

      await _supabase.from('parts').upsert({
        'id': id,
        'part_name': name,
        'serial_no': _serialCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'box_no': int.tryParse(_boxCtrl.text.trim()) ?? 0,
        'total_parts': total,
        'current_count': avail,
        'availability': avail,
        'image_url': imageUrl ?? '',
        'last_updated': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _snack(_isEditing ? 'Component updated!' : 'Component added!');
      Navigator.pop(context);
      // The real-time subscription in InventoryScreen will refresh the list.
    } catch (e) {
      _snack('Save failed: $e', error: true);
    }

    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        backgroundColor: error ? AppColors.danger : AppColors.accent,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Component' : 'Add Component'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_outlined,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image picker ───────────────────────────────────────────────
            _buildImageArea(),

            const SizedBox(height: 24),

            // ── Fields ─────────────────────────────────────────────────────
            _label('Component Name *'),
            _textField(_nameCtrl, hint: 'e.g. Arduino Uno R3'),

            _label('Serial Number'),
            _textField(_serialCtrl, hint: 'e.g. ARD-001'),

            _label('Category'),
            _textField(_categoryCtrl, hint: 'e.g. Microcontrollers'),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Box No.'),
                      _textField(
                        _boxCtrl,
                        hint: '3',
                        inputType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Total Qty'),
                      _textField(
                        _totalCtrl,
                        hint: '10',
                        inputType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Availability stepper ───────────────────────────────────────
            _label('Available Count'),
            const SizedBox(height: 6),
            _buildAvailabilityStepper(),

            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Component' : 'Save Component',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildImageArea() {
    final hasImage =
        _newImageFile != null || (_existingImageUrl?.isNotEmpty ?? false);

    return GestureDetector(
      onTap: _showImageOptions,
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? AppColors.accent.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _newImageFile != null
                      ? Image.file(_newImageFile!, fit: BoxFit.cover)
                      : Image.network(
                          _existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder(),
                        ),
                  // edit overlay
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.accent,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              )
            : _imgPlaceholder(),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.textMuted,
          size: 38,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to add photo',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAvailabilityStepper() {
    final total = int.tryParse(_totalCtrl.text.trim()) ?? 9999;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // decrease
          _stepBtn(
            icon: Icons.remove,
            active: _availability > 0,
            onTap: () {
              if (_availability > 0) setState(() => _availability--);
            },
          ),

          // count
          Expanded(
            child: Text(
              '$_availability',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // increase
          _stepBtn(
            icon: Icons.add,
            active: _availability < total,
            accent: true,
            onTap: () {
              if (_availability < total) setState(() => _availability++);
            },
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required bool active,
    bool accent = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? (accent ? AppColors.accent.withOpacity(0.12) : AppColors.card)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: active
              ? (accent ? AppColors.accent : AppColors.textMuted)
              : AppColors.border,
          size: 20,
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl, {
    String? hint,
    TextInputType inputType = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: inputType,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
    inputFormatters: inputType == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    decoration: InputDecoration(hintText: hint),
  );
}
