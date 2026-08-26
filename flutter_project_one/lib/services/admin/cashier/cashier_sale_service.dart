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
    String? referenceNumber,
  }) async {
    try {
      

      final String cashierId = _supabase.auth.currentUser!.id;

// Order number is derived from the real order_id (a DB-generated
      // serial, guaranteed unique) instead of a client-side row count —
      // no race condition possible between two simultaneous checkouts.
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

        final String orderNumber = _orderNumberFromId(orderId);

      // Attach the cashier-entered reference number to the payment
      // row process_cashier_sale already created. Only online
      // (GCash/Maya/Card) sales have one — cash sales pass null.
      if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
        await _supabase
            .from('payment')
            .update({'reference_number': referenceNumber.trim()})
            .eq('order_id', orderId);
      }
      // 5. Generate + upload PDF receipt, save receipt_url to the
      // payment row. Reuses the same ReceiptPdfService the online
      // order flow already uses — just fills in placeholder
      // customer info since this is a walk-in, in-store sale.
      //
      // isInStore: true — this is a walk-in sale with no delivery
      // leg, so the receipt should never show a Shipping row at all
      // (previously it always showed "Shipping: FREE" here, which
      // was misleading on an in-store receipt).
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

        await ReceiptPdfService().generateAndUpload(
          receiptOrder,
          isInStore: true,
        );
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
  // Built from the real order_id (unique, DB-assigned) instead of a
  // counted row query — eliminates the race condition where two
  // simultaneous checkouts could produce the same receipt number.
  // ================================================
  String _orderNumberFromId(int orderId) {
    final DateTime now = DateTime.now();
    final String date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'DG-$date-${orderId.toString().padLeft(4, '0')}';
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