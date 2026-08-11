import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart';

// ================================================
// ORDER HISTORY SERVICE
//
// FIX 1: Supabase join syntax — use bare table name
//         "address" not "address!orders_address_id_fkey"
//         when there is only one FK to that table.
// FIX 2: Pull receipt_url from payment so customer
//         can open their PDF receipt.
// FIX 3: Pull tracking_url from orders so the
//         "Track Package" button opens Lalamove.
// ================================================

class OrderHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Order>> getMyOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // ── Step 1: fetch orders with correct join syntax ──
      // NOTE: use the bare FK table name "address" — Supabase
      // auto-resolves the FK when there is only one FK to that table.
      final List<dynamic> ordersResponse = await _supabase
          .from('orders')
          .select('''
            order_id,
            total_amount,
            payment_method,
            order_status,
            tracking_url,
            created_at,
            address (
              street,
              city,
              zip_code,
              landmark
            ),
            order_item (
              product_name_snapshot,
              brand_snapshot,
              size_snapshot,
              quantity,
              unit_price,
              subtotal
            )
          ''')
          .eq('user_id', user.id)
          .neq('order_status', 'Awaiting Payment')   
          .order('created_at', ascending: false);

      if (ordersResponse.isEmpty) return [];

      final List<int> orderIds = ordersResponse
          .map<int>((dynamic r) => (r['order_id'] as num).toInt())
          .toList();

      final List<dynamic> payments = await _supabase
          .from('payment')
          .select('order_id, payment_status, receipt_url')
          .inFilter('order_id', orderIds);

      final Map<int, String>  paymentStatusMap = {};
      final Map<int, String?> receiptUrlMap    = {};

      for (final dynamic p in payments) {
        final int oid          = (p['order_id'] as num).toInt();
        paymentStatusMap[oid]  = p['payment_status'] ?? 'Pending';
        receiptUrlMap[oid]     = p['receipt_url'] as String?;
      }

      // ── Step 3: fetch customer profile once ──
      final dynamic userProfile = await _supabase
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      final String firstName = userProfile['first_name'] ?? '';
      final String lastName  = userProfile['last_name']  ?? '';
      final String phone     = userProfile['phone']      ?? '';
      final String fullName  = '$firstName $lastName'.trim().isEmpty
          ? 'Customer'
          : '$firstName $lastName'.trim();

      // ── Step 4: build Order list ──
      final List<Order> orders = [];

      for (final dynamic row in ordersResponse) {
        final Map<String, dynamic> map = row as Map<String, dynamic>;
        final int orderId = (map['order_id'] as num).toInt();

        final dynamic rawAddr = map['address'];
        final Map<String, dynamic> addr =
            rawAddr is Map<String, dynamic> ? rawAddr : {};

        final String street   = addr['street']   ?? '';
        final String city     = addr['city']      ?? '';
        final String zip      = addr['zip_code']  ?? '';
        final String landmark = addr['landmark']  ?? '';
        final String fullAddress = [street, city, zip]
            .where((s) => s.isNotEmpty)
            .join(', ');

        final List<dynamic>   rawItems = map['order_item'] ?? [];
        final List<OrderItem> items    = rawItems
            .map((dynamic i) =>
                OrderItem.fromMap(i as Map<String, dynamic>))
            .toList();

        String dateTime = '';
        if (map['created_at'] != null) {
          final DateTime dt  =
              DateTime.parse(map['created_at'].toString()).toLocal();
          final String month = dt.month.toString().padLeft(2, '0');
          final String day   = dt.day.toString().padLeft(2, '0');
          final String year  = dt.year.toString();
          final int    h12   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final String min   = dt.minute.toString().padLeft(2, '0');
          final String amPm  = dt.hour < 12 ? 'am' : 'pm';
          dateTime = '$month/$day/$year ${h12}:$min $amPm';
        }

        orders.add(Order(
          orderId:       orderId.toString(),
          customerName:  fullName,
          contact:       phone,
          landmark:      landmark,
          address:       fullAddress,
          totalAmount:   (map['total_amount'] as num).toDouble(),
          paymentMethod: map['payment_method'] ?? '',
          paymentStatus: paymentStatusMap[orderId] ?? 'Pending',
          orderStatus:   map['order_status'] ?? 'Pending',
          dateTime:      dateTime,
          items:         items,
          trackingUrl:   map['tracking_url'] as String?,   // ← add this
          receiptUrl:    receiptUrlMap[orderId],            // ← add this
        ));
      }

      return orders;
    } catch (e) {
      print('OrderHistoryService.getMyOrders error: $e');
      return [];
    }
  }

  // ================================================
  // FETCH SINGLE ORDER BY ID
  // Used when a notification needs to navigate straight to one
  // order (e.g. "TRACK SHIPMENT") without loading the entire order
  // history just to find it.
  // ================================================
  Future<Order?> fetchOrderById(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final int? parsedId = int.tryParse(orderId);
      if (parsedId == null) return null;

      final dynamic row = await _supabase
          .from('orders')
          .select('''
            order_id,
            total_amount,
            payment_method,
            order_status,
            tracking_url,
            created_at,
            address (
              street,
              city,
              zip_code,
              landmark
            ),
            order_item (
              product_name_snapshot,
              brand_snapshot,
              size_snapshot,
              quantity,
              unit_price,
              subtotal
            )
          ''')
          .eq('order_id', parsedId)
          .eq('user_id', user.id) // safety: only this customer's own order
          .maybeSingle();

      if (row == null) return null;

      final Map<String, dynamic> map = row as Map<String, dynamic>;

      final dynamic payment = await _supabase
          .from('payment')
          .select('payment_status, receipt_url')
          .eq('order_id', parsedId)
          .maybeSingle();

      final String paymentStatus =
          payment?['payment_status'] as String? ?? 'Pending';
      final String? receiptUrl = payment?['receipt_url'] as String?;

      final dynamic userProfile = await _supabase
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      final String firstName = userProfile['first_name'] ?? '';
      final String lastName  = userProfile['last_name']  ?? '';
      final String phone     = userProfile['phone']      ?? '';
      final String fullName  = '$firstName $lastName'.trim().isEmpty
          ? 'Customer'
          : '$firstName $lastName'.trim();

      final dynamic rawAddr = map['address'];
      final Map<String, dynamic> addr =
          rawAddr is Map<String, dynamic> ? rawAddr : {};

      final String street   = addr['street']   ?? '';
      final String city     = addr['city']      ?? '';
      final String zip      = addr['zip_code']  ?? '';
      final String landmark = addr['landmark']  ?? '';
      final String fullAddress = [street, city, zip]
          .where((s) => s.isNotEmpty)
          .join(', ');

      final List<dynamic>   rawItems = map['order_item'] ?? [];
      final List<OrderItem> items    = rawItems
          .map((dynamic i) => OrderItem.fromMap(i as Map<String, dynamic>))
          .toList();

      String dateTime = '';
      if (map['created_at'] != null) {
        final DateTime dt  =
            DateTime.parse(map['created_at'].toString()).toLocal();
        final String month = dt.month.toString().padLeft(2, '0');
        final String day   = dt.day.toString().padLeft(2, '0');
        final String year  = dt.year.toString();
        final int    h12   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final String min   = dt.minute.toString().padLeft(2, '0');
        final String amPm  = dt.hour < 12 ? 'am' : 'pm';
        dateTime = '$month/$day/$year ${h12}:$min $amPm';
      }

      return Order(
        orderId:       parsedId.toString(),
        customerName:  fullName,
        contact:       phone,
        landmark:      landmark,
        address:       fullAddress,
        totalAmount:   (map['total_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] ?? '',
        paymentStatus: paymentStatus,
        orderStatus:   map['order_status'] ?? 'Pending',
        dateTime:      dateTime,
        items:         items,
        trackingUrl:   map['tracking_url'] as String?,
        receiptUrl:    receiptUrl,
      );
    } catch (e) {
      print('OrderHistoryService.fetchOrderById error: $e');
      return null;
    }
  }
}