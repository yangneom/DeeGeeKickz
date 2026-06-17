import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> updateOrderStatus({
    required int orderId,
    required String status,
    String? adminNote,
  }) async {

    await _supabase
        .from('orders')
        .update({
          'order_status': status,
        })
        .eq('order_id', orderId);

    await _supabase
        .from('order_progress')
        .insert({
          'order_id': orderId,
          'status': status,
          'admin_note': adminNote,
        });
  }
}