import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart'; // ← add this import (reuses OrderItem)

class SaleRecord {
  final String orderId;
  final String orderType;
  final double subtotal;
  final double shipping;        // ← new
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final String orderStatus;
  final String dateTime;
  // AUDIT ADD: Phase 6 — the real DateTime, kept alongside the
  // formatted display string so the date filter can actually compare
  // real dates instead of re-parsing a human-readable string.
  final DateTime rawDateTime;
  final String? receiptUrl;     // ← new, so Sales table can offer a direct download


  SaleRecord({
    required this.orderId,
    required this.orderType,
    required this.subtotal,
    required this.shipping,       // ← new
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.orderStatus,
    required this.dateTime,
    required this.rawDateTime,
    this.receiptUrl,

  });

  factory SaleRecord.fromMap(Map<String, dynamic> map) {
    String dateTime = '';
    DateTime rawDateTime = DateTime.fromMillisecondsSinceEpoch(0);
    if (map['created_at'] != null) {
            // AUDIT FIX: same Philippine-time correction as SalesReportService.
      final DateTime dt = DateTime.parse(map['created_at'].toString()).toUtc().add(const Duration(hours: 8));
      rawDateTime = dt;
      final String month  = dt.month.toString().padLeft(2, '0');
      final String day    = dt.day.toString().padLeft(2, '0');
      final String year   = dt.year.toString();
      final int    hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final String minute = dt.minute.toString().padLeft(2, '0');
      final String amPm   = dt.hour < 12 ? 'am' : 'pm';
      dateTime = '$month/$day/$year $hour12:$minute $amPm';
    }

    return SaleRecord(
      orderId:         map['order_id'].toString(),
      orderType:       map['order_type'] ?? 'online',
      subtotal:        (map['subtotal'] as num?)?.toDouble() ?? 0,
      shipping:        (map['shipping'] as num?)?.toDouble() ?? 0,
      discountAmount:  (map['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount:     (map['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod:   map['payment_method'] ?? '',
      orderStatus:     map['order_status'] ?? '',
      dateTime:        dateTime,
      rawDateTime:     rawDateTime,
      receiptUrl:      map['receipt_url'] as String?,
    );
  }
}

class SalesManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<SaleRecord>> loadSales({String? typeFilter}) async {
    try {
      late List<dynamic> response;

      if (typeFilter != null) {
        response = await _supabase
            .from('orders')
            .select('order_id, order_type, subtotal, shipping, discount_amount, total_amount, payment_method, order_status, created_at')
            .eq('order_type', typeFilter)
            .order('created_at', ascending: false);
      } else {
        response = await _supabase
            .from('orders')
            .select('order_id, order_type, subtotal, shipping, discount_amount, total_amount, payment_method, order_status, created_at')
            .order('created_at', ascending: false);
      }

      // Get all paid order IDs
            // Get all paid order IDs — also grab receipt_url here so the
      // Sales table can offer a direct download without a second
      // per-row fetch.
      final List<dynamic> paidPayments = await _supabase
          .from('payment')
          .select('order_id, receipt_url')
          .eq('payment_status', 'Paid');

      final Set<int> paidOrderIds = paidPayments
          .map((p) => (p['order_id'] as num).toInt())
          .toSet();

      final Map<int, String?> receiptUrlByOrderId = {
        for (final p in paidPayments)
          (p['order_id'] as num).toInt(): p['receipt_url'] as String?,
      };

      // payment_status = 'Paid' is now unambiguous everywhere in the
      // app — it's ONLY ever set once a sale is truly finalized:
      //   - gcash/card (online): set by admin's approvePayment()
      //   - cod (online): set when order_status reaches 'Completed'
      //   - In-Store walk-in QR: set immediately by the webhook,
      //     since there's no separate approval step for those
      // The webhook's gateway-confirmed-but-not-yet-approved state
      // for online gcash/card is 'Verified', not 'Paid', so it never
      // leaks into this filter. Cancelled orders can never have
      // payment_status = 'Paid' either, since a Paid order cannot be
      // cancelled (see PaymentService docs) and any Verified order
      // that gets cancelled has its payment_status flipped to
      // 'Refunded'/'Refund Failed' instead of staying 'Paid'.
            final List<Map<String, dynamic>> filtered = response
          .cast<Map<String, dynamic>>()
          .where((row) {
            final String type = row['order_type'] ?? 'online';
            final String status = row['order_status'] ?? '';

            if (type == 'In-Store') {
              return status == 'Completed';
            }

            final int orderId = (row['order_id'] as num).toInt();
            return paidOrderIds.contains(orderId);
          })
          .map((row) {
            final int orderId = (row['order_id'] as num).toInt();
            return {
              ...row,
              'receipt_url': receiptUrlByOrderId[orderId],
            };
          })
          .toList();

      return filtered.map((row) => SaleRecord.fromMap(row)).toList();
    } catch (e) {
      print('SalesManagementService.loadSales error: $e');
      rethrow;
    }
  }

  // ── NEW: get one sale's items + payment info for the View dialog ──
  Future<Map<String, dynamic>> loadSaleDetails(String orderId) async {
    final int id = int.parse(orderId);

    final List<dynamic> itemRows = await _supabase
        .from('order_item')
        .select('product_name_snapshot, brand_snapshot, size_snapshot, quantity, unit_price, subtotal')
        .eq('order_id', id);

    final List<OrderItem> items =
        itemRows.map((row) => OrderItem.fromMap(row as Map<String, dynamic>)).toList();

    final Map<String, dynamic>? paymentRow = await _supabase
        .from('payment')
        .select('reference_number, payment_status, receipt_url')
        .eq('order_id', id)
        .maybeSingle();

    return {
      'items': items,
      'referenceNumber': paymentRow?['reference_number'] ?? '',
      'paymentStatus': paymentRow?['payment_status'] ?? 'Pending',
      'receiptUrl': paymentRow?['receipt_url'],
    };
  }
}