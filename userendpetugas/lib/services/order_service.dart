import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../shared/models/order_model.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();

  final ApiClient _apiClient = ApiClient();

  OrderService._internal();

  factory OrderService() {
    return _instance;
  }

  /// Get list of user orders
  /// Endpoint: GET /orders/user/:id
  Future<List<OrderModel>> getUserOrders(int userId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.getUserOrdersEndpoint}/$userId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Handle both array and object responses
        List<dynamic> orderList = [];
        if (data is List) {
          orderList = data;
        } else if (data is Map<String, dynamic>) {
          // If response is an object with 'data' or 'orders' key
          orderList = data['data'] ?? data['orders'] ?? [];
        }

        return orderList
            .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch user orders');
    } on DioException catch (e) {
      throw Exception('Error fetching orders: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get specific order by ID
  /// Endpoint: GET /orders/:id
  Future<OrderModel> getOrderById(int orderId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.getOrderDetailEndpoint}/$orderId',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return OrderModel.fromJson(data);
      }

      throw Exception('Failed to fetch order');
    } on DioException catch (e) {
      throw Exception('Error fetching order: ${_getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Create a new order
  /// Endpoint: POST /orders
  Future<OrderModel> createOrder(Map<String, dynamic> payload) async {
    try {
      // DEBUG: Log HTTP request
      print('[HTTP] POST ${ApiConstants.createOrderEndpoint}');
      print('[PAYLOAD] $payload');
      
      final response = await _apiClient.post(
        ApiConstants.createOrderEndpoint,
        data: payload,
      );

      // DEBUG: Log HTTP response
      print('[HTTP_RESPONSE] Status: ${response.statusCode}');
      print('[RESPONSE_DATA] ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // Handle direct order object, nested order key, or order_id only response
        if (data.containsKey('order_id')) {
          final orderId = (data['order_id'] as num).toInt();
          print('[ORDER_CREATED] order_id received: $orderId');
          print('[ORDER_FETCH] GET ${ApiConstants.getOrderDetailEndpoint}/$orderId');
          final order = await getOrderById(orderId);
          print('[ORDER_FETCH_RESPONSE] $order');
          return order;
        }

        final orderData = data['order'] ?? data;
        final order = OrderModel.fromJson(orderData as Map<String, dynamic>);
        
        print('[ORDER_CREATED] ID: ${order.id}, Status: ${order.status}');
        
        return order;
      }

      throw Exception('Failed to create order');
    } on DioException catch (e) {
      print('[HTTP_ERROR] ${e.message}');
      print('[ERROR_RESPONSE] ${e.response?.data}');
      throw Exception('Error creating order: ${_getErrorMessage(e)}');
    } catch (e) {
      print('[UNEXPECTED_ERROR] $e');
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get recent orders for dashboard (limit 5)
  /// Endpoint: GET /orders/user/:id
  Future<List<OrderModel>> getRecentOrders(int userId, {int limit = 5}) async {
    try {
      final orders = await getUserOrders(userId);
      // Sort by created_at descending and take first `limit` items
      orders.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      return orders.take(limit).toList();
    } catch (e) {
      throw Exception('Error fetching recent orders: $e');
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else if (e.type == DioExceptionType.badResponse) {
      return 'Server error: ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.unknown) {
      return 'Network error: ${e.message}';
    }
    return 'Unknown error';
  }
}
