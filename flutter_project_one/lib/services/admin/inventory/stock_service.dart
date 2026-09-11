import 'package:supabase_flutter/supabase_flutter.dart';
import '../../super/activity_log/activity_log_service.dart';

class StockService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  // Matches the "LOW STOCK" badge threshold used in SizeEntry.status
  // (product.dart) and ExpandableProductTable._resolveStatus — both
  // show the badge at 5, so the notification now fires at the same
  // cutoff instead of a size sitting at 6–10 units showing "Low
  // Stock" in the UI with no notification ever firing for it.
  static const int _lowStockThreshold = 5;

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

      // IMPORTANT: the stock adjustment itself already succeeded above —
      // logging and notifications are secondary effects and must never
      // cause this method to report failure back to the admin. Each is
      // wrapped in its own try/catch so a logging hiccup can't produce
      // a false "Failed to adjust stock" message that might prompt a
      // confused admin to retry and double-adjust.
      try {
        await _activityLog.log(
          action: isAddStock
              ? 'Added $adjustment stock to $label'
              : 'Removed $adjustment stock from $label',
          affectedModule: AffectedModule.inventory,
          targetId: sizeId.toString(),
          metadata: {'delta': isAddStock ? adjustment : -adjustment},
        );
      } catch (logError) {
        print('adjustStock: activity log failed (adjustment still succeeded): $logError');
      }
      // Low/out-of-stock notifications now fire automatically from
      // the trg_check_low_stock database trigger on ANY stock_quantity
      // change — covers manual adjustment, cashier sales, and order
      // approval commits from one place. Calling it again here would
      // duplicate the notification (confirmed: admins were seeing
      // every low-stock alert exactly twice).

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
          return 'Can\'t reduce below $reserved units, that many are currently reserved in customer carts or pending orders.';
        } catch (_) {
          return 'Can\'t reduce stock below the amount currently reserved in customer carts or pending orders.';
        }
      }

      if (error.code == '23514' && error.message.contains('stock_quantity_non_negative')) {
        // Tried to remove more units than physically exist at all
        // (distinct from the reserved-stock case above).
        try {
          final row = await _supabase
              .from('product_variant_size')
              .select('stock_quantity')
              .eq('size_id', sizeId)
              .single();
          final int current = (row['stock_quantity'] as num?)?.toInt() ?? 0;
          return 'Can\'t remove more than the $current unit(s) currently in stock.';
        } catch (_) {
          return 'Can\'t remove more units than are currently in stock.';
        }
      }

      return 'Failed to adjust stock. Please try again.';    } catch (error) {
      print('adjustStock error: $error');
      return 'Failed to adjust stock. Please try again.';
    }
  }

  // ── Low/out-of-stock notification ────────────────────────────────
  // Fires after a stock removal. Notifies every Admin when the new
  // quantity crosses into low-stock or out-of-stock range.
  //
  // FIX (this round): the insert was missing the `recipient_role`
  // field entirely. The notifications table defaults that column to
  // 'customer', so every low-stock/out-of-stock row was silently
  // filed under the wrong bucket and could never appear on the Admin
  // notification screen (which filters recipient_role = 'admin').
  // No error was ever thrown — it just wrote to a bucket nobody reads.
  //
  // Also narrowed the staff query back to Admin only (previously
  // queried Admin + Super Admin) — stock alerts are operational and
  // Super Admin's notification scope is feedback-only, matching the
  // same pattern used for order and chat notifications elsewhere.
  Future<void> _checkAndNotifyLowStock({
    required int sizeId,
    required String label,
  }) async {
    print('🔔🔔🔔 _checkAndNotifyLowStock CALLED for size #$sizeId 🔔🔔🔔');
    try {
      await _supabase.rpc('notify_staff_low_stock', params: {
        'p_size_id': sizeId,
        'p_label': label,
      });
      print('🔔 Low stock RPC completed successfully');
    } catch (error) {
      print('_checkAndNotifyLowStock error: $error');
    }
  }
}