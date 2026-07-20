import 'package:supabase_flutter/supabase_flutter.dart';
import '../../super/activity_log/activity_log_service.dart';

class StockService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  // Matches the "LOW STOCK" badge threshold already used in
  // shop_product_card.dart (product.totalAvailable <= 10).
  static const int _lowStockThreshold = 10;

  Future<String?> adjustStock({
    required int sizeId,
    required int adjustment,
    required bool isAddStock,
  }) async {
    if (adjustment <= 0) {
        return 'Adjustment must be greater than zero.';
      }
    try {
      await _supabase.rpc(
        'adjust_stock',
        params: {
          'p_size_id': sizeId,
          'p_delta': isAddStock ? adjustment : -adjustment,
        },
      );
      // Best-effort: fetch a human-readable product/size label for the log.
      String label = 'size #$sizeId';
      try {
        final row = await _supabase
            .from('product_variant_size')
            .select('size, product_variant(color_name, product(product_name))')
            .eq('size_id', sizeId)
            .single();

        final size = row['size'];
        final variant = row['product_variant'];
        final productName = variant?['product']?['product_name'];
        final colorName = variant?['color_name'];

        if (productName != null) {
          label = '$productName ($colorName, size $size)';
        }
      } catch (_) {
        // fall back to the generic label above
      }

      await _activityLog.log(
        action: isAddStock
            ? 'Added $adjustment stock to $label'
            : 'Removed $adjustment stock from $label',
        affectedModule: AffectedModule.inventory,
        targetId: sizeId.toString(),
        metadata: {'delta': isAddStock ? adjustment : -adjustment},
      );

      // Only removals can push stock down into low/out-of-stock —
      // adding stock never needs to trigger this notification.
      if (!isAddStock) {
        await _checkAndNotifyLowStock(sizeId: sizeId, label: label);
      }

      return null;
   } on PostgrestException catch (error) {
      print('adjustStock error: $error');

      if (error.code == '23514' && error.message.contains('reserved_not_exceed_stock')) {
        // This size has units currently reserved (in a cart / pending
        // order) that this reduction would drop below — fetch the
        // actual reserved count so the message is genuinely useful.
        try {
          final row = await _supabase
              .from('product_variant_size')
              .select('reserved_quantity')
              .eq('size_id', sizeId)
              .single();
          final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
          return 'Can\'t reduce below $reserved units — that many are currently reserved in customer carts or pending orders.';
        } catch (_) {
          return 'Can\'t reduce stock below the amount currently reserved in customer carts or pending orders.';
        }
      }

      return 'Failed to adjust stock. Please try again.';
    } catch (error) {
      print('adjustStock error: $error');
      return 'Failed to adjust stock. Please try again.';
    }
  }
  // ── Low/out-of-stock notification ────────────────────────────────
  // Fires after a stock removal. Notifies every Admin + Super Admin
// ── Low/out-of-stock notification ────────────────────────────────
  // Fires after a stock removal. Notifies every Admin + Super Admin
  // when the new quantity crosses into low-stock or out-of-stock range.
  Future<void> _checkAndNotifyLowStock({
    required int sizeId,
    required String label,
  }) async {
    print('LOWSTOCK CHECK: starting for sizeId=$sizeId');
    try {
      final row = await _supabase
          .from('product_variant_size')
          .select('stock_quantity')
          .eq('size_id', sizeId)
          .single();

      final int quantity = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      print('LOWSTOCK CHECK: quantity=$quantity, threshold=$_lowStockThreshold');

      if (quantity > _lowStockThreshold) {
        print('LOWSTOCK CHECK: quantity above threshold, skipping');
        return;
      }

      final bool isOutOfStock = quantity == 0;

      final staff = await _supabase
          .from('users')
          .select('id')
          .inFilter('role', ['Admin', 'Super Admin']);

      print('LOWSTOCK CHECK: staff found = $staff');

      if ((staff as List).isEmpty) {
        print('LOWSTOCK CHECK: no staff found, aborting');
        return;
      }

      final String title = isOutOfStock ? 'Out of stock' : 'Low stock alert';
      final String body = isOutOfStock
          ? '$label is now out of stock.'
          : '$label is running low ($quantity left).';
      final String type = isOutOfStock ? 'out_of_stock' : 'low_stock';

      final rows = staff.map((u) => {
            'customer_id': u['id'],
            'type': type,
            'title': title,
            'body': body,
          }).toList();

      print('LOWSTOCK CHECK: inserting rows = $rows');

      await _supabase.from('notifications').insert(rows);

      print('LOWSTOCK CHECK: insert completed');
    } catch (error) {
      print('LOWSTOCK CHECK ERROR: $error');
    }
  }
}