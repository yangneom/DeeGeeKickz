import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/sale.dart';

class CashierSaleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // SAVE IN-STORE SALE
  // Saves to orders + order_item + payment tables
  // ================================================
  Future<String> saveSale({
    required Sale sale,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      // 1. Generate order number
      final String orderNumber = await _generateOrderNumber();

      // 2. Insert into orders table
      final String cashierId = _supabase.auth.currentUser!.id;

      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'user_id':         cashierId,
            'subtotal':        sale.subtotal,
            'shipping':        0,
            'total_amount':    sale.total,
            'payment_method':  sale.paymentMethod,
            'order_status':    'Completed',
            'order_type':      'In-Store',
            'discount_amount': sale.discount,
          })
          .select()
          .single();

      final int orderId = orderResponse['order_id'];

      // 3. Insert order items
      for (final item in cartItems) {
        await _supabase.from('order_item').insert({
          'order_id':             orderId,
          'product_id':           item['productId'],
          'size_id':              item['sizeId'],
          'quantity':             item['quantity'],
          'unit_price':           item['retailPrice'],
          'subtotal':             item['subtotal'],
          'product_name_snapshot': item['productName'],
          'brand_snapshot':       item['brand'],
          'color_snapshot':       item['color'],
          'size_snapshot':        item['size'],
        });

        // Deduct stock immediately for in-store sales
        if (item['sizeId'] != null) {
          await _deductStock(
            sizeId:   item['sizeId'],
            quantity: item['quantity'],
          );
        }
      }

      // 4. Insert payment record
      await _supabase.from('payment').insert({
        'order_id':       orderId,
        'payment_method': sale.paymentMethod,
        'amount_paid':    sale.total,
        'payment_status': 'Paid',
        'payment_date':   DateTime.now().toIso8601String(),
        'cash_recieved':  sale.cashPaid,
        'change_given':   sale.change,
      });

      return orderNumber;
    } catch (e) {
      print('CashierSaleService.saveSale error: $e');
      rethrow;
    }
  }

  // ================================================
  // DEDUCT STOCK
  // For in-store sales — deduct immediately
  // ================================================
  Future<void> _deductStock({
    required int sizeId,
    required int quantity,
  }) async {
    final row = await _supabase
        .from('product_variant_size')
        .select('stock_quantity')
        .eq('size_id', sizeId)
        .single();

    final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;

    await _supabase
        .from('product_variant_size')
        .update({'stock_quantity': stock - quantity})
        .eq('size_id', sizeId);
  }

  // ================================================
  // GENERATE ORDER NUMBER
  // ================================================
  Future<String> _generateOrderNumber() async {
    final DateTime now = DateTime.now();
    final String date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final response = await _supabase
        .from('orders')
        .select('order_id')
        .eq('order_type', 'In-Store');

    final int count = (response as List).length + 1;
    final String seq = count.toString().padLeft(4, '0');
    return 'DG-$date-$seq';
  }
}