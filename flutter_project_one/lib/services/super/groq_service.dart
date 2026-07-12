import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// AI DASHBOARD SERVICE
//
// Calls two Supabase Edge Functions:
//   - 'ai-dashboard'            (Groq) — trend / trending / restock
//   - 'ai-product-replacement'  (Gemini + Google Search grounding)
//
// Both API keys live server-side as Edge Function secrets —
// never exposed to the Flutter client.
//
// NOTE: file kept as GroqService (not renamed) to avoid
// breaking existing imports across the dashboard screen/widgets.
// It now also handles the Gemini-based replacement call.
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

  // Separate call so the screen can show the insight text alongside
  // the numeric prediction without re-parsing.
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
  // salesData growth% is real, pre-computed data (see
  // DashboardService.getProductSalesGrowth) — Groq ranks it.
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
  // Math (daysUntilStockout, recommendedRestock) is computed
  // deterministically inside the Edge Function itself.
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
  // PRODUCT REPLACEMENT (Gemini + Google Search)
  // One call per discontinued product — run in parallel
  // from the screen via Future.wait.
  // ================================================
  Future<Map<String, dynamic>?> getProductReplacement({
    required String discontinuedProduct,
    required String brand,
    required List<String> availableBrands,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-product-replacement',
        body: {
          'discontinuedProduct': discontinuedProduct,
          'brand': brand,
          'availableBrands': availableBrands,
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