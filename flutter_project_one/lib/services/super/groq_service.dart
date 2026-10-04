import 'package:supabase_flutter/supabase_flutter.dart';
// ================================================
// AI DASHBOARD SERVICE
//
// Calls two Supabase Edge Functions, both now backed by OpenAI
// (gpt-5.6-luna):
//   - 'ai-dashboard'            — trend / trending / restock
//   - 'ai-product-replacement'  — 6a (customer_replacement) and
//                                 6b (new_product_suggestion)
//
// The OpenAI API key lives server-side as an Edge Function secret —
// never exposed to the Flutter client.
//
// NOTE: file kept as GroqService (not renamed) to avoid breaking
// existing imports across the dashboard screen/widgets. Neither
// function it calls uses Groq or Gemini anymore.
// ================================================
class GroqService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // SALES TREND PREDICTION
  // ================================================
  Future<List<double>> getSalesTrendPrediction({
    required List<double> monthlySales,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-dashboard',
        body: {
          'action': 'trend',
          'payload': {'monthlySales': monthlySales},
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        print('getSalesTrendPrediction failed: ${data?['error']}');
        return [];
      }

      final predicted = (data['data']['predictedSales'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      return predicted;
    } catch (error) {
      print('getSalesTrendPrediction error: $error');
      return [];
    }
  }

  Future<String> getSalesTrendInsight({
    required List<double> monthlySales,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-dashboard',
        body: {
          'action': 'trend',
          'payload': {'monthlySales': monthlySales},
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) return '';
      return data['data']['insight']?.toString() ?? '';
    } catch (error) {
      print('getSalesTrendInsight error: $error');
      return '';
    }
  }

  // ================================================
  // TRENDING SHOES
  // ================================================
  Future<List<Map<String, dynamic>>> getTrendingShoes({
    required List<Map<String, dynamic>> salesData,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-dashboard',
        body: {
          'action': 'trending',
          'payload': {'salesData': salesData},
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        print('getTrendingShoes failed: ${data?['error']}');
        return [];
      }

      return List<Map<String, dynamic>>.from(data['data']['trending']);
    } catch (error) {
      print('getTrendingShoes error: $error');
      return [];
    }
  }

  // ================================================
  // RESTOCK PREDICTION
  // ================================================
  Future<List<Map<String, dynamic>>> getRestockPrediction({
    required List<Map<String, dynamic>> inventoryData,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-dashboard',
        body: {
          'action': 'restock',
          'payload': {'inventoryData': inventoryData},
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        print('getRestockPrediction failed: ${data?['error']}');
        return [];
      }

      return List<Map<String, dynamic>>.from(data['data']['restockItems']);
    } catch (error) {
      print('getRestockPrediction error: $error');
      return [];
    }
  }

  // ================================================
  // PRODUCT REPLACEMENT — 6a, customer-facing
  // Catalog-first check happens server-side; this just calls
  // the Edge Function in customer_replacement mode.
  // ================================================
  Future<Map<String, dynamic>?> getProductReplacement({
    required String discontinuedProduct,
    required String brand,
    required List<String> availableBrands,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-product-replacement',
        body: {
          'discontinuedProduct': discontinuedProduct,
          'brand': brand,
          'availableBrands': availableBrands,
          'mode': 'customer_replacement',
          'forceRefresh': forceRefresh,
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        print('getProductReplacement failed: ${data?['error']}');
        return null;
      }

      return Map<String, dynamic>.from(data['data']);
    } catch (error) {
      print('getProductReplacement error: $error');
      return null;
    }
  }

  // ================================================
  // SUGGEST NEW PRODUCT — 6b, admin-initiated
  // Always AI + web search — deliberately skips the catalog-first
  // check, since the point is finding something NOT already stocked.
  // Separate cache key from getProductReplacement, so the two never
  // overwrite each other.
  // ================================================
  Future<Map<String, dynamic>?> getNewProductSuggestion({
    required String discontinuedProduct,
    required String brand,
    required List<String> availableBrands,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-product-replacement',
        body: {
          'discontinuedProduct': discontinuedProduct,
          'brand': brand,
          'availableBrands': availableBrands,
          'mode': 'new_product_suggestion',
          'forceRefresh': forceRefresh,
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        print('getNewProductSuggestion failed: ${data?['error']}');
        return null;
      }

      return Map<String, dynamic>.from(data['data']);
    } catch (error) {
      print('getNewProductSuggestion error: $error');
      return null;
    }
  }

  // Convenience: run replacement lookups for a batch of
  // discontinued/archived products in parallel.
  Future<List<Map<String, dynamic>>> getProductReplacements({
    required List<Map<String, dynamic>> discontinuedProducts,
    required List<String> availableBrands,
  }) async {
    final futures = discontinuedProducts.map((product) {
      return getProductReplacement(
        discontinuedProduct: product['productName'] as String,
        brand: product['brand'] as String,
        availableBrands: availableBrands,
      );
    });

    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }
}