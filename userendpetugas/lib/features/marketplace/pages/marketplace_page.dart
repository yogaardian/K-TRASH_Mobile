import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/api_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/marketplace_service.dart';
import '../../../services/user_service.dart';
import '../../../shared/models/product_model.dart';

// ============================================================
// DESIGN TOKENS — tema "green fintech / eco marketplace" 2026
// ============================================================
class _Palette {
  static const primary = Color(0xFF16A34A);
  static const secondary = Color(0xFF22C55E);
  static const accent = Color(0xFF4ADE80);
  static const background = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
}

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({Key? key}) : super(key: key);

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductModel> _products = [];
  bool _isLoading = true;
  bool _isOrdering = false;
  bool _isRefreshingBalance = false;
  String? _errorMessage;
  String _selectedCategory = 'Semua';
  String _searchTerm = '';
  Map<String, dynamic>? _balanceData;

  static const categories = [
    'Semua',
    'Beras',
    'Minyak',
    'Telur',
    'Gula',
    'Tepung',
    'Bumbu',
    'Minuman',
    'Paket',
  ];

  // ---- category icon map (presentation-only, no logic impact) ----
  static const Map<String, IconData> _categoryIcons = {
    'semua': Icons.apps_rounded,
    'beras': Icons.rice_bowl_rounded,
    'minyak': Icons.opacity_rounded,
    'telur': Icons.egg_rounded,
    'gula': Icons.icecream_rounded,
    'tepung': Icons.bakery_dining_rounded,
    'bumbu': Icons.soup_kitchen_rounded,
    'minuman': Icons.local_drink_rounded,
    'paket': Icons.inventory_2_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadMarketplace();
    _searchController.addListener(() {
      setState(() => _searchTerm = _searchController.text.trim());
    });
  }

  double _parseNumeric(dynamic raw, [double fallback = 0.0]) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(',', '');
      return double.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketplace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    try {
      final products = await _marketplaceService.getProducts();
      if (userId != null) {
        final balance = await _userService.getUserData(userId);
        if (mounted) {
          setState(() => _balanceData = balance);
        }
      }
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshBalance() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;

    setState(() {
      _isRefreshingBalance = true;
      _errorMessage = null;
    });

    try {
      final balance = await _userService.getUserData(authProvider.user!.id);
      setState(() => _balanceData = balance);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isRefreshingBalance = false;
      });
    }
  }

  Future<void> _createOrder(ProductModel product) async {
    setState(() {
      _isOrdering = true;
      _errorMessage = null;
    });

    try {
      await _marketplaceService.createProductOrder(
        productId: product.id,
        quantity: 1,
        catatan: 'Pembelian ${product.nama}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _Palette.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('Berhasil memesan ${product.nama}'),
        ),
      );
      await _refreshBalance();
      await _loadMarketplace();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _Palette.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(_errorMessage ?? 'Gagal memesan produk.'),
        ),
      );
    } finally {
      setState(() {
        _isOrdering = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    final searchLower = _searchTerm.toLowerCase();
    return _products.where((product) {
      final name = product.nama.toLowerCase();
      final description = product.deskripsi.toLowerCase();
      final category = product.kategori.toLowerCase();
      final matchesSearch =
          _searchTerm.isEmpty ||
          name.contains(searchLower) ||
          description.contains(searchLower);
      final matchesCategory =
          _selectedCategory == 'Semua' ||
          category.contains(_selectedCategory.toLowerCase()) ||
          name.contains(_selectedCategory.toLowerCase());
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _getPlaceholderImage(
    String category, {
    String? productName,
    int? productId,
  }) {
    final key = category.toLowerCase();
    final seedBase = [
      key,
      productName?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-') ??
          'produk',
      productId?.toString() ?? '0',
    ].join('-');

    final placeholders = {
      'beras': 'https://picsum.photos/seed/beras/500/300',
      'minyak': 'https://picsum.photos/seed/minyak/500/300',
      'telur': 'https://picsum.photos/seed/telur/500/300',
      'gula': 'https://picsum.photos/seed/gula/500/300',
      'tepung': 'https://picsum.photos/seed/tepung/500/300',
      'bumbu': 'https://picsum.photos/seed/bumbu/500/300',
      'minuman': 'https://picsum.photos/seed/minuman/500/300',
      'paket': 'https://picsum.photos/seed/paket/500/300',
      'lokal': 'https://picsum.photos/seed/lokal/500/300',
    };

    final baseUrl =
        placeholders[key] ?? 'https://picsum.photos/seed/produk/500/300';
    return '$baseUrl?seed=$seedBase';
  }

  String _getProductImageUrl(ProductModel product) {
    final rawUrl = product.gambar?.trim();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final normalizedUrl = rawUrl.replaceAll('\\', '/').trim();
      final uri = Uri.tryParse(normalizedUrl);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        return normalizedUrl;
      }

      if (normalizedUrl.startsWith('//')) {
        return '${ApiConstants.baseUrl.replaceFirst(RegExp(r'^https?://'), '')}$normalizedUrl';
      }

      if (normalizedUrl.startsWith('/')) {
        return '${ApiConstants.baseUrl}$normalizedUrl';
      }

      return '${ApiConstants.baseUrl}/${normalizedUrl.replaceAll(RegExp(r'^/+'), '')}';
    }

    return _getPlaceholderImage(
      product.kategori,
      productName: product.nama,
      productId: product.id,
    );
  }

  // Presentation-only helper — pure formatting, no business logic change.
  String _formatRupiah(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final totalSaldo = _parseNumeric(
      _balanceData?['saldo'],
      user?.saldo ?? 0.0,
    );
    final saldoHold = _parseNumeric(
      _balanceData?['saldo_hold'],
      user?.saldoHold ?? 0.0,
    );
    final availableBalance = totalSaldo - saldoHold;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final baseCrossAxisCount = width >= 900 ? 3 : 2;
    // If the device is very short, prefer a single column to avoid vertical overflow
    final crossAxisCount = height < 650 ? 1 : baseCrossAxisCount;

    // compute item width and target height to avoid vertical overflow on short screens
    const horizontalPadding = 32.0; // left+right sliver padding (16+16)
    const crossAxisSpacing = 12.0;
    final itemWidth =
        (width - horizontalPadding - (crossAxisCount - 1) * crossAxisSpacing) /
        crossAxisCount;
    // target card height: responsive but clamped so cards aren't too tall on small screens
    final targetCardHeight = height * (width >= 900 ? 0.28 : 0.32);
    final clampedCardHeight = targetCardHeight.clamp(220.0, 380.0);
    final childAspectRatio = itemWidth / clampedCardHeight;

    return Scaffold(
      backgroundColor: _Palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _Palette.primary,
          onRefresh: _loadMarketplace,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildBalanceCard(availableBalance, totalSaldo, saldoHold),
                    const SizedBox(height: 20),
                    _buildSearchAndCategories(),
                    const SizedBox(height: 18),
                    if (_errorMessage != null)
                      _buildErrorBanner(_errorMessage!),
                    _buildSectionHeader(),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              if (_isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: _Palette.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              else if (_filteredProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product, availableBalance);
                    }, childCount: _filteredProducts.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      // Use childAspectRatio (width / height) so the grid
                      // adapts to screen width and avoids fixed excessive height.
                      childAspectRatio: childAspectRatio,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketplace',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _Palette.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Penuhi kebutuhan operasional toko Anda',
                style: TextStyle(fontSize: 13, color: _Palette.muted),
              ),
            ],
          ),
        ),
        _CircleIconButton(
          icon: Icons.refresh_rounded,
          isLoading: _isLoading,
          onTap: _isLoading || _isRefreshingBalance ? null : _loadMarketplace,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // BALANCE CARD
  // ---------------------------------------------------------------
  Widget _buildBalanceCard(double available, double total, double hold) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [_Palette.primary, _Palette.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Saldo Tersedia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _RefreshPill(
                isLoading: _isRefreshingBalance,
                onTap: _isRefreshingBalance ? null : _refreshBalance,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rp ${_formatRupiah(available)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(child: _buildBalanceItem('Total Saldo', total)),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.25),
                ),
                Expanded(
                  child: _buildBalanceItem('Saldo Hold', hold, alignEnd: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, num value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rp ${_formatRupiah(value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // SEARCH + CATEGORY FILTER
  // ---------------------------------------------------------------
  Widget _buildSearchAndCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _Palette.border),
            boxShadow: [
              BoxShadow(
                color: _Palette.text.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14, color: _Palette.text),
            decoration: InputDecoration(
              hintText: 'Cari produk, kategori, atau kebutuhan...',
              hintStyle: const TextStyle(color: _Palette.muted, fontSize: 13.5),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _Palette.muted,
                size: 22,
              ),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _Palette.muted,
                        size: 18,
                      ),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isActive = category == _selectedCategory;
              final icon =
                  _categoryIcons[category.toLowerCase()] ??
                  Icons.category_rounded;
              return _CategoryChip(
                label: category,
                icon: icon,
                isActive: isActive,
                onTap: () => setState(() => _selectedCategory = category),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // SECTION HEADER
  // ---------------------------------------------------------------
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Produk Marketplace',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _Palette.text,
            letterSpacing: -0.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _Palette.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredProducts.length} produk',
            style: const TextStyle(
              color: _Palette.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // ERROR BANNER
  // ---------------------------------------------------------------
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Palette.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.danger.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _Palette.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _Palette.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _Palette.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: _Palette.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada produk yang cocok',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _Palette.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah kata kunci pencarian atau kategori filter Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _Palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PRODUCT CARD
  // ---------------------------------------------------------------
  Widget _buildProductCard(ProductModel product, double availableBalance) {
    final price = 'Rp ${_formatRupiah(product.harga)}';
    final canBuy = product.stok > 0 && availableBalance >= product.harga;
    final imageUrl = _getProductImageUrl(product);

    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Palette.border),
        boxShadow: [
          BoxShadow(
            color: _Palette.text.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- image + stock badge ----
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  // keep a consistent, wide image area to reduce cropping
                  // and avoid large empty vertical gaps inside the card
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: _Palette.background,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _Palette.primary,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_Palette.primary, _Palette.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  product.nama,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: product.stok > 0
                        ? Colors.white.withOpacity(0.92)
                        : _Palette.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.stok > 0 ? 'Stok ${product.stok}' : 'Habis',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: product.stok > 0 ? _Palette.primary : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ---- content ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nama,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _Palette.text,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.deskripsi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Palette.muted,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _Palette.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: !canBuy || _isOrdering
                          ? null
                          : () => _showPurchaseConfirmation(product),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: canBuy
                            ? _Palette.primary
                            : _Palette.background,
                        disabledBackgroundColor: _Palette.background,
                        foregroundColor: canBuy ? Colors.white : _Palette.muted,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: canBuy
                              ? BorderSide.none
                              : BorderSide(color: _Palette.border),
                        ),
                      ),
                      child: Text(
                        !canBuy
                            ? (product.stok <= 0
                                  ? 'Stok Habis'
                                  : 'Saldo Kurang')
                            : _isOrdering
                            ? 'Memproses...'
                            : 'Beli Sekarang',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseConfirmation(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _Palette.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: _Palette.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Beli ${product.nama}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _Palette.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apakah Anda yakin ingin membeli 1x ${product.nama} dengan harga Rp ${_formatRupiah(product.harga)}?',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _Palette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          foregroundColor: _Palette.muted,
                          side: const BorderSide(color: _Palette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _createOrder(product);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _Palette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Konfirmasi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ====================================================================
// SMALL REUSABLE PRESENTATION WIDGETS (no business logic, UI only)
// ====================================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.card,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _Palette.border),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _Palette.primary,
                    ),
                  )
                : Icon(icon, color: _Palette.text, size: 19),
          ),
        ),
      ),
    );
  }
}

class _RefreshPill extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _RefreshPill({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Segarkan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? _Palette.primary : _Palette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? _Palette.primary : _Palette.border,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _Palette.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : _Palette.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : _Palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
