import 'package:supabase_flutter/supabase_flutter.dart';

class OrderManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;

Future<void> updateOrderStatus({
  required int orderId,
  required String status,
  String? adminNote,
}) async {

  print('Updating order $orderId');

  final before = await _supabase
      .from('orders')
      .select()
      .eq('order_id', orderId);

  print('BEFORE UPDATE = $before');

  final result = await _supabase
      .from('orders')
      .update({
        'order_status': status,
      })
      .eq('order_id', orderId)
      .select();

  print('UPDATE RESULT = $result');

  final after = await _supabase
      .from('orders')
      .select()
      .eq('order_id', orderId);

  print('AFTER UPDATE = $after');

  final progress = await _supabase
      .from('order_progress')
      .insert({
        'order_id': orderId,
        'status': status,
        'admin_note': adminNote,
      })
      .select();

  print('PROGRESS RESULT = $progress');
}
}