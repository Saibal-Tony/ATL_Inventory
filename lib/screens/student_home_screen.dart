import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import 'login_screen.dart';
import 'student_auth_screen.dart';
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
      final requests = await _supabase
          .from('requests')
          .select()
          .order('request_date', ascending: false);

      // Load cart from Supabase
      final cartData = await _supabase
          .from('cart_items')
          .select()
          .eq('student_id', user.id);

      if (!mounted) return;
      setState(() {
        _parts = List<Map<String, dynamic>>.from(parts);
        _profile = profile;
        _requests = List<Map<String, dynamic>>.from(requests)
            .where(
              (r) => r['student_id'] == user.id || _matchesProfile(r, profile),
            )
            .toList();
        _cart = List<Map<String, dynamic>>.from(cartData);
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
    _snack('Added to cart ✓', color: _accent);
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

  // ── Submit request ─────────────────────────────────────────────────────────
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
    setState(() => _currentTab = 3);
    _fetchAll();
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? _card),
    );
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
                  onAddToCart: _addToCart,
                  profile: _profile,
                  isDark: _isDark,
                  onTabChange: (i) => setState(() => _currentTab = i),
                ),
                _SearchTab(
                  parts: _parts,
                  cart: _cart,
                  onAddToCart: _addToCart,
                  isDark: _isDark,
                ),
                _CartTab(
                  cart: _cart,
                  parts: _parts,
                  onUpdateQty: _updateCartQty,
                  onSubmit: _submitRequest,
                  isDark: _isDark,
                ),
                _RequestsTab(requests: _requests, isDark: _isDark),
                _ProfileTab(
                  profile: _profile,
                  isDark: _isDark,
                  onLogout: () async {
                    await Supabase.instance.client.auth.signOut(
                      scope: SignOutScope.local,
                    );

                    if (!context.mounted) return;

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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              label: 'Search',
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
//  Home Tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final List<Map<String, dynamic>> parts;
  final List<Map<String, dynamic>> cart;
  final Future<void> Function(Map<String, dynamic>) onAddToCart;
  final Map<String, dynamic>? profile;
  final bool isDark;
  final void Function(int) onTabChange;

  const _HomeTab({
    required this.parts,
    required this.cart,
    required this.onAddToCart,
    required this.profile,
    required this.isDark,
    required this.onTabChange,
  });

  Color get _bg => isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  List<String> get _categories {
    final cats =
        parts
            .map((p) => (p['category'] as String? ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (profile?['full_name'] as String? ?? 'Student')
        .split(' ')
        .first;
    final popular = parts
        .where((p) => ((p['availability'] as num?)?.toInt() ?? 0) > 0)
        .take(6)
        .toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _surf,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName 👋',
                          style: GoogleFonts.inter(
                            color: _txtP,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What do you need today?',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Theme toggle
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_outlined,
                      color: _txtM,
                      size: 20,
                    ),
                    onPressed: () => themeNotifier.value = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => onTabChange(1),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: _txtM, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Search components...',
                      style: GoogleFonts.inter(color: _txtM, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Categories ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: GoogleFonts.inter(
                      color: _txtP,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTabChange(1),
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final count = parts.where((p) => p['category'] == cat).length;
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.memory_outlined, color: _accent, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: _txtP,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$count items',
                          style: GoogleFonts.inter(color: _txtM, fontSize: 9),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Popular ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Popular Components',
                    style: GoogleFonts.inter(
                      color: _txtP,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onTabChange(1),
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final part = popular[i];
              final avail = (part['availability'] as num?)?.toInt() ?? 0;
              final imgUrl = part['image_url'] as String? ?? '';
              final inCart = cart.any((c) => c['part_id'] == part['id']);

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            part['part_name'],
                            style: GoogleFonts.inter(
                              color: _txtP,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            part['category'] ?? '',
                            style: GoogleFonts.inter(
                              color: _txtM,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$avail available',
                            style: GoogleFonts.inter(
                              color: avail > 0
                                  ? _accent
                                  : (isDark
                                        ? AppColors.danger
                                        : AppColorsLight.danger),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: avail > 0 ? () => onAddToCart(part) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: avail > 0
                              ? _accent.withOpacity(inCart ? 0.2 : 1)
                              : _border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          inCart ? 'Added' : 'Add to Cart',
                          style: GoogleFonts.inter(
                            color: avail > 0
                                ? (inCart
                                      ? _accent
                                      : (isDark
                                            ? AppColors.background
                                            : Colors.white))
                                : (isDark
                                      ? AppColors.textMuted
                                      : AppColorsLight.textMuted),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }, childCount: popular.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
//  Search Tab
// ─────────────────────────────────────────────────────────────────────────────
class _SearchTab extends StatefulWidget {
  final List<Map<String, dynamic>> parts;
  final List<Map<String, dynamic>> cart;
  final Future<void> Function(Map<String, dynamic>) onAddToCart;
  final bool isDark;

  const _SearchTab({
    required this.parts,
    required this.cart,
    required this.onAddToCart,
    required this.isDark,
  });

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _ctrl = TextEditingController();
  String _query = '';
  String _selectedCat = 'All';

  Color get _bg =>
      widget.isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => widget.isDark ? AppColors.surface : AppColorsLight.surface;
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
                (p['category'] ?? '').toString().toLowerCase().contains(
                  _query.toLowerCase(),
                ),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Container(
            color: _surf,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: _txtP),
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search components...',
                hintStyle: TextStyle(color: _txtM, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _txtM, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: _txtM, size: 16),
                        onPressed: () => setState(() {
                          _query = '';
                          _ctrl.clear();
                        }),
                      )
                    : null,
              ),
            ),
          ),

          // ── Category chips ─────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = cat == _selectedCat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCat = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
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
                );
              },
            ),
          ),

          // ── Results ────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No components found',
                      style: GoogleFonts.inter(color: _txtM, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final part = _filtered[i];
                      final avail =
                          (part['availability'] as num?)?.toInt() ?? 0;
                      final imgUrl = part['image_url'] as String? ?? '';
                      final inCart = widget.cart.any(
                        (c) => c['part_id'] == part['id'],
                      );

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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    part['part_name'],
                                    style: GoogleFonts.inter(
                                      color: _txtP,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    part['category'] ?? '',
                                    style: GoogleFonts.inter(
                                      color: _txtM,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Box ${part['box_no'] ?? '-'} · $avail available',
                                    style: GoogleFonts.inter(
                                      color: avail > 0 ? _accent : _danger,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: avail > 0
                                  ? () => widget.onAddToCart(part)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: avail > 0
                                      ? _accent.withOpacity(inCart ? 0.2 : 1)
                                      : _border,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  inCart ? 'Added' : 'Add',
                                  style: GoogleFonts.inter(
                                    color: avail > 0
                                        ? (inCart
                                              ? _accent
                                              : (widget.isDark
                                                    ? AppColors.background
                                                    : Colors.white))
                                        : _txtM,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
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
    width: 56,
    height: 56,
    color: widget.isDark ? AppColors.card : AppColorsLight.card,
    child: Icon(Icons.memory_outlined, color: _txtM, size: 24),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cart Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CartTab extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final List<Map<String, dynamic>> parts;
  final Future<void> Function(Map<String, dynamic>, int) onUpdateQty;
  final Future<void> Function() onSubmit;
  final bool isDark;

  const _CartTab({
    required this.cart,
    required this.parts,
    required this.onUpdateQty,
    required this.onSubmit,
    required this.isDark,
  });

  Color get _bg => isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
  Color get _border => isDark ? AppColors.border : AppColorsLight.border;
  Color get _accent => isDark ? AppColors.accent : AppColorsLight.accent;
  Color get _danger => isDark ? AppColors.danger : AppColorsLight.danger;
  Color get _txtP =>
      isDark ? AppColors.textPrimary : AppColorsLight.textPrimary;
  Color get _txtM => isDark ? AppColors.textMuted : AppColorsLight.textMuted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
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

          // ── Cart items ─────────────────────────────────────────────────
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
                      final qty = item['qty'] as int;

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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['part_name'],
                                    style: GoogleFonts.inter(
                                      color: _txtP,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls
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

          // ── Submit button ──────────────────────────────────────────────
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

  Color get _bg => isDark ? AppColors.background : AppColorsLight.background;
  Color get _surf => isDark ? AppColors.surface : AppColorsLight.surface;
  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
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
                                  'Seller is on the way.',
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
  Color get _card => isDark ? AppColors.card : AppColorsLight.card;
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
            // ── Avatar ──────────────────────────────────────────────────
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

            // ── Info cards ───────────────────────────────────────────────
            if (profile != null) ...[
              _infoCard(
                'Class',
                '${profile!['class']} - ${profile!['section']}',
              ),
              _infoCard('Roll No', profile!['roll_no']),
              _infoCard('Phone', profile!['phone_no']),
            ],

            const SizedBox(height: 24),

            // ── Edit profile ─────────────────────────────────────────────
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

            // ── Logout ───────────────────────────────────────────────────
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

  Widget _infoCard(String label, String value) {
    return Container(
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
}
