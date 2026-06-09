import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  final SupabaseClient _supabase = Supabase.instance.client;

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

      return null;
    } catch (error) {
      print('adjustStock error: $error');
      return 'Failed to adjust stock. Please try again.';
    }
  }
}