import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';

import 'customer_search_page.dart';

final String _backendBaseUrl = ApiConstants.baseUrl;

class DriverJourneyPage extends StatefulWidget {
  final int driverId;
  final int orderId;

  const DriverJourneyPage({
    super.key,
    required this.driverId,
    required this.orderId,
  });

  @override
  State<DriverJourneyPage> createState() => _DriverJourneyPageState();
}

class _DriverJourneyPageState extends State<DriverJourneyPage> {
  Timer? _locationTimer;
  Position? _currentPosition;
  String _orderStatus = 'assigned';
  String? _message;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _startDriverWorkflow();
  }

  Future<void> _startDriverWorkflow() async {
    await _requestLocationPermission();
    await _updateOrderStatus('on_the_way');
    _startLocationTimer();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _message = 'Layanan lokasi tidak aktif. Aktifkan GPS.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _message = 'Izin lokasi ditolak. Tidak dapat mengirim lokasi.';
      });
    }
  }

  void _startLocationTimer() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendLocation();
    });
  }

  Future<void> _sendLocation() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = position;

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/driver/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': widget.driverId,
          'order_id': widget.orderId,
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || data['status'] == 'fail') {
        setState(() {
          _message = data['message'] ?? 'Gagal mengirim lokasi';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error saat mengirim lokasi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$_backendBaseUrl/orders/status/${widget.orderId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driver_id': widget.driverId,
          'status': newStatus,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _orderStatus = newStatus;
          _message = 'Status diperbarui: $newStatus';
        });
      } else {
        setState(() {
          _message = data['message'] ?? 'Gagal memperbarui status';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error status: $e';
      });
    }
  }

  void _markAsArrived() async {
    await _updateOrderStatus('arrived');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerSearchPage(
          driverId: widget.driverId,
          orderId: widget.orderId,
        ),
      ),
    );
  }

  void _completeOrder() async {
    await _updateOrderStatus('completed');
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F1F1),
      appBar: AppBar(
        title: const Text('Perjalanan Driver'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Order ID', widget.orderId.toString()),
                  const SizedBox(height: 12),
                  _buildInfoRow('Driver ID', widget.driverId.toString()),
                  const SizedBox(height: 12),
                  _buildInfoRow('Status Order', _orderStatus),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi Saat Ini',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              const Text('Menunggu lokasi GPS...'),
            const SizedBox(height: 8),
            if (_isSending)
              const Text(
                'Mengirim lokasi...',
                style: TextStyle(color: Colors.orange),
              ),
            const SizedBox(height: 8),
            if (_message != null)
              Text(
                _message!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _currentPosition != null ? _markAsArrived : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Tandai Tiba di Lokasi'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _completeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Selesaikan Order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
