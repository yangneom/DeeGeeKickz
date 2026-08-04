// lib/services/customer/notification/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

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

  // ── Realtime: Admin's own notifications ─────────────────────────
  // Filtered server-side by customer_id (this admin's UUID) since
  // that's the column Supabase realtime filters on here. recipient_role
  // is double-checked client-side as a safety net.
  RealtimeChannel subscribeToAdminNotifications(
    String userId,
    void Function(AppNotification notification) onInsert,
  ) {
    return _client
        .channel('notifications:admin:$userId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'notifications',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'customer_id',
            value:  userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row['recipient_role'] == 'admin') {
              onInsert(AppNotification.fromMap(row));
            }
          },
        )
        .subscribe();
  }

  // ── Realtime: Super Admin shared inbox ──────────────────────────
  // Not scoped to one customer_id — filtered by recipient_role instead,
  // matching the RLS policy added for the shared inbox.
  RealtimeChannel subscribeToSuperAdminNotifications(
    void Function(AppNotification notification) onInsert,
  ) {
    return _client
        .channel('notifications:super_admin')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'notifications',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'recipient_role',
            value:  'super_admin',
          ),
          callback: (payload) {
            onInsert(AppNotification.fromMap(payload.newRecord));
          },
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}