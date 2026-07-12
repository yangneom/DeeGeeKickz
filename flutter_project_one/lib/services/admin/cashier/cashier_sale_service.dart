import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/sale.dart';
import '../../../models/order.dart';
import '../../customer/receipt/receipt_pdf_service.dart';
import '../../super/activity_log/activity_log_service.dart';

class CashierSaleService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

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
        final double costPrice = await _getCostPrice(item['sizeId'] as int?);

        await _supabase.from('order_item').insert({
          'order_id':             orderId,
          'product_id':           item['productId'],
          'size_id':              item['sizeId'],
          'quantity':             item['quantity'],
          'unit_price':           item['retailPrice'],
          'subtotal':             item['subtotal'],
          'cost_price_snapshot':  costPrice,
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

      // 5. Generate + upload PDF receipt, save receipt_url to the
      // payment row. Reuses the same ReceiptPdfService the online
      // order flow already uses — just fills in placeholder
      // customer info since this is a walk-in, in-store sale.
      try {
        final List<OrderItem> orderItems = cartItems.map((item) {
          final int parsedSize =
              int.tryParse(item['size'].toString()) ?? 0;
          return OrderItem(
            productName: item['productName'] ?? '',
            brand:       item['brand'] ?? '',
            size:        parsedSize,
            quantity:    (item['quantity'] as num).toInt(),
            price:       (item['retailPrice'] as num).toDouble(),
            total:       (item['subtotal'] as num).toDouble(),
          );
        }).toList();

        final Order receiptOrder = Order(
          orderId:       orderId.toString(),
          customerName:  'Walk-in Customer',
          contact:       '',
          landmark:      '',
          address:       '',
          totalAmount:   sale.total,
          paymentMethod: sale.paymentMethod,
          paymentStatus: 'Paid',
          orderStatus:   'Completed',
          dateTime:      sale.transactionDate.toIso8601String(),
          items:         orderItems,
        );

        await ReceiptPdfService().generateAndUpload(receiptOrder);
      } catch (receiptErr) {
        // Don't fail the whole sale just because PDF generation or
        // upload failed — the sale itself is already saved correctly.
        print('CashierSaleService.saveSale receipt error: $receiptErr');
      }

      // 6. Log the completed sale.
      final String itemSummary = cartItems.length == 1
          ? (cartItems.first['productName']?.toString() ?? 'item')
          : '${cartItems.length} items';

      await _activityLog.log(
        action: 'Completed in-store sale of $itemSummary '
            '(₱${sale.total.toStringAsFixed(2)})',
        affectedModule: AffectedModule.sales,
        targetId: orderId.toString(),
        metadata: {
          'order_number': orderNumber,
          'total': sale.total,
          'payment_method': sale.paymentMethod,
          'item_count': cartItems.length,
        },
      );

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

  Future<double> _getCostPrice(int? sizeId) async {
    if (sizeId == null) return 0;
    try {
      final row = await _supabase
          .from('product_variant_size')
          .select('product_variant(cost_price)')
          .eq('size_id', sizeId)
          .single();
      final variant = row['product_variant'];
      return (variant?['cost_price'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      print('_getCostPrice error: $e');
      return 0;
    }
  }
}