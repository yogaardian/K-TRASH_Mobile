import 'package:flutter/material.dart';

class OrderDetailPage extends StatelessWidget {
  final int? orderId;

  const OrderDetailPage({Key? key, this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: Center(
        child: Text('Order Detail Page (Order: $orderId) - To be implemented'),
      ),
    );
  }
}
