import 'package:supabase_flutter/supabase_flutter.dart';
import '../../super/activity_log/activity_log_service.dart';

class StockService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

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

      return null;
    } catch (error) {
      print('adjustStock error: $error');
      return 'Failed to adjust stock. Please try again.';
    }
  }
}