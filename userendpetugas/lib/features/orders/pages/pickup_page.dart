import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Design Tokens
/// Ported 1:1 from the website's `T` token object (src: PickupPage.jsx)
/// so that colors / radii / shadows stay visually identical across
/// platforms. Nothing here touches business logic.
/// ────────────────────────────────────────────────────────────────────────
class _T {
  static const Color green900 = Color(0xFF052E16);
  static const Color green400 = Colors.white;
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color bg = Color(0xFFF5F7F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0x2622C55E); // rgba(34,197,94,0.15)
  static const Color borderStrong = Color(0x4D22C55E); // rgba(34,197,94,0.30)
  static const Color text = Color(0xFF0F172A);
  static const Color textSoft = Color(0xFF64748B);
  static const Color textXSoft = Color(0xFF94A3B8);
  static const Color greenAccent = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF15803D);

  static const double radius = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;

  static const LinearGradient gradientBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66B282), Color(0xFF15803D), Color(0xFF14532D)],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient gradientLoading = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
  );

  static List<BoxShadow> shadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: greenAccent.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: greenAccent.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: greenAccent.withOpacity(0.16),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
}

class PickupPage extends StatefulWidget {
  const PickupPage({Key? key}) : super(key: key);

  @override
  State<PickupPage> createState() => _PickupPageState();
}

class _PickupPageState extends State<PickupPage> {
  // ── Original state (UNCHANGED — logic parity with previous Flutter code) ──
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(-6.8915, 111.4944);

  double? _selectedLat;
  double? _selectedLng;
  bool _isLocating = false;
  String? _locationMessage;
  String? _currentAddress;

  // Data untuk kecamatan dan desa (kept exactly as-is; the website source
  // also declares this map but never renders a Kecamatan selector, so the
  // Desa dropdown here is intentionally guarded the same way it was
  // originally — see Gap Analysis note #4 in the chat response).
  String? selectedKecamatan;
  String? selectedDesa;

  Map<String, List<String>> dataNgawi = {
    "Pangkur": ["Pangkur", "Bendo", "Cengkok", "Gandri"],
    "Karangjati": ["Karangjati", "Campurasri", "Danguk"],
    "Geneng": ["Geneng", "Kedunggalar", "Ngrambe"],
    "Wonoasri": ["Wonoasri", "Purwosari", "Buduran", "Klitik"],
  };

  @override
  void initState() {
    super.initState();
    final provider = context.read<OrderProvider>();
    _addressController = TextEditingController(text: provider.address);
    _notesController = TextEditingController(text: provider.notes);
    _selectedLat = provider.pickupLat;
    _selectedLng = provider.pickupLng;

    if (_selectedLat != null && _selectedLng != null) {
      _mapCenter = LatLng(_selectedLat!, _selectedLng!);
      _currentAddress = provider.address.isNotEmpty ? provider.address : null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationMessage = 'Layanan lokasi belum aktif';
          _isLocating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Izin lokasi ditolak';
          _isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _setLocation(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationMessage = 'Gagal mendapatkan lokasi: $e';
      });
    } finally {
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _setLocation(double lat, double lng) async {
    _selectedLat = lat;
    _selectedLng = lng;
    _mapCenter = LatLng(lat, lng);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_mapCenter, 16);
    });

    await _reverseGeocode(lat, lng);
    setState(() {});
  }

  String _buildStreetAddress(Map<String, dynamic> payload) {
    final displayName = payload['display_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      final cleanedDisplayName = displayName
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanedDisplayName.isNotEmpty &&
          cleanedDisplayName.toLowerCase() != 'caruban') {
        return cleanedDisplayName;
      }
    }

    final addressData = payload['address'];
    if (addressData is Map<String, dynamic>) {
      final parts = <String>[];

      void addIfPresent(String? value) {
        if (value != null && value.trim().isNotEmpty) {
          parts.add(value.trim());
        }
      }

      addIfPresent(addressData['house_number'] as String?);
      addIfPresent(addressData['road'] as String?);
      addIfPresent(addressData['path'] as String?);
      addIfPresent(addressData['residential'] as String?);
      addIfPresent(addressData['neighbourhood'] as String?);
      addIfPresent(addressData['hamlet'] as String?);
      addIfPresent(addressData['suburb'] as String?);
      addIfPresent(addressData['village'] as String?);
      addIfPresent(addressData['town'] as String?);
      addIfPresent(addressData['city'] as String?);
      addIfPresent(addressData['county'] as String?);
      addIfPresent(addressData['state_district'] as String?);
      addIfPresent(addressData['state'] as String?);
      addIfPresent(addressData['postcode'] as String?);
      addIfPresent(addressData['country'] as String?);

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }

    return 'Jalan sekitar lokasi';
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() {
      _locationMessage = null;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'K-TRASH/1.0 (example@example.com)'},
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final address = _buildStreetAddress(payload);
        _addressController.text = address;
        _currentAddress = address;
      } else {
        _addressController.text = 'Jalan sekitar lokasi';
        _currentAddress = 'Jalan sekitar lokasi';
      }
    } catch (e) {
      _addressController.text = 'Jalan sekitar lokasi';
      _currentAddress = 'Jalan sekitar lokasi';
    }
  }

  void _proceedToSelectWaste() {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat tidak boleh kosong')),
      );
      return;
    }

    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lokasi pickup terlebih dahulu')),
      );
      return;
    }

    final provider = context.read<OrderProvider>();
    provider.setPickupLocation(
      latitude: _selectedLat!,
      longitude: _selectedLng!,
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
    );

    Navigator.pushNamed(context, '/select-waste');
  }

  // ── UI (ported from website PickupPage.jsx) ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('TIPE PENGANGKUTAN'),
                    const SizedBox(height: 8),
                    _buildServiceCard(),
                    const SizedBox(height: 20),
                    _sectionLabel('LOKASI PENJEMPUTAN'),
                    const SizedBox(height: 8),
                    _buildAddressCard(),
                    const SizedBox(height: 12),
                    if (selectedKecamatan != null) ...[
                      _buildDesaDropdown(),
                      const SizedBox(height: 12),
                    ],
                    _buildMapSection(),
                    const SizedBox(height: 14),
                    _buildGpsButton(),
                    if (_locationMessage != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _locationMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    _sectionLabel('CATATAN TAMBAHAN'),
                    const SizedBox(height: 8),
                    _buildNotesCard(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(context),
    );
  }

  // ── Sticky header (avatar / greeting / back button) ─────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _T.surface.withOpacity(0.85),
        border: Border(bottom: BorderSide(color: _T.border, width: 1)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _T.surface,
                shape: BoxShape.circle,
                border: Border.all(color: _T.borderStrong, width: 1.5),
                boxShadow: _T.shadow,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: _T.greenDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _T.green50,
              border: Border.all(color: Colors.white, width: 2),
            ),
            clipBehavior: Clip.hardEdge,
            child: const Icon(Icons.person, color: _T.greenDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Halo, User 👋',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _T.text,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'daur ulang sampahmu yuk!',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _T.textSoft,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.phone_in_talk_outlined, color: _T.text),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, color: _T.text),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _T.textXSoft,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Service type card ────────────────────────────────────────────────────
  Widget _buildServiceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radiusLg),
        border: Border.all(color: _T.borderStrong, width: 1.5),
        boxShadow: _T.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: _T.gradientBtn,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Jemput Sampah',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _T.text,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Petugas kami menjemput sampahmu',
                  style: TextStyle(fontSize: 12, color: _T.textSoft),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _T.green100,
              border: Border.all(color: _T.borderStrong, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AKTIF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _T.greenDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Address input card ───────────────────────────────────────────────────
  // NOTE: The website exposes an *editable* Alamat field bound directly to
  // the same address state used for validation/submission. The previous
  // Flutter build only rendered a read-only lat/lng row and a separate
  // read-only address line. To match the website UX (and because it is
  // strictly better UX — user can correct a wrong reverse-geocoded address)
  // this is ported as a TextField bound to the *same* `_addressController`
  // that already existed and was already used for validation + the API
  // payload. No new controller, no new business logic — just exposing an
  // existing controller in the UI.
  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radiusLg),
        border: Border.all(color: _T.border, width: 1.5),
        boxShadow: _T.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 2),
            child: Text(
              'ALAMAT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _T.greenDark,
                letterSpacing: 0.8,
              ),
            ),
          ),
          TextField(
            controller: _addressController,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _T.text,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'masukkan alamat mu...',
              contentPadding: EdgeInsets.only(bottom: 12, top: 4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Kecamatan/Desa dropdown ──────────────────────────────────────────────
  // Preserved from the original Flutter implementation. In current logic
  // `selectedKecamatan` is never assigned (there is no Kecamatan selector in
  // either source), so this branch does not render today — kept as-is since
  // removing it would be a logic change and the website source shows the
  // same dormant selectedKecamatan/selectedDesa state without a rendered
  // selector either.
  Widget _buildDesaDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radiusLg),
        border: Border.all(color: _T.border, width: 1.5),
        boxShadow: _T.shadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDesa,
          hint: const Text('Pilih Desa'),
          isExpanded: true,
          items: (dataNgawi[selectedKecamatan] ?? [])
              .map((desa) => DropdownMenuItem(value: desa, child: Text(desa)))
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedDesa = val;
              if (selectedKecamatan != null && selectedDesa != null) {
                _addressController.text =
                    '$selectedDesa, $selectedKecamatan, Ngawi';
              }
            });
          },
        ),
      ),
    );
  }

  // ── Map section (card + floating GPS/coordinate chips) ──────────────────
  Widget _buildMapSection() {
    final hasLocation = _selectedLat != null && _selectedLng != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_T.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_T.radiusXl),
          border: Border.all(color: _T.borderStrong, width: 1.5),
          boxShadow: _T.shadowLg,
          color: const Color(0xFFE8F5E9),
        ),
        child: (_isLocating && !hasLocation)
            ? Container(
                height: 240,
                alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: _T.gradientLoading),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(_T.greenAccent),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Mendeteksi lokasi GPS…',
                      style: TextStyle(
                        fontSize: 13,
                        color: _T.textSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  SizedBox(
                    height: 240,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: 13,
                        minZoom: 5,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        if (hasLocation)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: LatLng(_selectedLat!, _selectedLng!),
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (_isLocating)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: _T.surface.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GpsDot(),
                              SizedBox(width: 6),
                              Text(
                                'GPS Aktif',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF14532D),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasLocation)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _T.green900.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                '${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── GPS refresh button ───────────────────────────────────────────────────
  Widget _buildGpsButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLocating ? null : _determinePosition,
        style: OutlinedButton.styleFrom(
          backgroundColor: _T.surface,
          side: const BorderSide(color: _T.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.radius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GpsDot(size: 8),
            const SizedBox(width: 8),
            Text(
              _isLocating ? 'Mendeteksi Lokasi…' : 'Gunakan Lokasi Saat Ini',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _T.greenDark,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notes card ────────────────────────────────────────────────────────────
  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.radiusLg),
        border: Border.all(color: _T.border, width: 1.5),
        boxShadow: _T.shadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              ),
              border: Border(bottom: BorderSide(color: _T.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _T.greenAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sticky_note_2_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Catatan untuk Petugas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _T.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Blok / Unit, Patokan, dll.',
                      style: TextStyle(fontSize: 11, color: _T.textSoft),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: _T.text, height: 1.5),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Contoh: Blok A No. 12, dekat warung merah…',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky bottom action bar ─────────────────────────────────────────────
  Widget _buildActionBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _T.surface.withOpacity(0.92),
          border: Border(top: BorderSide(color: _T.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: _T.greenAccent.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _T.surface,
                    side: const BorderSide(color: _T.borderStrong, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_T.radius),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _T.greenDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _T.gradientBtn,
                    borderRadius: BorderRadius.circular(_T.radius),
                    boxShadow: [
                      BoxShadow(
                        color: _T.greenAccent.withOpacity(0.40),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_T.radius),
                      onTap: _proceedToSelectWaste,
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Berikutnya',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pulsing GPS indicator dot used in the GPS button and map overlay.
class _GpsDot extends StatelessWidget {
  final double size;
  const _GpsDot({this.size = 8, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _T.greenAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _T.greenAccent.withOpacity(0.3),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}
