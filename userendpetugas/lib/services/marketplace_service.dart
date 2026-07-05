import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../shared/models/product_model.dart';

class MarketplaceService {
  static final MarketplaceService _instance = MarketplaceService._internal();
  final ApiClient _apiClient = ApiClient();

  MarketplaceService._internal();

  factory MarketplaceService() => _instance;

  Future<List<ProductModel>> getProducts({
    String? kategori,
    String? search,
  }) async {
    try {
      final products = <ProductModel>[];

      // Try to fetch all products in a single request by requesting a large page size.
      // If the backend ignores per_page/limit, fall back to paginated fetching.
      const int initialPerPage = 1000;
      int page = 1;
      bool usePaginationLoop = false;

      final initialResponse = await _apiClient.get(
        ApiConstants.getMarketplaceProductsEndpoint,
        queryParameters: {
          if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'per_page': initialPerPage,
          'limit': initialPerPage,
        },
      );

      dynamic data = initialResponse.data;

      List<dynamic>? extractList(dynamic payload) {
        if (payload == null) return null;
        if (payload is List) return payload;
        if (payload is Map<String, dynamic>) {
          final listData = payload['data'] ?? payload['products'] ?? payload['items'];
          if (listData is List) return listData;
        }
        return null;
      }

      List<dynamic>? listData = extractList(data);

      if (listData != null && listData.isNotEmpty) {
        products.addAll(
          listData.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)),
        );

        // If the returned list is smaller than our requested per-page size, assume we got everything.
        if (listData.length < initialPerPage) {
          return products;
        }

        // If the response contains explicit pagination metadata, use it to loop.
        final meta = (data is Map<String, dynamic>) ? (data['meta'] ?? data['pagination']) : null;
        if (meta is Map<String, dynamic>) {
          final lastPage = (meta['last_page'] ?? meta['lastPage'] ?? meta['total_pages']) as int?;
          if (lastPage != null) {
            // We already have page 1 results; fetch remaining pages up to lastPage.
            for (int p = 2; p <= lastPage; p++) {
              final resp = await _apiClient.get(
                ApiConstants.getMarketplaceProductsEndpoint,
                queryParameters: {
                  if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
                  if (search != null && search.isNotEmpty) 'search': search,
                  'page': p,
                  'per_page': initialPerPage,
                  'limit': initialPerPage,
                },
              );
              final pageData = extractList(resp.data);
              if (pageData != null && pageData.isNotEmpty) {
                products.addAll(pageData.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)));
              }
            }
            return products;
          }

          // If no lastPage metadata, fall back to loop until an empty page.
          usePaginationLoop = true;
        } else {
          // No meta provided; fall back to loop only if the initial response filled the page.
          usePaginationLoop = true;
        }
      } else {
        // If initial response didn't return a list, attempt to interpret top-level map
        // and try a single pass to collect items if present.
        if (data is Map<String, dynamic>) {
          final list = data['data'] ?? data['products'] ?? data['items'];
          if (list is List) {
            products.addAll(list.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)));
            return products;
          }
        }
      }

      // Paginated loop fallback: request pages until an empty list is returned.
      if (usePaginationLoop) {
        page = 2;
        const int loopPerPage = 200;
        while (true) {
          final resp = await _apiClient.get(
            ApiConstants.getMarketplaceProductsEndpoint,
            queryParameters: {
              if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
              if (search != null && search.isNotEmpty) 'search': search,
              'page': page,
              'per_page': loopPerPage,
              'limit': loopPerPage,
            },
          );
          final pageList = extractList(resp.data) ?? [];
          if (pageList.isEmpty) break;
          products.addAll(pageList.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)));
          if (pageList.length < loopPerPage) break;
          page++;
          // Safety: avoid infinite loops
          if (page > 1000) break;
        }
      }

      return products;
    } on DioException catch (e) {
      throw Exception('Marketplace load error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected marketplace error: $e');
    }
  }

  Future<void> createProductOrder({
    required int productId,
    required int quantity,
    required String catatan,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.createMarketplaceOrderEndpoint}/$productId/order',
        data: {'jumlah': quantity, 'catatan': catatan},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Gagal membuat pesanan marketplace.');
      }
    } on DioException catch (e) {
      if (e.response?.data != null &&
          e.response?.data is Map<String, dynamic>) {
        final message =
            (e.response?.data as Map<String, dynamic>)['message'] as String?;
        throw Exception(message ?? 'Gagal memproses pesanan marketplace');
      }
      throw Exception('Marketplace order error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected marketplace order error: $e');
    }
  }
}
