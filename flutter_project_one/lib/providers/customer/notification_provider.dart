// lib/providers/customer/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel, Supabase;
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

// ── Notifier: Customer ──────────────────────────────────────────────────────────
class NotificationNotifier extends Notifier<NotificationState> {
  RealtimeChannel? _channel;

  @override
  NotificationState build() {
    ref.onDispose(_cancelSubscription);
    Future.microtask(() async {
      await loadNotifications();
      if (!ref.mounted) return;
      _subscribeRealtime();
    });
    return const NotificationState(isLoading: true);
  }

  NotificationService get _service =>
      ref.read(notificationServiceProvider);

  // ── Realtime: live-insert new notifications as Customer ─────────
  void _subscribeRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _cancelSubscription();

    _channel = _service.subscribeToCustomerNotifications(userId, (notification) {
      if (!ref.mounted) return;
      final alreadyPresent =
          state.notifications.any((n) => n.id == notification.id);
      if (!alreadyPresent) {
        state = state.copyWith(
          notifications: [notification, ...state.notifications],
        );
      }
    });
  }

  void _cancelSubscription() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
      _channel = null;
    }
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _service.fetchNotifications();
      if (!ref.mounted) return;
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications.',
      );
    }
  }

  Future<void> markRead(String notificationId) async {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList(),
    );
    try {
      await _service.markRead(notificationId);
    } catch (_) {
      await loadNotifications();
    }
  }

  Future<void> markAllRead() async {
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

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

// ── Notifier: Admin ──────────────────────────────────────────────────────────────
class AdminNotificationNotifier extends Notifier<NotificationState> {
  RealtimeChannel? _channel;

  @override
  NotificationState build() {
    ref.onDispose(_cancelSubscription);
    Future.microtask(() async {
      await loadNotifications();
      if (!ref.mounted) return;
      _subscribeRealtime();
    });
    return const NotificationState(isLoading: true);
  }

  NotificationService get _service =>
      ref.read(notificationServiceProvider);

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _service.fetchAdminNotifications();
      if (!ref.mounted) return;
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications.',
      );
    }
  }

  // ── Realtime: live-insert new notifications as Admin ────────────
  void _subscribeRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _cancelSubscription();

    _channel = _service.subscribeToAdminNotifications(userId, (notification) {
      if (!ref.mounted) return;
      final alreadyPresent =
          state.notifications.any((n) => n.id == notification.id);
      if (!alreadyPresent) {
        state = state.copyWith(
          notifications: [notification, ...state.notifications],
        );
      }
    });
  }

  void _cancelSubscription() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
      _channel = null;
    }
  }

  Future<void> markRead(String notificationId) async {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList(),
    );
    try {
      await _service.markRead(notificationId);
    } catch (_) {
      await loadNotifications();
    }
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
    );
    try {
      await _service.markAdminAllRead();
    } catch (_) {
      await loadNotifications();
    }
  }
}

final adminNotificationProvider =
    NotifierProvider<AdminNotificationNotifier, NotificationState>(() {
  return AdminNotificationNotifier();
});

// ── Notifier: Super Admin (shared inbox) ──────────────────────────────────────────
class SuperAdminNotificationNotifier extends Notifier<NotificationState> {
  RealtimeChannel? _channel;

  @override
  NotificationState build() {
    ref.onDispose(_cancelSubscription);
    Future.microtask(() async {
      await loadNotifications();
      if (!ref.mounted) return;
      _subscribeRealtime();
    });
    return const NotificationState(isLoading: true);
  }

  NotificationService get _service =>
      ref.read(notificationServiceProvider);

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _service.fetchSuperAdminNotifications();
      if (!ref.mounted) return;
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications.',
      );
    }
  }

  // ── Realtime: shared inbox, not scoped to one user ───────────────
  void _subscribeRealtime() {
    _cancelSubscription();

    _channel = _service.subscribeToSuperAdminNotifications((notification) {
      if (!ref.mounted) return;
      final alreadyPresent =
          state.notifications.any((n) => n.id == notification.id);
      if (!alreadyPresent) {
        state = state.copyWith(
          notifications: [notification, ...state.notifications],
        );
      }
    });
  }

  void _cancelSubscription() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
      _channel = null;
    }
  }

  Future<void> markRead(String notificationId) async {
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList(),
    );
    try {
      await _service.markRead(notificationId);
    } catch (_) {
      await loadNotifications();
    }
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
    );
    try {
      await _service.markSuperAdminAllRead();
    } catch (_) {
      await loadNotifications();
    }
  }
}

final superAdminNotificationProvider =
    NotifierProvider<SuperAdminNotificationNotifier, NotificationState>(() {
  return SuperAdminNotificationNotifier();
});