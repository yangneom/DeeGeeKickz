import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_cart_item.dart';
import '../../services/customer/payment/payment_service.dart';

class ArchivedProductException implements Exception {
  final String message;
  ArchivedProductException(this.message);

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);

  @override
  String toString() => message;
}

class AccountSuspendedException implements Exception {
  final String message;
  AccountSuspendedException(this.message);

  @override
  String toString() => message;
}

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ───────────────────────────────────────────
  // CREATE ORDER
  //
  // This used to be 5+ separate network calls (address, order,
  // order_item × N, reserveStock, order_progress, payment) — if any
  // step failed partway, everything before it stayed in the
  // database as orphaned rows (confirmed happening live during
  // testing: failed stock reservation left behind a real order and
  // order_item rows with no successful reservation behind them).
  //
  // Now it's a single call to create_order_full, a Postgres function
  // that does the entire sequence as one atomic unit — if ANY step
  // inside it fails (including the stock check), every write it made
  // rolls back automatically. Nothing partial can ever be left
  // behind again.
  // ───────────────────────────────────────────
  Future<int> createOrder({
    required String userId,
    String? addressId,
    required String street,
    required String city,
    required String postal,
    required String country,
    double? lat,
    double? lng,
    required List<CustomerCartItem> items,
    required double subtotal,
    required double shipping,
    required double total,
    required String paymentMethod,
  }) async {
    final double discountAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.discountSubtotal,
    );

    final List<Map<String, dynamic>> itemsPayload = items
        .map((item) => {
              'product_id': item.productId,
              'size_id': item.sizeId,
              'quantity': item.quantity,
              'unit_price': item.retailPrice,
              'subtotal': item.subtotal,
              'product_name': item.productName,
              'brand': item.brand,
              'color': item.color,
              'size': item.size,
            })
        .toList();

    try {
      final dynamic result = await _supabase.rpc('create_order_full', params: {
        'p_user_id': userId,
        'p_address_id': addressId != null ? int.parse(addressId) : null,
        'p_street': street,
        'p_city': city,
        'p_zip_code': postal,
        'p_lat': lat,
        'p_lng': lng,
        'p_subtotal': subtotal,
        'p_shipping': shipping,
        'p_discount_amount': discountAmount,
        'p_total': total,
        'p_payment_method': paymentMethod,
        'p_items': itemsPayload,
      });

      final int orderId = (result as num).toInt();

      // Non-critical — evaluates the rapid-ordering abuse pattern.
      // Must never fail order placement, which already succeeded.
      try {
        await _supabase.rpc('evaluate_customer_abuse', params: {
          'p_user_id': userId,
        });
      } catch (e) {
        print('evaluate_customer_abuse error: $e');
      }

      // Non-critical — must never fail the order itself, which has
      // already fully committed by this point.
      await _notifyStaffNewOrder(
        orderId: orderId,
        total: total,
        paymentMethod: paymentMethod,
      );

      return orderId;
        } on PostgrestException catch (e) {
      print('OrderService.createOrder error: $e');
      if (e.code == 'P1001') {
        throw ArchivedProductException(e.message);
      }
      if (e.code == 'P1002' || e.code == 'P1003') {
        throw ArchivedProductException(e.message);
      }
      if (e.code == 'P0001') {
        // P0001 is Postgres's generic user-raised-exception code —
        // multiple DIFFERENT triggers share it (stock checks AND
        // account suspension), so the message content, not the code
        // alone, is what actually tells them apart. Checked first,
        // since a suspension error was previously always
        // misclassified as a stock issue.
        if (e.message.contains('account is currently suspended')) {
          throw AccountSuspendedException(e.message);
        }
        throw InsufficientStockException(e.message);
      }
      rethrow;
    }
  }

  // ───────────────────────────────────────────
  // NOTIFY STAFF — new order placed
  // Fires for every order (COD, GCash, Card) the moment it's
  // created, regardless of payment status. Non-critical — a
  // notification failure must never fail the order itself, which
  // has already fully succeeded by the time this runs.
  // ───────────────────────────────────────────
  Future<void> _notifyStaffNewOrder({
    required int orderId,
    required double total,
    required String paymentMethod,
  }) async {
    print('🔔🔔🔔 _notifyStaffNewOrder CALLED for order #$orderId 🔔🔔🔔');
    try {
      await _supabase.rpc('notify_staff_new_order', params: {
        'p_order_id': orderId,
        'p_total': total,
        'p_payment_method': paymentMethod,
      });
      print('🔔 Order RPC completed successfully');
    } catch (error) {
      print('_notifyStaffNewOrder error: $error');
    }
  }
}