import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/shared/models/waste_item_model.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';

// Brand gradient — disamakan dengan `BRAND_GRADIENT` di website
// linear-gradient(135deg, rgb(102,178,130) 0%, rgb(21,128,61) 60%, rgb(20,83,45) 100%)
const _kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF66B282),
    Color(0xFF15803D),
    Color(0xFF14532D),
  ],
  stops: [0.0, 0.6, 1.0],
);

const _kDarkGreen = Color(0xFF1E4D2B);
const _kBorderGreen = Color(0xFFC8DFC8);
const _kCardBlue = Color(0xFFDBEAFE);
const _kLabelBlue = Color(0xFF1E3A5F);

class SelectWastePage extends StatefulWidget {
  final int? orderId;

  const SelectWastePage({Key? key, this.orderId}) : super(key: key);

  @override
  State<SelectWastePage> createState() => _SelectWastePageState();
}

class _SelectWastePageState extends State<SelectWastePage> {
  // Waste categories - EXACTLY 3 categories (logic tidak diubah)
  final List<WasteItemModel> _availableWaste = [
    WasteItemModel(id: 1, name: 'organik'),
    WasteItemModel(id: 2, name: 'anorganik'),
    WasteItemModel(id: 3, name: 'lainnya'),
  ];

  late OrderProvider _provider;
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<OrderProvider>();
  }

  /// Get display text for category (mengikuti format website)
  String _getCategoryDisplayText(String categoryCode) {
    const displayMap = {
      'organik': 'Sampah Organik',
      'anorganik': 'Sampah Anorganik',
      'lainnya': 'Sampah Lainnya',
    };
    return displayMap[categoryCode] ?? categoryCode;
  }

  // NOTE: sesuaikan field ini dengan model User Anda yang sebenarnya
  // (mis. user.name / user.username / user.fullName).
  String _getUsername(AuthProvider authProvider) {
    try {
      final user = authProvider.user;
      if (user == null) return 'User';
      final dynamic dynamicUser = user;
      final name = dynamicUser.name;
      if (name is String && name.isNotEmpty) return name;
    } catch (_) {
      // field 'name' tidak tersedia pada model User — fallback ke default
    }
    return 'User';
  }

  void _proceedToCreateOrderAndFindDriver() async {
    if (_provider.selectedWaste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu jenis sampah')),
      );
      return;
    }

    // Get auth provider for user ID
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User tidak ditemukan')));
      return;
    }

    setState(() => _isCreatingOrder = true);

    // Create order (logic tidak diubah)
    final success = await _provider.createOrder(authProvider.user!.id);

    if (!mounted) return;

    setState(() => _isCreatingOrder = false);

    if (success && _provider.currentOrder != null) {
      // Order created successfully, now go to find driver page
      Navigator.pushNamed(context, '/find-driver');
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_provider.errorMessage ?? 'Gagal membuat pesanan'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final username = _getUsername(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeroHeader(username),
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, provider, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSectionLabel('📍 Alamat Penjemputan'),
                        const SizedBox(height: 8),
                        _buildAddressCard(provider.address),
                        const SizedBox(height: 24),

                        const Center(
                          child: Text(
                            'Pilih Jenis Sampahmu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _kDarkGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Waste items list - EXACTLY 3 categories
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableWaste.length,
                          itemBuilder: (context, index) {
                            final waste = _availableWaste[index];
                            final selected = provider.selectedWaste.firstWhere(
                              (w) => w.id == waste.id,
                              orElse: () => WasteItemModel(id: -1, name: ''),
                            );
                            final isSelected = selected.id != -1;

                            return _buildCategoryItem(
                              _getCategoryDisplayText(waste.name),
                              isSelected,
                              (val) {
                                if (val ?? false) {
                                  provider.addWasteItem(waste);
                                } else {
                                  provider.removeWasteItem(waste.id);
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildSectionLabel('📝 Catatan Untuk Sampah Lainnya'),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Tambahkan catatan (opsional)',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _kBorderGreen,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _kBorderGreen,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                          onChanged: (value) => _provider.updateNotes(value),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 28),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildCancelButton(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildNextButton(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(String username) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(gradient: _kBrandGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Halo $username 👋',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Daur ulang sampahmu yuk!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, color: _kDarkGreen),
    );
  }

  Widget _buildAddressCard(String address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E8D4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, color: Color(0xFF15803D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address.isNotEmpty ? address : 'Alamat tidak diketahui',
              style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    String title,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kCardBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Color(0xFF15803D), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _kLabelBlue,
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

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _isCreatingOrder ? null : () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF15803D)),
        foregroundColor: const Color(0xFF15803D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: const Text(
        'Batal',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNextButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(gradient: _kBrandGradient),
          child: InkWell(
            onTap: _isCreatingOrder ? null : _proceedToCreateOrderAndFindDriver,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: _isCreatingOrder
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Berikutnya →',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}