import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String _backendBaseUrl = 'http://10.53.84.142:3000';

class TrackingPetugasPage extends StatefulWidget {
  final String username;
  final int orderId;

  const TrackingPetugasPage({
    super.key,
    required this.username,
    required this.orderId,
  });

  @override
  State<TrackingPetugasPage> createState() => _TrackingPetugasPageState();
}

class _TrackingPetugasPageState extends State<TrackingPetugasPage> {
  Position? _currentPosition;
  final MapController _mapController = MapController();
  Timer? _trackingTimer;
  LatLng? driverPosition;
  String? orderStatus;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _startTracking();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
  }

  void _startTracking() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final res = await http.get(
          Uri.parse('$_backendBaseUrl/tracking/${widget.orderId}'),
        );

        if (res.statusCode != 200) return;

        final data = jsonDecode(res.body);

        setState(() {
          orderStatus = data['status'] as String?;
        });

        if (data['location'] != null) {
          final lat = data['location']['lat'];
          final lng = data['location']['lng'];

          driverPosition = LatLng(lat, lng);

          if (driverPosition != null) {
            _mapController.move(driverPosition!, 16.0);
          }
        }
      } catch (e) {
        debugPrint('Error fetching tracking: $e');
      }
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Isi Build tetap sama dengan kode Anda sebelumnya
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.black),
        title: _buildUserHeader(),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'map',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: _currentPosition == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      center: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      zoom: 16.0,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        subdomains: const ['a', 'b', 'c'],
                                        tileProvider:
                                            const NetworkTileProvider(),
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          if (_currentPosition != null)
                                            Marker(
                                              point: LatLng(
                                                _currentPosition!.latitude,
                                                _currentPosition!.longitude,
                                              ),
                                              child: const Icon(
                                                Icons.location_pin,
                                                color: Colors.green,
                                                size: 40,
                                              ),
                                            ),
                                          if (driverPosition != null)
                                            Marker(
                                              point: driverPosition!,
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  'https://via.placeholder.com/80',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.person, size: 80),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  children: [
                                    _infoTile('budi sudarso'),
                                    const SizedBox(height: 8),
                                    _infoTile('No.Hp: 08123xxxxxx'),
                                    const SizedBox(height: 8),
                                    _infoTile('jarak: 1,2 Km'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              orderStatus == 'arrived'
                                  ? 'Petugas sudah sampai'
                                  : 'Petugas menuju Lokasi',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _actionButton(
                                'Chat',
                                Colors.white,
                                Colors.black,
                                border: true,
                              ),
                              _actionButton(
                                'Telepon',
                                Colors.green,
                                Colors.white,
                              ),
                              _actionButton(
                                'Batalkan orderan',
                                Colors.red.shade400,
                                Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- WIDGET HELPERS ---
  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                'Halo ${widget.username}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Text(
                'daur ulang sampahmu yuk!',
                style: TextStyle(fontSize: 8, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _actionButton(
    String label,
    Color bgColor,
    Color textColor, {
    bool border = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: border ? Border.all(color: Colors.green) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Icon(Icons.home, color: Colors.black),
          const Icon(Icons.assignment, color: Colors.grey),
          CircleAvatar(
            backgroundColor: Colors.green,
            child: const Icon(Icons.recycling, color: Colors.white, size: 25),
          ),
          const Icon(Icons.notifications_none, color: Colors.grey),
          const Icon(Icons.person_outline, color: Colors.grey),
        ],
      ),
    );
  }
}
