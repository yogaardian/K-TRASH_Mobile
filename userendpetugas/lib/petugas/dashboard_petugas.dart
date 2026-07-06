import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'models/order.dart';
import '../utils/secure_storage_helper.dart';
import '../services/api_service.dart';
import 'akun_page.dart';
import 'detail_order.dart';
import 'riwayat_page_petugas.dart';

const primaryColor = Color(0xFF4CAF50);

class DashboardPetugas extends StatefulWidget {
  final String nama;
  final int driverId;

  const DashboardPetugas({super.key, required this.nama, this.driverId = 1});

  @override
  State<DashboardPetugas> createState() => _DashboardPetugasState();
}

class _DashboardPetugasState extends State<DashboardPetugas> {
  int _selectedIndex = 0;
  bool isOnline = true;
  bool isLoading = true;
  bool _isFetching = false;
  String? errorMessage;

  List<Order> orders = [];
  Order? activeOrder;
  LatLng? activeOrderLocation;
  final Map<int, LatLng> _orderLocations = {};

  LatLng driverLocation = const LatLng(-7.8, 110.3);
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();

  Timer? _timer;
  int? _driverId;
  String? _driverName;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    _loadDriverInfo();
    _fetchOrders();
    _startPolling();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      if (await Geolocator.isLocationServiceEnabled()) {
        _startPositionStream();
      } else {
        setState(() {
          errorMessage = 'GPS tidak aktif';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error lokasi: $e';
      });
    }
  }

  void _startPositionStream() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              driverLocation = LatLng(position.latitude, position.longitude);
            });
            _mapController.move(driverLocation, _mapController.camera.zoom);
            if (activeOrder != null) {
              _sendLocationToBackend();
            }
          }
        });
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isOnline) {
        _fetchOrders();
      }
    });
  }

  Future<void> _loadDriverInfo() async {
    try {
      final userJson = await SecureStorageHelper.getUserData();
      if (userJson != null) {
        final parsed = _parseStoredUserData(userJson);
        if (parsed != null) {
          setState(() {
            _driverId = parsed['id'] is int ? parsed['id'] as int : int.tryParse('${parsed['id']}');
            _driverName = parsed['nama'] ?? parsed['name']?.toString();
          });
        }
      }
    } catch (_) {
      // ignore parsing errors
    }
  }

  Map<String, dynamic>? _parseStoredUserData(String userJson) {
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } on FormatException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchOrders() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final token = await SecureStorageHelper.getToken();
      final decoded = await ApiService.getPendingOrders(token);

      final newOrders = <Order>[];
      final newLocations = <int, LatLng>{};

      for (final item in decoded) {
        if (item is! Map) continue;

        final orderId = item['id'];
        if (orderId is! int) continue;

        final lat = item['user_lat'];
        final lng = item['user_lng'];

        if (lat is num && lng is num) {
          newLocations[orderId] = LatLng(lat.toDouble(), lng.toDouble());
        }

        newOrders.add(
          Order(
            id: orderId,
            nama: 'User ${item['user_id'] ?? ''}',
            alamat: item['address']?.toString() ?? 'Alamat tidak tersedia',
            code: orderId.toString(),
            jenisSampah: item['jenis_sampah']?.toString(),
            catatan: item['catatan']?.toString(),
          ),
        );
      }

      if (!mounted) return;

      if (!_sameOrders(orders, newOrders)) {
        setState(() {
          orders = newOrders;
          _orderLocations
            ..clear()
            ..addAll(newLocations);
          errorMessage = null;
        });
      } else {
        _orderLocations
          ..clear()
          ..addAll(newLocations);
      }

      if (isLoading) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Gagal memuat order: $e';
        isLoading = false;
      });
    } finally {
      _isFetching = false;
    }
  }

  bool _sameOrders(List<Order> oldList, List<Order> newList) {
    if (oldList.length != newList.length) return false;
    for (var i = 0; i < oldList.length; i++) {
      final old = oldList[i];
      final neo = newList[i];
      if (old.id != neo.id ||
          old.nama != neo.nama ||
          old.alamat != neo.alamat ||
          old.code != neo.code ||
          old.jenisSampah != neo.jenisSampah ||
          old.catatan != neo.catatan) {
        return false;
      }
    }
    return true;
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      final token = await SecureStorageHelper.getToken();
      final data = await ApiService.acceptOrder(order.id!, _driverId ?? widget.driverId, token);
      if (data['status'] == 'success') {
        setState(() {
          activeOrder = order;
          activeOrderLocation =
              _orderLocations[order.id!] ?? const LatLng(-7.7, 110.35);
          orders.removeWhere((element) => element.id == order.id);
          errorMessage = null;
        });
        _sendLocationToBackend();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailOrderPage(
              order: activeOrder!,
              driverId: _driverId ?? widget.driverId,
            ),
          ),
        );
        return;
      }

      setState(() {
        errorMessage = data['message']?.toString() ?? 'Gagal menerima order';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Gagal menerima order: $e';
      });
    }
  }

  void _rejectOrder(Order order) {
    () async {
      try {
        final token = await SecureStorageHelper.getToken();
        await ApiService.rejectOrder(order.id!, _driverId ?? widget.driverId, token);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        orders.removeWhere((element) => element.id == order.id);
      });
    }();
  }

  Future<void> _viewOrderDetail(Order order) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailOrderPage(
          order: order,
          driverId: _driverId ?? widget.driverId,
        ),
      ),
    );
  }

  Future<void> _sendLocationToBackend() async {
    if (activeOrder == null) return;

    try {
      final token = await SecureStorageHelper.getToken();
      await ApiService.sendDriverLocation(
        _driverId ?? widget.driverId,
        activeOrder!.id!,
        driverLocation.latitude,
        driverLocation.longitude,
        token,
      );
    } catch (_) {
      // Handle silently
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: buildMap(),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: buildOrderSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const RiwayatPage(),
          const AkunPage(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 2),
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName ?? widget.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Petugas BankTrash',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white30,
                value: isOnline,
                onChanged: (value) {
                  setState(() {
                    isOnline = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMap() {
    return activeOrder == null ? buildDriverMap() : buildTrackingMap();
  }

  Widget buildDriverMap() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: driverLocation, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.banktrash.app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: driverLocation,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTrackingMap() {
    final orderPoint = activeOrderLocation ?? const LatLng(-7.7, 110.35);
    final center = _centerBetween(driverLocation, orderPoint);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.banktrash.app',
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [driverLocation, orderPoint],
                  color: Colors.green,
                  strokeWidth: 4,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: driverLocation,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                Marker(
                  width: 40,
                  height: 40,
                  point: orderPoint,
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
    );
  }

  LatLng _centerBetween(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  Widget buildOrderSection() {
    if (activeOrder != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Active Order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          buildActiveOrderCard(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pending Orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (orders.isEmpty)
          const Center(child: Text('Tidak ada order pending'))
        else
          ...orders.map(
            (order) => OrderCard(
              order: order,
              isOnline: isOnline,
              onTolak: () => _rejectOrder(order),
              onTerima: () => _acceptOrder(order),
              onDetail: () => _viewOrderDetail(order),
            ),
          ),
      ],
    );
  }

  Widget buildActiveOrderCard() {
    final order = activeOrder!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor,
                child: Text(
                  order.nama[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(order.alamat),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Kode Order', order.code),
          _infoRow('Jenis Sampah', order.jenisSampah ?? 'Tidak tersedia'),
          _infoRow('Catatan', order.catatan ?? 'Tidak ada'),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              if (activeOrder != null) {
                _viewOrderDetail(activeOrder!);
              }
            },
            child: const Text('Lihat Detail'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final bool isOnline;
  final VoidCallback onTolak;
  final VoidCallback onTerima;
  final VoidCallback onDetail;

  const OrderCard({
    super.key,
    required this.order,
    required this.isOnline,
    required this.onTolak,
    required this.onTerima,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor,
                child: Text(
                  order.nama[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(order.alamat),
                    const SizedBox(height: 4),
                    Text(
                      'Kode: ${order.code}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTolak,
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isOnline ? onTerima : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnline ? primaryColor : Colors.grey,
                  ),
                  child: const Text('Terima'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



