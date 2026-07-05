// lib/services/customer/notification/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Fetch all notifications for current user ───────────────────
  Future<List<AppNotification>> fetchNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Mark one notification as read ─────────────────────────────
  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('notification_id', int.parse(notificationId));
  }

  // ── Mark all notifications as read ────────────────────────────
  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('customer_id', userId)
        .eq('is_read', false);
  }
}