import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../constants/route_constants.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../utils/profile_photo_utils.dart';

// ─── Design Tokens (tidak diubah) ─────────────────────────────────────────
class _DS {
  static const primary = Color(0xFF16A34A);
  static const primaryDark = Color(0xFF15803D);
  static const primaryDeep = Color(0xFF0F4C25);
  static const secondary = Color(0xFF22C55E);
  static const accent = Color(0xFF4ADE80);
  static const bg = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const greenLight = Color(0xFFDCFCE7);
  static const greenMid = Color(0xFFBBF7D0);
  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFFFBEB);

  static const r12 = Radius.circular(12);
  static const r16 = Radius.circular(16);
  static const r20 = Radius.circular(20);
  static const r24 = Radius.circular(24);
  static const r28 = Radius.circular(28);
  static const r32 = Radius.circular(32);
  static const r999 = Radius.circular(999);

  static BoxShadow get shadowSm => BoxShadow(
    color: const Color(0xFF0F172A).withOpacity(0.06),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
  static BoxShadow get shadowMd => BoxShadow(
    color: const Color(0xFF0F172A).withOpacity(0.08),
    blurRadius: 16,
    offset: const Offset(0, 6),
  );
  static BoxShadow get shadowGreen => BoxShadow(
    color: primary.withOpacity(0.22),
    blurRadius: 24,
    offset: const Offset(0, 10),
  );
}

// ─── Page ──────────────────────────────────────────────────────────────────
class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({Key? key}) : super(key: key);

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabCtrl;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    final auth = context.read<AuthProvider>();
    final dashboard = context.read<DashboardProvider>();
    if (auth.user != null) dashboard.loadDashboard(auth.user!.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: _DS.bg,
      extendBodyBehindAppBar: true,
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut),
        child: _FabPickup(
          onTap: () => Navigator.pushNamed(context, RouteConstants.pickupPage),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        onHistory: () =>
            Navigator.pushNamed(context, RouteConstants.userHistory),
        onMarketplace: () =>
            Navigator.pushNamed(context, RouteConstants.marketplace),
        onProfile: () =>
            Navigator.pushNamed(context, RouteConstants.userProfile),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: dashboard.isLoading
            ? _LoadingView()
            : dashboard.errorMessage != null
            ? _ErrorView(
                message: dashboard.errorMessage!,
                onRetry: () {
                  if (auth.user != null) dashboard.refresh(auth.user!.id);
                },
              )
            : RefreshIndicator(
                color: _DS.primary,
                backgroundColor: _DS.card,
                onRefresh: () async {
                  if (auth.user != null) await dashboard.refresh(auth.user!.id);
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: kBottomNavigationBarHeight + 16,
                  ),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _Header(auth: auth)),
                      SliverToBoxAdapter(child: _HeroBanner()),
                      SliverToBoxAdapter(child: const SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: _WalletCard(
                          dashboard: dashboard,
                          onTap: () =>
                              Navigator.pushNamed(context, RouteConstants.userHistory),
                        ),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: _InfoGrid(dashboard: dashboard),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: _MarketplaceCard(
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteConstants.marketplace,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: _PickupBanner(
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteConstants.pickupPage,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              kBottomNavigationBarHeight +
                              MediaQuery.of(context).padding.bottom +
                              20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Header (disederhanakan, mengikuti .topbar web) ───────────────────────
class _Header extends StatelessWidget {
  final AuthProvider auth;
  const _Header({required this.auth});

  @override
  Widget build(BuildContext context) {
    final name = auth.user?.nama ?? 'Pengguna';
    final imageProvider = buildProfileImageProvider(auth.user?.profilePhoto);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            _AvatarButton(
              initial: name.isNotEmpty ? name[0].toUpperCase() : 'U',
              image: imageProvider,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String initial;
  final ImageProvider? image;
  const _AvatarButton({required this.initial, this.image});

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _DS.greenMid, width: 1.5),
          image: DecorationImage(image: image!, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _DS.primary,
        border: Border.all(color: _DS.greenMid, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}

// ─── Hero Banner (porting dari .hero-banner web) ──────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 480;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _DS.greenLight,
              borderRadius: const BorderRadius.all(_DS.r24),
            ),
            child: Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang, 👋',
                        style: TextStyle(
                          fontSize: 13,
                          color: _DS.textMuted,
                          fontFamily: 'NunitoSans',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Jaga lingkungan mulai dari langkah kecil!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans',
                          color: _DS.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kelola sampah dengan mudah, pantau saldo poin, dan jadwalkan penjemputan kapan saja.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _DS.textMuted,
                          fontFamily: 'NunitoSans',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide) const SizedBox(width: 16),
                if (!isWide) const SizedBox(height: 12),
                Text('♻️', style: TextStyle(fontSize: isWide ? 56 : 44)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Wallet / Saldo Card (porting dari .saldo-card web) ───────────────────
class _WalletCard extends StatelessWidget {
  final DashboardProvider dashboard;
  final VoidCallback onTap;
  const _WalletCard({required this.dashboard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_DS.primary, _DS.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.all(_DS.r24),
            boxShadow: [_DS.shadowGreen],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: const BorderRadius.all(_DS.r16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo Poin Kamu',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontFamily: 'NunitoSans',
                          ),
                        ),
                        const SizedBox(height: 6),
                        // NOTE: getFormattedBalance() = logic provider lama, tidak diubah
                        Text(
                          dashboard.getFormattedBalance(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'PlusJakartaSans',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Subtext saldo tersedia / tertahan (porting dari .saldo-subtext)
              // ASUMSI: dashboard.availableBalanceFormatted & dashboard.holdBalanceFormatted
              // sudah/akan tersedia di provider (mengikuti pola getFormattedBalance()).
              // Jika belum ada, ganti dengan getter yang sesuai pada DashboardProvider Anda.
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    'Tersedia: ${dashboard.getFormattedAvailableBalance()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                      fontFamily: 'NunitoSans',
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  Text(
                    'Tertahan: ${dashboard.getFormattedHoldBalance()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                      fontFamily: 'NunitoSans',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Lihat Detail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'NunitoSans',
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Grid: Harga Sampah + Aktivitas (porting dari .info-grid web) ────
class _InfoGrid extends StatelessWidget {
  final DashboardProvider dashboard;
  const _InfoGrid({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final harga = _HargaCard(dashboard: dashboard);
          final aktivitas = _AktivitasCard(dashboard: dashboard);
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: harga),
                const SizedBox(width: 16),
                Expanded(child: aktivitas),
              ],
            );
          }
          return Column(
            children: [
              harga,
              const SizedBox(height: 16),
              aktivitas,
            ],
          );
        },
      ),
    );
  }
}

class _InfoCardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _InfoCardHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                color: _DS.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
            ),
            child: const Text(
              'Lihat Semua',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _DS.primary,
                fontFamily: 'NunitoSans',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Harga Sampah Card (porting dari .harga-list)
// ASUMSI: dashboard.hargaSampah adalah List item dengan field subJenis & harga,
// mengikuti hargaAPI.getByJenis('anorganik') pada web. Jika provider belum
// mengekspos field ini, tambahkan getter ringan (bukan business logic baru,
// hanya expose data yang backend-nya sudah identik).
class _HargaCard extends StatelessWidget {
  final DashboardProvider dashboard;
  const _HargaCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.hargaSampah.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: _DS.card,
        borderRadius: const BorderRadius.all(_DS.r20),
        border: Border.all(color: _DS.border),
        boxShadow: [_DS.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCardHeader(
            title: 'Harga Sampah / Kg',
            onTap: () => Navigator.pushNamed(context, RouteConstants.userHarga),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Belum ada data harga.',
                style: TextStyle(color: _DS.textMuted, fontSize: 12.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Text('🗂️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.subJenis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'NunitoSans',
                              color: _DS.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _DS.textPrimary,
                              fontFamily: 'NunitoSans',
                            ),
                            children: [
                              TextSpan(text: 'Rp ${item.harga}'),
                              const TextSpan(
                                text: '/kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 10,
                                  color: _DS.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Aktivitas Terbaru Card (porting dari .aktivitas-list, sumber data =
// dashboard.recentOrders yang SUDAH ADA — logic tidak diubah, hanya UI ringkas)
class _AktivitasCard extends StatelessWidget {
  final DashboardProvider dashboard;
  const _AktivitasCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final orders = dashboard.recentOrders
        .where((o) => o.status != 'cancelled')
        .take(4)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: _DS.card,
        borderRadius: const BorderRadius.all(_DS.r20),
        border: Border.all(color: _DS.border),
        boxShadow: [_DS.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCardHeader(
            title: 'Aktivitas Terbaru',
            onTap: () => Navigator.pushNamed(context, RouteConstants.userHistory),
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Belum ada aktivitas.',
                style: TextStyle(color: _DS.textMuted, fontSize: 12.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: orders.map((order) {
                  final statusLabel = dashboard.getStatusLabel(order.status);
                  final statusColor =
                      Color(int.parse(dashboard.getStatusColor(order.status)));
                  final waktu = order.createdAt != null
                      ? DateFormat('dd MMM, HH:mm', 'id_ID')
                          .format(order.createdAt!)
                      : '-';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _DS.greenLight,
                            borderRadius: const BorderRadius.all(_DS.r12),
                          ),
                          child: const Center(
                            child: Text('🚛', style: TextStyle(fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${order.id}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _DS.textPrimary,
                                  fontFamily: 'NunitoSans',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                waktu,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: _DS.textMuted,
                                  fontFamily: 'NunitoSans',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: const BorderRadius.all(_DS.r999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Marketplace Card (porting dari section .marketplace web) ─────────────
class _MarketplaceCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MarketplaceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _DS.card,
          borderRadius: const BorderRadius.all(_DS.r20),
          border: Border.all(color: _DS.border),
          boxShadow: [_DS.shadowSm],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCardHeader(title: 'Marketplace', onTap: onTap),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Beli produk seperti beras, minyak, dan telur langsung dari marketplace menggunakan saldo tersedia Anda.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _DS.textMuted,
                  fontFamily: 'NunitoSans',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pickup Banner / CTA (sudah ada, dipertahankan) ────────────────────────
class _PickupBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PickupBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _DS.card,
            borderRadius: const BorderRadius.all(_DS.r20),
            border: Border.all(color: _DS.greenMid),
            boxShadow: [_DS.shadowSm],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _DS.greenLight,
                  borderRadius: const BorderRadius.all(_DS.r16),
                ),
                child: const Center(
                  child: Text('♻️', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jadwalkan Jemput Sampah Sekarang!',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans',
                        color: _DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pilih jenis sampah & jadwal penjemputan.',
                      style: TextStyle(
                        color: _DS.textMuted,
                        fontSize: 11.5,
                        fontFamily: 'NunitoSans',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _DS.greenLight,
                  borderRadius: BorderRadius.all(_DS.r12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: _DS.primary,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loading View (tidak diubah) ───────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerWidget.rectangular(
            height: 140,
            borderRadius: BorderRadius.all(_DS.r24),
          ),
          const SizedBox(height: 16),
          const ShimmerWidget.rectangular(
            height: 150,
            borderRadius: BorderRadius.all(_DS.r24),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: ShimmerWidget.rectangular(
                  height: 180,
                  borderRadius: BorderRadius.all(_DS.r20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ShimmerWidget.rectangular(
                  height: 180,
                  borderRadius: BorderRadius.all(_DS.r20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerWidget.rectangular(
            height: 100,
            borderRadius: BorderRadius.all(_DS.r20),
          ),
        ],
      ),
    );
  }
}

// ─── Error View (tidak diubah) ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Text('😵', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gagal Memuat Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                color: _DS.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: _DS.textMuted,
                fontSize: 14,
                fontFamily: 'NunitoSans',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(_DS.r999),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Muat Ulang',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'NunitoSans',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB (tidak diubah) ─────────────────────────────────────────────────────
class _FabPickup extends StatelessWidget {
  final VoidCallback onTap;
  const _FabPickup({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_DS.primaryDark, _DS.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [_DS.shadowGreen],
        ),
        child: const Center(child: Text('♻️', style: TextStyle(fontSize: 26))),
      ),
    );
  }
}

// ─── Bottom Nav (tidak diubah) ──────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onMarketplace;
  final VoidCallback onProfile;
  const _BottomNav({
    required this.onHistory,
    required this.onMarketplace,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: _DS.card,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: kBottomNavigationBarHeight + 8,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _DS.border, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Beranda',
                  isActive: true,
                  onTap: () {},
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Riwayat',
                  isActive: false,
                  onTap: onHistory,
                ),
                const SizedBox(width: 60),
                _NavItem(
                  icon: Icons.storefront_rounded,
                  label: 'Market',
                  isActive: false,
                  onTap: onMarketplace,
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  isActive: false,
                  onTap: onProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? _DS.primary : _DS.textMuted, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'NunitoSans',
                color: isActive ? _DS.primary : _DS.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}