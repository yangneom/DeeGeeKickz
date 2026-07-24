// lib/services/customer/notification/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Fetch all notifications for current user ───────────────────
// ── Fetch all notifications for current user ───────────────────
// ── Fetch: Customer's own notifications ─────────────────────────
  Future<List<AppNotification>> fetchNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('customer_id', userId)
        .eq('recipient_role', 'customer')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Fetch: this Admin's own notifications ────────────────────────
  Future<List<AppNotification>> fetchAdminNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('customer_id', userId)
        .eq('recipient_role', 'admin')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Fetch: Super Admin shared inbox (not tied to one account) ────
  Future<List<AppNotification>> fetchSuperAdminNotifications() async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('recipient_role', 'super_admin')
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
 // ── Mark all as read: Customer ────────────────────────────────
  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('customer_id', userId)
        .eq('recipient_role', 'customer')
        .eq('is_read', false);
  }

  // ── Mark all as read: Admin ────────────────────────────────────
  Future<void> markAdminAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('customer_id', userId)
        .eq('recipient_role', 'admin')
        .eq('is_read', false);
  }

  // ── Mark all as read: Super Admin (shared inbox) ────────────────
  Future<void> markSuperAdminAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_role', 'super_admin')
        .eq('is_read', false);
  }
}