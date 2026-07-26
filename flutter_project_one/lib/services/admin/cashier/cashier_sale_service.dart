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
      // 1. Generate order number (still needed for the printed
      // receipt/order number label — the RPC uses its own real
      // order_id as the DB primary key, this is just the display code)
      final String orderNumber = await _generateOrderNumber();

      final String cashierId = _supabase.auth.currentUser!.id;

      // 2-4. Order + items (with stock check) + payment — all done
      // atomically inside one Postgres transaction via RPC. If any
      // item fails the availability check, EVERYTHING rolls back:
      // no order, no order_item rows, no stock deducted, no payment
      // row. No more risk of a partial sale leaving stock silently
      // wrong when one item in a multi-item cart fails.
      final int orderId = await _supabase.rpc('process_cashier_sale', params: {
        'p_cashier_id':      cashierId,
        'p_subtotal':        sale.subtotal,
        'p_discount_amount': sale.discount,
        'p_total_amount':    sale.total,
        'p_payment_method':  sale.paymentMethod,
        'p_cash_received':   sale.cashPaid,
        'p_change_given':    sale.change,
        'p_items': cartItems.map((item) => {
          'productId':   item['productId'],
          'sizeId':      item['sizeId'],
          'productName': item['productName'],
          'brand':       item['brand'],
          'color':       item['color'],
          'size':        item['size'],
          'quantity':    item['quantity'],
          'retailPrice': item['retailPrice'],
          'subtotal':    item['subtotal'],
        }).toList(),
      }) as int;

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