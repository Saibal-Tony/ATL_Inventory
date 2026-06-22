import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import 'login_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _supabase = Supabase.instance.client;
  int _currentTab = 0;

  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _requests = [];
  Map<String, dynamic>? _profile;
  bool _loading = true;

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
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final parts = await _supabase.from('parts').select().order('part_name');
      final profile = await _supabase
          .from('student_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      final cartData = await _supabase
          .from('cart_items')
          .select()
          .eq('student_id', user.id);
      final requests = await _supabase
          .from('requests')
          .select()
          .order('request_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _parts = List<Map<String, dynamic>>.from(parts);
        _profile = profile;
        _cart = List<Map<String, dynamic>>.from(cartData);
        _requests = List<Map<String, dynamic>>.from(
          requests,
        ).where((r) => _matchesProfile(r, profile)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesProfile(
    Map<String, dynamic> req,
    Map<String, dynamic>? profile,
  ) {
    if (profile == null) return false;
    return req['student_name'] == profile['full_name'] &&
        req['roll_no'] == profile['roll_no'];
  }

  // ── Cart operations ────────────────────────────────────────────────────────
  Future<void> _addToCart(Map<String, dynamic> part) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final existing = _cart.indexWhere((c) => c['part_id'] == part['id']);
    final avail = (part['availability'] as num?)?.toInt() ?? 0;

    if (existing >= 0) {
      final currentQty = (_cart[existing]['qty'] as num).toInt();
      if (currentQty >= avail) {
        _snack('Only $avail available', color: _danger);
        return;
      }
      final newQty = currentQty + 1;
      await _supabase
          .from('cart_items')
          .update({'qty': newQty})
          .eq('id', _cart[existing]['id']);
      setState(() => _cart[existing]['qty'] = newQty);
    } else {
      final newItem = {
        'id': const Uuid().v4(),
        'student_id': user.id,
        'part_id': part['id'],
        'part_name': part['part_name'],
        'image_url': part['image_url'] ?? '',
        'qty': 1,
      };
      await _supabase.from('cart_items').insert(newItem);
      setState(() => _cart.add(newItem));
    }
  }

  Future<void> _removeFromCart(Map<String, dynamic> part) async {
    final existing = _cart.indexWhere((c) => c['part_id'] == part['id']);
    if (existing < 0) return;

    final currentQty = (_cart[existing]['qty'] as num).toInt();
    if (currentQty <= 1) {
      await _supabase
          .from('cart_items')
          .delete()
          .eq('id', _cart[existing]['id']);
      setState(() => _cart.removeAt(existing));
    } else {
      final newQty = currentQty - 1;
      await _supabase
          .from('cart_items')
          .update({'qty': newQty})
          .eq('id', _cart[existing]['id']);
      setState(() => _cart[existing]['qty'] = newQty);
    }
  }

  Future<void> _updateCartQty(Map<String, dynamic> cartItem, int delta) async {
    final newQty = (cartItem['qty'] as int) + delta;
    if (newQty <= 0) {
      await _supabase.from('cart_items').delete().eq('id', cartItem['id']);
      setState(() => _cart.removeWhere((c) => c['id'] == cartItem['id']));
    } else {
      await _supabase
          .from('cart_items')
          .update({'qty': newQty})
          .eq('id', cartItem['id']);
      setState(() => cartItem['qty'] = newQty);
    }
  }

  Future<void> _clearCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('cart_items').delete().eq('student_id', user.id);
    setState(() => _cart.clear());
  }

  Future<void> _submitRequest() async {
    if (_cart.isEmpty) return;
    if (_profile == null) {
      _snack('Please complete your profile first', color: _danger);
      return;
    }

    final items = _cart
        .map(
          (c) => {
            'part_id': c['part_id'],
            'part_name': c['part_name'],
            'image_url': c['image_url'] ?? '',
            'qty_requested': c['qty'],
          },
        )
        .toList();

    await _supabase.from('requests').insert({
      'id': const Uuid().v4(),
      'student_name': _profile!['full_name'],
      'class': _profile!['class'],
      'section': _profile!['section'],
      'roll_no': _profile!['roll_no'],
      'contact_no': _profile!['phone_no'],
      'items': items,
      'status': 'pending',
    });

    await _clearCart();
    _snack('Request sent! Admin will review it ✓', color: _accent);
    setState(() => _currentTab = 1);
    _fetchAll();
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? _card),
    );
  }

  int _cartQtyFor(String partId) {
    final item = _cart.where((c) => c['part_id'] == partId).toList();
    if (item.isEmpty) return 0;
    return (item.first['qty'] as num).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = _cart.fold(0, (sum, c) => sum + (c['qty'] as int));

    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            )
          : IndexedStack(
              index: _currentTab,
              children: [
                _HomeTab(
                  parts: _parts,
                  cart: _cart,
                  profile: _profile,
                  isDark: _isDark,
                  cartQtyFor: _cartQtyFor,
                  onAdd: _addToCart,
                  onRemove: _removeFromCart,
                ),
                _CartTab(
                  cart: _cart,
                  onUpdateQty: _updateCartQty,
                  onSubmit: _submitRequest,
                  isDark: _isDark,
                ),
                _RequestsTab(requests: _requests, isDark: _isDark),
                _ProfileTab(
                  profile: _profile,
                  isDark: _isDark,
                  onLogout: () async {
                    await _supabase.auth.signOut(scope: SignOutScope.local);
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surf,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _accent,
          unselectedItemColor: _txtM,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Components',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cartCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$cartCount',
                          style: TextStyle(
                            color: _isDark
                                ? AppColors.background
                                : Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.shopping_cart_rounded),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Requests',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Home Tab — inventory grid with search + category chips
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final List<Map<String, dynamic>> parts;
  final List<Map<String, dynamic>> cart;
  final Map<String, dynamic>? profile;
  final bool isDark;
  final int Function(String) cartQtyFor;
  final Future<void> Function(Map<String, dynamic>) onAdd;
  final Future<void> Function(Map<String, dynamic>) onRemove;

  const _HomeTab({
    required this.parts,
    required this.cart,
    required this.profile,
    required this.isDark,
    required this.cartQtyFor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCat = 'All';

  Color get _bg =>
      widget.isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => widget.isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => widget.isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => widget.isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => widget.isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => widget.isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP =>
      widget.isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM =>
      widget.isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  List<String> get _categories {
    final cats =
        widget.parts
            .map((p) => (p['category'] as String? ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...cats];
  }

  List<Map<String, dynamic>> get _filtered {
    var list = widget.parts;
    if (_selectedCat != 'All')
      list = list.where((p) => p['category'] == _selectedCat).toList();
    if (_query.isNotEmpty) {
      list = list
          .where(
            (p) =>
                (p['part_name'] ?? '').toString().toLowerCase().contains(
                  _query.toLowerCase(),
                ) ||
                (p['serial_no'] ?? '').toString().toLowerCase().contains(
                  _query.toLowerCase(),
                ) ||
                (p['category'] ?? '').toString().toLowerCase().contains(
                  _query.toLowerCase(),
                ) ||
                (p['box_no'] ?? '').toString().contains(_query),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.profile?['full_name'] as String? ?? 'Student')
        .split(' ')
        .first;

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ────────────────────────────────────────────────────
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.18),
                        blurRadius: 10,
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
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $firstName 👋',
                        style: GoogleFonts.inter(
                          color: _txtP,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Browse & request components',
                        style: GoogleFonts.inter(color: _txtM, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isDark
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined,
                    color: _txtM,
                    size: 19,
                  ),
                  onPressed: () => themeNotifier.value = widget.isDark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
              ],
            ),
          ),

          // ── Search ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: _txtP, fontSize: 14),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, category, box no…',
                hintStyle: TextStyle(color: _txtM, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _txtM, size: 19),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: _txtM, size: 17),
                        onPressed: () => setState(() {
                          _query = '';
                          _searchCtrl.clear();
                        }),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Category chips ─────────────────────────────────────────────
          SizedBox(
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
                    onTap: () => setState(() => _selectedCat = cat),
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
                              ? (widget.isDark
                                    ? AppColors.background
                                    : Colors.white)
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
          ),

          const SizedBox(height: 4),

          // ── Grid ───────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: _txtM,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No components found',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final part = _filtered[i];
                      final total = (part['total_parts'] as num?)?.toInt() ?? 0;
                      final avail =
                          (part['availability'] as num?)?.toInt() ?? 0;
                      final ratio = total > 0
                          ? (avail / total).clamp(0.0, 1.0)
                          : 0.0;
                      final imgUrl = part['image_url'] as String?;
                      final cartQty = widget.cartQtyFor(part['id'] as String);

                      final Color statusColor = ratio > 0.5
                          ? _accent
                          : ratio > 0.2
                          ? (widget.isDark
                                ? AppColors.warning
                                : AppColorsLight.warning)
                          : _danger;

                      return Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                          boxShadow: widget.isDark
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
                            // ── Image ───────────────────────────────────
                            Stack(
                              children: [
                                SizedBox(
                                  height: 130,
                                  width: double.infinity,
                                  child: imgUrl != null && imgUrl.isNotEmpty
                                      ? Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _placeholder(),
                                        )
                                      : _placeholder(),
                                ),
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
                                            : const Color(
                                                0xFFFFB300,
                                              ).withOpacity(0.85),
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

                                // ── Cart button bottom-right ─────────────
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: cartQty == 0
                                      ? GestureDetector(
                                          onTap: avail > 0
                                              ? () => widget.onAdd(part)
                                              : null,
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: avail > 0
                                                  ? _accent
                                                  : _border,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              color: avail > 0
                                                  ? (widget.isDark
                                                        ? AppColors.background
                                                        : Colors.white)
                                                  : _txtM,
                                              size: 18,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: _accent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () =>
                                                    widget.onRemove(part),
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  child: Icon(
                                                    Icons.remove,
                                                    color: widget.isDark
                                                        ? AppColors.background
                                                        : Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '$cartQty',
                                                style: TextStyle(
                                                  color: widget.isDark
                                                      ? AppColors.background
                                                      : Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: avail > cartQty
                                                    ? () => widget.onAdd(part)
                                                    : null,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  child: Icon(
                                                    Icons.add,
                                                    color: widget.isDark
                                                        ? AppColors.background
                                                        : Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),

                            // ── Info ────────────────────────────────────
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  5,
                                  10,
                                  5,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            if ((part['category'] as String? ??
                                                    '')
                                                .isNotEmpty) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _accent.withOpacity(
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  part['category'],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CustomPaint(
                                            painter: _ArcPainter(
                                              ratio,
                                              statusColor,
                                              _border,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: widget.isDark ? AppColors.surface : AppColorsLight.surface,
    child: Center(child: Icon(Icons.memory_outlined, color: _txtM, size: 32)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cart Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CartTab extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final Future<void> Function(Map<String, dynamic>, int) onUpdateQty;
  final Future<void> Function() onSubmit;
  final bool isDark;

  const _CartTab({
    required this.cart,
    required this.onUpdateQty,
    required this.onSubmit,
    required this.isDark,
  });

  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Text(
                  'Your Cart',
                  style: GoogleFonts.inter(
                    color: _txtP,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (cart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${cart.length}',
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.background : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          color: _txtM,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your cart is empty',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse components and add to cart',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      final imgUrl = item['image_url'] as String? ?? '';
                      final qty = (item['qty'] as num).toInt();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surf,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imgUrl.isNotEmpty
                                  ? Image.network(
                                      imgUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(),
                                    )
                                  : _placeholder(),
                            ),
                            const SizedBox(width: 12),
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
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => onUpdateQty(item, -1),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _card,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      color: _txtM,
                                      size: 14,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    '$qty',
                                    style: GoogleFonts.inter(
                                      color: _txtP,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => onUpdateQty(item, 1),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      color: isDark
                                          ? AppColors.background
                                          : Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: _surf,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    'Request Come to Me',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onSubmit,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 56,
    height: 56,
    color: isDark ? AppColors.card : AppColorsLight.card,
    child: Icon(
      Icons.memory_outlined,
      color: isDark ? AppColors.textMuted : AppColorsLight.textMuted,
      size: 24,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Requests Tab
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool isDark;

  const _RequestsTab({required this.requests, required this.isDark});

  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _warn => isDark ? AppColors.warning : AppColorsLight.warning;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Text(
                  'My Requests',
                  style: GoogleFonts.inter(
                    color: _txtP,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: _txtM,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No requests yet',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: requests.length,
                    itemBuilder: (_, i) {
                      final req = requests[i];
                      final status = req['status'] as String;
                      final items = List<Map<String, dynamic>>.from(
                        req['items'] as List,
                      );
                      final statusColor = status == 'pending'
                          ? _warn
                          : status == 'approved'
                          ? _accent
                          : _danger;
                      final statusLabel = status == 'pending'
                          ? 'Pending'
                          : status == 'approved'
                          ? 'Accepted'
                          : 'Denied';
                      final reqDate = DateTime.tryParse(
                        req['request_date'] ?? '',
                      )?.toLocal();
                      final dateStr = reqDate != null
                          ? '${reqDate.day}/${reqDate.month}/${reqDate.year}'
                          : '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surf,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Request ID',
                                  style: GoogleFonts.inter(
                                    color: _txtM,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
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
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '#${req['id'].toString().substring(0, 8).toUpperCase()}',
                              style: GoogleFonts.inter(
                                color: _accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${items.length} item${items.length > 1 ? 's' : ''} · $dateStr',
                              style: GoogleFonts.inter(
                                color: _txtM,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.circle, color: _accent, size: 5),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item['part_name']} x${item['qty_requested']}',
                                      style: GoogleFonts.inter(
                                        color: _txtP,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (status == 'approved')
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Accepted — Admin will bring it to you.',
                                  style: GoogleFonts.inter(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool isDark;
  final VoidCallback onLogout;

  const _ProfileTab({
    required this.profile,
    required this.isDark,
    required this.onLogout,
  });

  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  profile != null
                      ? (profile!['full_name'] as String)[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile?['full_name'] ?? 'Student',
              style: GoogleFonts.inter(
                color: _txtP,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              profile?['email'] ?? '',
              style: GoogleFonts.inter(color: _txtM, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (profile != null) ...[
              _infoCard(
                'Class',
                '${profile!['class']} - ${profile!['section']}',
              ),
              _infoCard('Roll No', profile!['roll_no']),
              _infoCard('Phone', profile!['phone_no']),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.edit_outlined, size: 16, color: _accent),
                label: Text('Edit Profile', style: TextStyle(color: _accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _accent.withOpacity(0.5)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentProfileScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.logout_outlined, size: 16, color: _danger),
                label: Text('Logout', style: TextStyle(color: _danger)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _danger.withOpacity(0.5)),
                ),
                onPressed: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _surf,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Text(label, style: GoogleFonts.inter(color: _txtM, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _txtP,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Arc painter
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
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * ratio.clamp(0.0, 0.999),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.ratio != ratio || old.color != color;
}
