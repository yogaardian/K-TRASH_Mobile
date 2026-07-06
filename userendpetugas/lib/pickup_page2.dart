import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'pilih_sampah_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PickupPage extends StatefulWidget {
  final String username; // Menambahkan variabel untuk nama user

  const PickupPage({super.key, required this.username});

  @override
  State<PickupPage> createState() => _PickupPageState();
}

class _PickupPageState extends State<PickupPage> {
  final TextEditingController alamatController = TextEditingController();
  final TextEditingController catatanController = TextEditingController();

  Position? _currentPosition;
  String? _currentAddress;
  bool _isLocating = false;
  final MapController _mapController = MapController();

  // 🔥 TAMBAHKAN INI
  String? selectedKecamatan;
  String? selectedDesa;

  // 🔥 TAMBAHKAN INI JUGA
  Map<String, List<String>> dataNgawi = {
    "Pangkur": ["Pangkur", "Bendo", "Cengkok", "Gandri"],
    "Karangjati": ["Karangjati", "Campurasri", "Danguk"],
    "Geneng": ["Geneng", "Kedunggalar", "Ngrambe"],
    "Wonoasri": ["Wonoasri", "Purwosari", "Buduran", "Klitik"],
  };

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLocating = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _isLocating = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });

    await _getAddressFromLatLng(position);
    await _moveCamera();
    setState(() => _isLocating = false);
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _currentAddress = address;
          if (alamatController.text.isEmpty) {
            alamatController.text = address;
          }
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  Future<void> _moveCamera() async {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    }
  }

  @override
  void dispose() {
    alamatController.dispose();
    catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.green),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo ${widget.username}', // Mengikuti nama user login
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'daur ulang sampahmu yuk!',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipe Pengangkutan Sampahmu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFD1E4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    color: Colors.blue,
                    size: 40,
                  ),
                  const SizedBox(width: 15),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jemput Sampah',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Petugas kami menjemput sampahmu',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lokasi Penjemputan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: alamatController, // Menghubungkan ke controller
                    decoration: InputDecoration(
                      hintText: 'masukkan alamat mu',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.search, color: Colors.black),
                const SizedBox(width: 10),
                const Icon(Icons.my_location, color: Colors.black),
              ],
            ),
            const SizedBox(height: 15),
            // 🔽 KECAMATAN
            DropdownButton<String>(
              hint: Text("Pilih Kecamatan"),
              value: selectedKecamatan,
              isExpanded: true,
              items: dataNgawi.keys.map((kec) {
                return DropdownMenuItem(value: kec, child: Text(kec));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedKecamatan = value;
                  selectedDesa = null;
                });
              },
            ),

            const SizedBox(height: 10),

            // 🔽 DESA
            DropdownButton<String>(
              hint: Text("Pilih Desa"),
              value: selectedDesa,
              isExpanded: true,
              items: selectedKecamatan == null
                  ? []
                  : dataNgawi[selectedKecamatan]!.map((desa) {
                      return DropdownMenuItem(value: desa, child: Text(desa));
                    }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDesa = value;

                  // 🔥 AUTO ISI ALAMAT
                  if (selectedDesa != null && selectedKecamatan != null) {
                    alamatController.text =
                        "$selectedDesa, $selectedKecamatan, Ngawi";
                  }
                });
              },
            ),
            // PETA DAN LOKASI OTOMATIS
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _currentPosition == null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey.shade200),
                          if (_isLocating)
                            const Center(child: CircularProgressIndicator())
                          else
                            const Center(
                              child: Icon(
                                Icons.location_searching,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 16.0,
                          onMapReady: () {
                            _moveCamera();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            tileProvider: NetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
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
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _determinePosition,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Gunakan Lokasi Saat Ini'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_currentAddress != null) ...[
              const SizedBox(height: 10),
              Text(
                'Alamat terdeteksi: $_currentAddress',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 20),
                SizedBox(width: 10),
                Text(
                  'Catatan untuk petugas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: catatanController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Detail Lainnya (Cth: Blok / Unit., Patokan)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: const Text(
                      'cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final selectedAlamat = alamatController.text;
                      final selectedCatatan = catatanController.text;
                      final navigator = Navigator.of(context);
                      if (!mounted) return;

                      final prefs = await SharedPreferences.getInstance();
                      final uid = prefs.getInt('userId');
                      final token = prefs.getString('token');
                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => PilihSampahPage(
                            username: widget.username,
                            alamat: selectedAlamat,
                            catatan: selectedCatatan,
                            userLat: _currentPosition?.latitude,
                            userLng: _currentPosition?.longitude,
                            userId: uid,
                            token: token,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'berikutnya',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
