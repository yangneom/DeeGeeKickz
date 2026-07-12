import 'package:supabase_flutter/supabase_flutter.dart';
import '../../super/activity_log/activity_log_service.dart';

// NOTE: This service overlaps significantly with
// OrderManagementService.updateOrderStatus() — that one also
// handles tracking URLs and the COD payment-status flip on
// Completed. Worth checking whether this file is still called
// anywhere, or if it's leftover from before OrderManagementService
// was built out. Logging is added here regardless so nothing
// silently skips the audit trail if it IS still in use.

class AdminOrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

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

    await _activityLog.log(
      action: status == 'Cancelled'
          ? 'Cancelled order #$orderId'
              '${adminNote != null && adminNote.trim().isNotEmpty ? ' (reason: $adminNote)' : ''}'
          : 'Updated order #$orderId status to $status',
      affectedModule: AffectedModule.orders,
      targetId: orderId.toString(),
      metadata: {
        'status': status,
        if (adminNote != null) 'admin_note': adminNote,
      },
    );
  }
}