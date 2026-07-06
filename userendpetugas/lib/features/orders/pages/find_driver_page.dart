import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user/constants/route_constants.dart';
import 'package:user/services/order_service.dart';
import '../providers/order_provider.dart';

class FindDriverPage extends StatefulWidget {
  final int? orderId;

  const FindDriverPage({Key? key, this.orderId}) : super(key: key);

  @override
  State<FindDriverPage> createState() => _FindDriverPageState();
}

class _FindDriverPageState extends State<FindDriverPage> {
  late Timer _pollingTimer;
  String? _errorMessage;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer.cancel();
    super.dispose();
  }

  void _startPolling() {
    final orderProvider = context.read<OrderProvider>();
    final currentOrder = orderProvider.currentOrder;

    if (currentOrder == null) {
      setState(() {
        _errorMessage = 'Order tidak ditemukan';
      });
      return;
    }

    // Poll every 3 seconds like React
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final updatedOrder = await _orderService.getOrderById(currentOrder.id);

        if (!mounted) return;

        print('[POLLING] Order status: ${updatedOrder.status}');

        // Update provider with new order data
        orderProvider.setCurrentOrder(updatedOrder);

        // Check if driver accepted
        if ([
          'assigned',
          'on_the_way',
          'arrived',
        ].contains(updatedOrder.status)) {
          _pollingTimer.cancel();
          if (mounted) {
            // Show "Driver Found" message
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Petugas Ditemukan!')));
            // Navigate to result page
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteConstants.trackingPage,
                  (route) =>
                      route.settings.name == '/dashboard' || route.isFirst,
                  arguments: updatedOrder.id,
                );
              }
            });
          }
          return;
        }

        // Check if order was cancelled
        if (['cancelled', 'completed'].contains(updatedOrder.status)) {
          _pollingTimer.cancel();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => route.isFirst,
            );
          }
          return;
        }
      } catch (e) {
        print('[POLLING_ERROR] $e');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error polling order status';
        });
      }
    });
  }

  void _cancelOrder() async {
    final orderProvider = context.read<OrderProvider>();
    final currentOrder = orderProvider.currentOrder;

    if (currentOrder == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order tidak ditemukan')));
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _pollingTimer.cancel();
              // Navigate back to dashboard
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (route) => route.isFirst,
              );
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9F1),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: const Color(0xFFB4BCB4),
              child: const Column(
                children: [
                  Text(
                    'Mencari Petugas Terdekat .....',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Mohon tunggu',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Loading Animation Container
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Loading..',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Information Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Kami sedang mencari petugas yang tersedia di sekitar anda .',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),

            // Error message if any
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[400]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const Spacer(),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: ElevatedButton(
                onPressed: _cancelOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 12,
                  ),
                ),
                child: const Text('Batalkan', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
