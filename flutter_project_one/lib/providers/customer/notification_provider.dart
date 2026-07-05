// lib/providers/customer/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../services/customer/notification/notification_service.dart';

// ── Service provider ───────────────────────────────────────────────────────────
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ── State ──────────────────────────────────────────────────────────────────────
class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => n.isUnread).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading:     isLoading     ?? this.isLoading,
      error:         error,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() {
    // Kick off initial load
    Future.microtask(loadNotifications);
    return const NotificationState(isLoading: true);
  }

  NotificationService get _service =>
      ref.read(notificationServiceProvider);

  // ── Load ────────────────────────────────────────────────────
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _service.fetchNotifications();
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications.',
      );
    }
  }

  // ── Mark one read ───────────────────────────────────────────
  Future<void> markRead(String notificationId) async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList(),
    );
    try {
      await _service.markRead(notificationId);
    } catch (_) {
      // Revert on failure
      await loadNotifications();
    }
  }

  // ── Mark all read ───────────────────────────────────────────
  Future<void> markAllRead() async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
    );
    try {
      await _service.markAllRead();
    } catch (_) {
      await loadNotifications();
    }
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});