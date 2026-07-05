import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';

class ApiService {
  static String get baseUrl => ApiConstants.baseUrl;

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserBalance(
    int userId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/balance/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Gagal memuat saldo');
    }

    final balanceValue =
        data['saldo'] ?? data['total_balance'] ?? data['balance'];
    return {...data, 'balance': balanceValue};
  }

  static Future<Map<String, dynamic>> getUserProfile(
    int userId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserOrders(
    int userId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/user/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getDriverOrders(
    int driverId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl${ApiConstants.getDriverOrdersEndpoint}/$driverId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      try {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['message'] ??
              'Gagal memuat riwayat driver (${response.statusCode})',
        );
      } catch (_) {
        throw Exception('Gagal memuat riwayat driver (${response.statusCode})');
      }
    }

    final body = jsonDecode(response.body);
    if (body is List<dynamic>) return body;
    if (body is Map<String, dynamic> && body['data'] is List<dynamic>) {
      return body['data'] as List<dynamic>;
    }
    if (body is Map<String, dynamic> && body['orders'] is List<dynamic>) {
      return body['orders'] as List<dynamic>;
    }
    throw Exception('Format riwayat driver tidak dikenali');
  }

  static Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getHarga(String jenis) async {
    final response = await http.get(Uri.parse('$baseUrl/harga/$jenis'));
    return jsonDecode(response.body) as List<dynamic>;
  }

  // Driver / Orders (pending list for petugas/driver)
  static Future<List<dynamic>> getPendingOrders(String? token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/pending'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );

    if (response.statusCode != 200) {
      try {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['message'] ?? 'Gagal memuat order (${response.statusCode})',
        );
      } catch (_) {
        throw Exception('Gagal memuat order (${response.statusCode})');
      }
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> acceptOrder(
    int orderId,
    int driverId,
    String? token,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/accept/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'driver_id': driverId}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rejectOrder(
    int orderId,
    int driverId,
    String? token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/reject'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'driver_id': driverId}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> sendDriverLocation(
    int driverId,
    int orderId,
    double lat,
    double lng,
    String? token,
  ) async {
    await http.post(
      Uri.parse('$baseUrl/driver/location'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'driver_id': driverId,
        'order_id': orderId,
        'lat': lat,
        'lng': lng,
      }),
    );
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    int driverId,
    String status,
    String? token,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/status/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'driver_id': driverId, 'status': status}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getHargaSub(String jenis, String sub) async {
    final response = await http.get(Uri.parse('$baseUrl/harga/$jenis/$sub'));
    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> updateUserProfile(
    int userId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/user/profile/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        responseData['message'] ?? 'Gagal update profil (${response.statusCode})',
      );
    }

    return responseData;
  }

  // Tambahkan endpoint lain sesuai kebutuhan
}
