import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/discount_model.dart';

// ==========================================
// DISCOUNT SERVICE
//
// Same style as InventoryService.
//
// Deliberately does NOT depend on the full Product
// model — searchProducts() returns lightweight maps
// so this feature stays decoupled from Inventory's
// model shape.
// ==========================================
class DiscountService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'discount';

  // ==========================================
  // SEARCH PRODUCTS
  // Used by ProductSearchField's type-ahead.
  // originalPrice = MIN retail_price across the
  // product's non-archived variants.
  // ==========================================
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final List<dynamic> response = await _supabase
          .from('product')
          .select('''
            product_id,
            product_name,
            is_archived,
            product_variant (
              retail_price
            )
          ''')
          .eq('is_archived', false)
          .ilike('product_name', '%$query%')
          .limit(10);

      final List<Map<String, dynamic>> results = [];

      for (final item in response) {
        final List<dynamic> variants =
            (item['product_variant'] as List<dynamic>?) ?? [];

        if (variants.isEmpty) continue;

        double? minPrice;
        for (final variant in variants) {
          final double price = (variant['retail_price'] as num).toDouble();
          if (minPrice == null || price < minPrice) {
            minPrice = price;
          }
        }

        if (minPrice == null) continue;

        results.add({
          'productId': item['product_id'] as int,
          'productName': item['product_name'] as String,
          'originalPrice': minPrice,
        });
      }

      return results;
    } catch (error) {
      print('searchProducts error: $error');
      return [];
    }
  }

  // ==========================================
  // FETCH DISCOUNTS
  // Nested select on discount.* + product.product_name,
  // same style as InventoryService.fetchProducts().
  // Original price is derived the same way as
  // searchProducts() (min retail_price of variants),
  // kept consistent between create and fetch.
  // ==========================================
  Future<List<Discount>> fetchDiscounts() async {
    try {
      final List<dynamic> response = await _supabase
          .from(_table)
          .select('''
            discount_id,
            product_id,
            discount_type,
            discount_value,
            status,
            start_date,
            end_date,

            product (
              product_name,
              product_variant (
                retail_price
              )
            )
          ''')
          .order('created_at', ascending: false);

      final List<Discount> discounts = [];

      for (final row in response) {
        final Map<String, dynamic> product =
            row['product'] as Map<String, dynamic>? ?? {};

        final List<dynamic> variants =
            (product['product_variant'] as List<dynamic>?) ?? [];

        double originalPrice = 0;
        for (final variant in variants) {
          final double price = (variant['retail_price'] as num).toDouble();
          if (originalPrice == 0 || price < originalPrice) {
            originalPrice = price;
          }
        }

        discounts.add(Discount.fromMap({
          'discount_id': row['discount_id'],
          'product_id': row['product_id'],
          'product_name': product['product_name'] ?? 'Unknown Product',
          'original_price': originalPrice,
          'discount_type': row['discount_type'],
          'discount_value': row['discount_value'],
          'status': row['status'],
          'start_date': row['start_date'],
          'end_date': row['end_date'],
        }));
      }

      return discounts;
    } catch (error) {
      print('fetchDiscounts error: $error');
      return [];
    }
  }

// ==========================================
  // FETCH ACTIVE DISCOUNTS (keyed by product_id)
  //
  // Used by the customer Promo page, Cashier, and
  // Checkout to look up whether a given product
  // currently has a live discount.
  //
  // "Live" means: admin status == 'Active' AND
  // today falls within [start_date, end_date]
  // inclusive.
  // ==========================================
  Future<Map<int, Discount>> fetchActiveDiscountsByProduct() async {
    try {
      final String today = _dateOnly(DateTime.now());

      final List<dynamic> response = await _supabase
          .from(_table)
          .select('''
            discount_id,
            product_id,
            discount_type,
            discount_value,
            status,
            start_date,
            end_date,

            product (
              product_name,
              product_variant (
                retail_price
              )
            )
          ''')
          .eq('status', 'Active')
          .lte('start_date', today)
          .gte('end_date', today);

      final Map<int, Discount> result = {};

      for (final row in response) {
        final Map<String, dynamic> product =
            row['product'] as Map<String, dynamic>? ?? {};

        final List<dynamic> variants =
            (product['product_variant'] as List<dynamic>?) ?? [];

        double originalPrice = 0;
        for (final variant in variants) {
          final double price = (variant['retail_price'] as num).toDouble();
          if (originalPrice == 0 || price < originalPrice) {
            originalPrice = price;
          }
        }

        final Discount discount = Discount.fromMap({
          'discount_id': row['discount_id'],
          'product_id': row['product_id'],
          'product_name': product['product_name'] ?? 'Unknown Product',
          'original_price': originalPrice,
          'discount_type': row['discount_type'],
          'discount_value': row['discount_value'],
          'status': row['status'],
          'start_date': row['start_date'],
          'end_date': row['end_date'],
        });

        result[discount.productId] = discount;
      }

      return result;
    } catch (error) {
      print('fetchActiveDiscountsByProduct error: $error');
      return {};
    }
  }
  // ==========================================
  // ADD DISCOUNT
  // discountType MUST be exactly 'Percentage' or
  // 'Fixed' — Discount.fromMap's display/calculation
  // getters check for the literal string 'Percentage'.
  // ==========================================
  Future<String?> addDiscount({
    required int productId,
    required String discountType,
    required double discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
  }) async {
    try {
      await _supabase.from(_table).insert({
        'product_id': productId,
        'discount_type': discountType,
        'discount_value': discountValue,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'status': status,
      });

      return null;
    } catch (error) {
      print('addDiscount error: $error');
      return error.toString();
    }
  }

  // ==========================================
  // UPDATE DISCOUNT
  // Product is NOT editable once created.
  // ==========================================
  Future<String?> updateDiscount({
    required int discountId,
    required String discountType,
    required double discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
  }) async {
    try {
      await _supabase.from(_table).update({
        'discount_type': discountType,
        'discount_value': discountValue,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'status': status,
      }).eq('discount_id', discountId);

      return null;
    } catch (error) {
      print('updateDiscount error: $error');
      return error.toString();
    }
  }

  // ==========================================
  // DELETE DISCOUNT
  // ==========================================
  Future<String?> deleteDiscount({required int discountId}) async {
    try {
      await _supabase.from(_table).delete().eq('discount_id', discountId);
      return null;
    } catch (error) {
      print('deleteDiscount error: $error');
      return error.toString();
    }
  }

  // ── helpers ──

  // 'discount.start_date' / 'end_date' are `date` columns,
  // so send just the date portion (no time/zone).
  String _dateOnly(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}