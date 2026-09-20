import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/discount_model.dart';
import '../../super/activity_log/activity_log_service.dart';

// ==========================================
// ACTIVE DISCOUNTS
//
// Wraps the result of fetchActiveDiscounts() so callers can resolve
// the correct discount for a given product + (optionally) variant,
// with variant-specific discounts taking priority over whole-product
// ones when both exist.
// ==========================================
class ActiveDiscounts {
  final Map<int, Discount> byProduct; // keyed by product_id, variant_id IS NULL
  final Map<int, Discount> byVariant; // keyed by variant_id

  ActiveDiscounts({required this.byProduct, required this.byVariant});

  /// Resolves the discount that should apply right now.
  /// If [variantId] is given and has its own discount, that wins.
  /// Otherwise falls back to a whole-product discount, if any.
  Discount? resolve({required int productId, int? variantId}) {
    if (variantId != null && byVariant.containsKey(variantId)) {
      return byVariant[variantId];
    }
    return byProduct[productId];
  }

  bool get isEmpty => byProduct.isEmpty && byVariant.isEmpty;
}


// ==========================================
// DISCOUNT SERVICE
//
// Deliberately does NOT depend on the full Product
// model — searchProducts()/fetchVariantsForProduct()
// return lightweight maps so this feature stays
// decoupled from Inventory's model shape.
// ==========================================
class DiscountService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  static const String _table = 'discount';

  // Shared nested select used by fetchDiscounts() and
  // fetchActiveDiscounts() — keeps both queries in sync.
  static const String _discountSelect = '''
    discount_id,
    product_id,
    variant_id,
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
    ),

    variant:product_variant (
      color_name,
      retail_price
    )
  ''';

  // ==========================================
  // SEARCH PRODUCTS
  // Used by the "Select Product" type-ahead.
  // originalPrice = MIN retail_price across the
  // product's non-archived variants (whole-product default).
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
              retail_price,
              product_variant_size (
                stock_quantity,
                reserved_quantity
              )
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
        bool hasAvailableStock = false;

        for (final variant in variants) {
          final double price = (variant['retail_price'] as num).toDouble();
          if (minPrice == null || price < minPrice) {
            minPrice = price;
          }

          final List<dynamic> sizes =
              (variant['product_variant_size'] as List<dynamic>?) ?? [];
          for (final size in sizes) {
            final int stock = (size['stock_quantity'] as num?)?.toInt() ?? 0;
            final int reserved = (size['reserved_quantity'] as num?)?.toInt() ?? 0;
            if (stock - reserved > 0) {
              hasAvailableStock = true;
            }
          }
        }

        if (minPrice == null) continue;
        // Out-of-stock products don't appear in discount search at all —
        // a discount can only ever be created on something a customer
        // could actually buy right now.
        if (!hasAvailableStock) continue;

        results.add({
          'productId': item['product_id'] as int,
          'productName': item['product_name'] as String,
          'originalPrice': minPrice,
        });
      }

      return results;
    } catch (error) {
      return [];
    }
  }
// ==========================================
  // CHECK PRODUCT HAS STOCK
  // Used before creating a discount — warns the admin instead of
  // silently letting them create a discount on something with
  // nothing to actually sell.
  // ==========================================
  Future<bool> productHasStock(int productId) async {
    try {
      final List<dynamic> variants = await _supabase
          .from('product_variant')
          .select('product_variant_size(stock_quantity, reserved_quantity)')
          .eq('product_id', productId);

      for (final variant in variants) {
        final List<dynamic> sizes =
            variant['product_variant_size'] as List<dynamic>? ?? [];
        for (final size in sizes) {
          final int stock = (size['stock_quantity'] as num?)?.toInt() ?? 0;
          final int reserved = (size['reserved_quantity'] as num?)?.toInt() ?? 0;
          final int available = stock - reserved;
          // FIX: previously only checked raw stock_quantity, ignoring
          // reservations — a fully-reserved size (e.g. 19 stock, 19
          // reserved) was wrongly reported as "has stock" since
          // availableQty was never actually computed here, unlike
          // SizeEntry.availableQty elsewhere in the app.
          if (available > 0) return true;
        }
      }
      return false;
    } catch (error) {
      return true; // fail open — don't block on a check-itself failure
    }
  }
  
// ==========================================
// CHECK FOR OVERLAPPING DISCOUNT
// Prevents creating a duplicate/overlapping discount for the
// same product (or same variant, if variant-specific) during
// a period that already has an active discount.
// ==========================================
Future<bool> hasOverlappingDiscount({
  required int productId,
  int? variantId,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  try {
    final String newStart = _dateOnly(startDate);
    final String newEnd = _dateOnly(endDate);

    var query = _supabase
        .from(_table)
        .select('discount_id, start_date, end_date')
        .eq('product_id', productId)
        .eq('status', 'Active')
        .lte('start_date', newEnd)
        .gte('end_date', newStart);

    // Match scope exactly: whole-product discounts only conflict with
    // other whole-product discounts; a variant-specific discount only
    // conflicts with the SAME variant's discounts.
    if (variantId != null) {
      query = query.eq('variant_id', variantId);
    } else {
      query = query.isFilter('variant_id', null);
    }

    final List<dynamic> response = await query;
    return response.isNotEmpty;
  } catch (error) {
    print('hasOverlappingDiscount error: $error');
    // Fail safe: if the check itself errors, don't block creation —
    // but this should be rare and worth logging.
    return false;
  }
}
  // ==========================================
  // FETCH VARIANTS FOR PRODUCT
  // Used by the "Apply To" color picker in Create Discount,
  // once a specific product has been selected. Returns each
  // color/variant with its own retail_price so the admin can
  // pick "just the red ones" and see the correct final price.
  // ==========================================
  Future<List<Map<String, dynamic>>> fetchVariantsForProduct(
      int productId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('product_variant')
          .select('variant_id, color_name, retail_price')
          .eq('product_id', productId);

      return response
          .map((row) => {
                'variantId': row['variant_id'] as int,
                'color': row['color_name'] as String,
                'retailPrice': (row['retail_price'] as num).toDouble(),
              })
          .toList();
    } catch (error) {
      print('fetchVariantsForProduct error: $error');
      return [];
    }
  }

  // ==========================================
  // BUILD DISCOUNT FROM ROW
  // Shared parsing logic for fetchDiscounts() and
  // fetchActiveDiscounts() — handles both whole-product rows
  // (variant_id null, price = min across variants) and
  // variant-specific rows (variant_id set, price = that
  // variant's own retail_price).
  // ==========================================
  Discount _discountFromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> product =
        row['product'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic>? variantRow =
        row['variant'] as Map<String, dynamic>?;
    final int? variantId = row['variant_id'] as int?;

    double originalPrice;
    if (variantId != null && variantRow != null) {
      // Variant-specific discount: use that variant's own price.
      originalPrice = (variantRow['retail_price'] as num).toDouble();
    } else {
      // Whole-product discount: use the min price across variants,
      // same as searchProducts()'s convention.
     final List<dynamic> variants =
          (product['product_variant'] as List<dynamic>?) ?? [];
      double? minPrice;
      for (final variant in variants) {
        final double price = (variant['retail_price'] as num).toDouble();
        if (minPrice == null || price < minPrice) {
          minPrice = price;
        }
      }
      originalPrice = minPrice ?? 0;
    }

    return Discount.fromMap({
      'discount_id': row['discount_id'],
      'product_id': row['product_id'],
      'variant_id': variantId,
      'variant_color': variantRow?['color_name'],
      'product_name': product['product_name'] ?? 'Unknown Product',
      'original_price': originalPrice,
      'discount_type': row['discount_type'],
      'discount_value': row['discount_value'],
      'status': row['status'],
      'start_date': row['start_date'],
      'end_date': row['end_date'],
    });
  }

  // ==========================================
  // FETCH DISCOUNTS
  // Full list for the admin Discounts table.
  // ==========================================
  Future<List<Discount>> fetchDiscounts() async {
    try {
      final List<dynamic> response = await _supabase
          .from(_table)
          .select(_discountSelect)
          .order('created_at', ascending: false);

      return response
          .map((row) => _discountFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchDiscounts error: $error');
      return [];
    }
  }

  // ==========================================
  // FETCH ACTIVE DISCOUNTS
  //
  // Used by the customer Promo page, Cashier, Checkout, and Product
  // Detail to look up whether a given product/variant currently has
  // a live discount. Returns an ActiveDiscounts wrapper — call
  // .resolve(productId: ..., variantId: ...) to get the discount
  // that should actually apply (variant-specific wins over
  // whole-product when both exist).
  //
  // "Live" means: admin status == 'Active' AND today falls within
  // [start_date, end_date] inclusive.
  //
  // NOTE: this replaces the old fetchActiveDiscountsByProduct(),
  // which returned a flat Map<int, Discount> keyed only by
  // product_id and had no way to express variant-specific
  // discounts. Callers (Promo, Shop, Cashier, Product Detail)
  // need to switch from that flat map to calling .resolve() here.
  // ==========================================
  Future<ActiveDiscounts> fetchActiveDiscounts() async {
    try {
      final String today = _dateOnly(DateTime.now());

      final List<dynamic> response = await _supabase
          .from(_table)
          .select(_discountSelect)
          .eq('status', 'Active')
          .lte('start_date', today)
          .gte('end_date', today);

      final Map<int, Discount> byProduct = {};
      final Map<int, Discount> byVariant = {};

      for (final row in response) {
        final Discount discount = _discountFromRow(row as Map<String, dynamic>);
        if (discount.isVariantSpecific) {
          byVariant[discount.variantId!] = discount;
        } else {
          byProduct[discount.productId] = discount;
        }
      }

      return ActiveDiscounts(byProduct: byProduct, byVariant: byVariant);
    } catch (error) {
      print('fetchActiveDiscounts error: $error');
      return ActiveDiscounts(byProduct: {}, byVariant: {});
    }
  }

  // ==========================================
  // ADD DISCOUNT
  // discountType MUST be exactly 'Percentage' or 'Fixed'.
  // Pass variantId to scope this discount to a single color;
  // leave it null to apply to the whole product (default).
  // ==========================================
  Future<String?> addDiscount({
    required int productId,
    int? variantId,
    required String discountType,
    required double discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
  }) async {
    try {
      final inserted = await _supabase
          .from(_table)
          .insert({
            'product_id': productId,
            'variant_id': variantId,
            'discount_type': discountType,
            'discount_value': discountValue,
            'start_date': _dateOnly(startDate),
            'end_date': _dateOnly(endDate),
            'status': status,
          })
          .select('discount_id')
          .single();

      await _activityLog.log(
        action: 'Added new discount ($discountType $discountValue) '
            'for product #$productId'
            '${variantId != null ? ' (variant #$variantId)' : ''}',
        affectedModule: AffectedModule.promotions,
        targetId: inserted['discount_id']?.toString(),
        metadata: {
          'product_id': productId,
          'variant_id': variantId,
          'discount_type': discountType,
          'discount_value': discountValue,
          'status': status,
        },
      );

      // Notify immediately ONLY if this discount is live starting today
      // (start_date <= today) — otherwise the customer would wait for
      // the next daily cron run even though the discount is already
      // visible/active right now. Future-dated discounts are still
      // left to notify_customers_promotion_start() on their actual
      // start date, so nobody gets notified early for a discount that
      // hasn't started yet.
      final DateTime todayManila =
          DateTime.now().toUtc().add(const Duration(hours: 8));
      final DateTime startDateOnly =
          DateTime(startDate.year, startDate.month, startDate.day);
      final DateTime todayOnly =
          DateTime(todayManila.year, todayManila.month, todayManila.day);

      if (status == 'Active' && !startDateOnly.isAfter(todayOnly)) {
        final bool hasStock = await productHasStock(productId);
        if (hasStock) {
          await _notifyCustomersDiscountLive(
            productId: productId,
            discountType: discountType,
            discountValue: discountValue,
          );
        }
        // Out-of-stock products don't notify customers at all — matches
        // Promo's own totalAvailable == 0 exclusion. The discount still
        // gets created either way (admin may be prepping ahead of a
        // restock); it just won't announce itself to customers until
        // there's actually something to buy.
      }
      return null;
    } catch (error) {
      print('addDiscount error: $error');
      return error.toString();
    }
  }

  // ================================================
  // NOTIFY CUSTOMERS — DISCOUNT LIVE NOW
  // Fires immediately when an admin creates a discount that's active
  // starting today, so customers don't have to wait for the daily
  // cron job. Uses type 'discount' — separate from the promotion
  // banner's 'promotion' type, so the two are distinguishable.
  // ================================================
  Future<void> _notifyCustomersDiscountLive({
    required int productId,
    required String discountType,
    required double discountValue,
  }) async {
    try {
      String productName = 'A product';
      try {
        final row = await _supabase
            .from('product')
            .select('product_name')
            .eq('product_id', productId)
            .single();
        productName = row['product_name']?.toString() ?? productName;
      } catch (_) {
        // fall back to the generic label above
      }

      final String valueLabel = discountType == 'Percentage'
          ? '${discountValue.toStringAsFixed(0)}% off'
          : '₱${discountValue.toStringAsFixed(2)} off';

      final customers = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'Customer');

      if ((customers as List).isEmpty) return;

      final rows = customers.map((u) => {
            'customer_id': u['id'],
            'type': 'discount',
            'title': 'New discount available',
            'body': '$productName is now $valueLabel. Shop now before it ends!',
            'recipient_role': 'customer',
          }).toList();

      await _supabase.from('notifications').insert(rows);
    } catch (error) {
      print('_notifyCustomersDiscountLive error: $error');
    }
  }

  // ================================================
  // NOTIFY CUSTOMERS — NEW PROMOTION
  // Store-wide announcement: every customer gets notified when a
  // new discount goes live. Non-critical — a notification failure
  // must never block discount creation itself.
  // ================================================
  Future<void> _notifyCustomersNewPromotion({
    required int productId,
    required String discountType,
    required double discountValue,
  }) async {
    try {
      String productName = 'A product';
      try {
        final row = await _supabase
            .from('product')
            .select('product_name')
            .eq('product_id', productId)
            .single();
        productName = row['product_name']?.toString() ?? productName;
      } catch (_) {
        // fall back to the generic label above
      }

      final String valueLabel = discountType == 'Percentage'
          ? '${discountValue.toStringAsFixed(0)}% off'
          : '₱${discountValue.toStringAsFixed(2)} off';

      final customers = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'Customer');

      if ((customers as List).isEmpty) return;

      final rows = customers.map((u) => {
            'customer_id': u['id'],
            'type': 'promotion',
            'title': 'New discount available',
            'body': '$productName is now $valueLabel. Shop now before it ends!',
            'recipient_role': 'customer',
          }).toList();

      await _supabase.from('notifications').insert(rows);
    } catch (error) {
      print('_notifyCustomersNewPromotion error: $error');
    }
  }

  // ==========================================
  // UPDATE DISCOUNT
  // Product AND variant scope are NOT editable once created —
  // only type, value, duration, and status can change. To change
  // scope, delete and recreate.
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

      await _activityLog.log(
        action: 'Updated discount #$discountId',
        affectedModule: AffectedModule.promotions,
        targetId: discountId.toString(),
        metadata: {
          'discount_type': discountType,
          'discount_value': discountValue,
          'status': status,
        },
      );

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

      await _activityLog.log(
        action: 'Deleted discount #$discountId',
        affectedModule: AffectedModule.promotions,
        targetId: discountId.toString(),
      );

      return null;
    } catch (error) {
      print('deleteDiscount error: $error');
      return error.toString();
    }
  }

  // ── helpers ──

  String _dateOnly(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}