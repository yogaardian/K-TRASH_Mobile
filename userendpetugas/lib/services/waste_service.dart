import 'package:dio/dio.dart';
import 'package:user/core/network/api_client.dart';
import '../constants/api_constants.dart';

class WasteService {
  static final WasteService _instance = WasteService._internal();
  final ApiClient _apiClient = ApiClient();

  WasteService._internal();
  factory WasteService() => _instance;

  Future<List<Map<String, dynamic>>> getWasteTypes({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.getWasteTypesEndpoint,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final rawList = data['data'];
          if (rawList is List) {
            return rawList
                .whereType<Map<String, dynamic>>()
                .toList();
          }
        }
        throw Exception('Unexpected waste types response format');
      }

      throw Exception('Failed to fetch waste types');
    } on DioException catch (e) {
      throw Exception('Error fetching waste types: ${_getErrorMessage(e)}');
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
