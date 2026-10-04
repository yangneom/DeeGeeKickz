import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import '../../common/dialog/profile_dialog.dart';
import '../../../models/notification_model.dart';
import '../../../providers/customer/notification_provider.dart';
import '../../../screens/admin/notification/admin_notification_screen.dart';

class AdminTopBar extends ConsumerStatefulWidget {
  // Optional: lets AdminLayout hand the top bar its sidebar-switching
  // callback, so tapping a notification inside the "See All" page can
  // still jump to the right section (Orders, Feedback, ...) after the
  // page closes. Optional, so any existing `const AdminTopBar()` call
  // keeps compiling.
  final ValueChanged<int>? onNavigate;

  const AdminTopBar({super.key, this.onNavigate});

  @override
  ConsumerState<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends ConsumerState<AdminTopBar> {
  final AuthService _authService = AuthService();
  bool _reminderChecked = false;

  // The notification popover lives in Flutter's real Overlay layer (via
  // OverlayPortal) so it paints ABOVE the dashboard content. A plain
  // Stack/Positioned can't do that: the content area is a later sibling
  // of the top bar, so it always paints over anything the top bar draws.
  final OverlayPortalController _notificationOverlayController =
      OverlayPortalController();
  final LayerLink _notificationLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPasswordReminder());
  }

  Future<void> _checkPasswordReminder() async {
    if (_reminderChecked) return;
    _reminderChecked = true;

    final due = await _authService.isPasswordChangeDue();
    if (!mounted || !due) return;

    _showPasswordReminderDialog();
  }

  void _showPasswordReminderDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time to update your password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'For account security',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'It\'s been 30 days or more since your last password change. '
                      'Please update it to keep your account secure.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF374151),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Later', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) return;

                              final data = await Supabase.instance.client
                                  .from('users')
                                  .select('first_name, last_name, email, phone, role')
                                  .eq('id', user.id)
                                  .single();

                              if (!mounted) return;
                              showDialog(
                                context: context,
                                builder: (_) => ProfileDialog(
                                  userId: user.id,
                                  firstName: data['first_name'] ?? '',
                                  lastName: data['last_name'] ?? '',
                                  email: data['email'] ?? user.email ?? '',
                                  phone: data['phone'] ?? '',
                                  role: data['role'] ?? '',
                                  canEdit: false,
                                  autoOpenPasswordSection: true,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Change Now', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // NOTIFICATIONS
  // ================================================

  Widget _buildNotificationBell() {
    final int unread = ref.watch(adminNotificationProvider).unreadCount;

    return GestureDetector(
      onTap: () => _notificationOverlayController.toggle(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Full-screen transparent barrier (outside-tap closes the popover)
  // plus the popover itself, anchored to the bell via the LayerLink —
  // no hardcoded screen coordinates, so it stays attached to the bell
  // at any window width.
  Widget _buildNotificationOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _notificationOverlayController.hide(),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _notificationLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: _buildNotificationPopover(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationPopover() {
    // Material(transparency) gives the popover's Text widgets a Material
    // ancestor (without one, debug builds draw a yellow double underline
    // under all text) without adding an elevation tint of its own.
    return Material(
      type: MaterialType.transparency,
      child: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(adminNotificationProvider);
          final List<AppNotification> recent =
              state.notifications.take(5).toList();

          return Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openAllNotifications,
                        child: const Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: recent.map((n) {
                          return InkWell(
                            onTap: () {
                              // Mark as read using the existing provider logic.
                              ref.read(adminNotificationProvider.notifier).markRead(n.id);
                              final int? target = _moduleIndexFor(n);
                              if (target != null && widget.onNavigate != null) {
                                _notificationOverlayController.hide();
                                widget.onNavigate!(target);
                              } else {
                                // No matching module (or no layout callback): fall back
                                // to the full notifications page.
                                _openAllNotifications();
                              }
                            },
                            child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF3F4F6)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: n.isUnread
                                        ? const Color(0xFF2563EB)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.timeAgo,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ));
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Maps a notification's type to the AdminLayout sidebar index of the
  // module it belongs to: 0 Dashboard, 1 Inventory, 2 Sales, 3 Feedback,
  // 4 Messages, 5 Orders, 6 Promotions. null = no matching module.
  int? _moduleIndexFor(AppNotification n) {
    switch (n.type) {
      case NotificationType.order:
      case NotificationType.orderCancellation:
        return 5;
      case NotificationType.lowStock:
      case NotificationType.outOfStock:
        return 1;
      case NotificationType.newFeedback:
      case NotificationType.adminReply:
        return 3;
      case NotificationType.newMessage:
        return 4;
      case NotificationType.promotion:
      case NotificationType.newArrival:
        return 6;
      case NotificationType.salesAlert:
        return 2;
      case NotificationType.adminActivity:
        return null;
    }
  }

  // "See All" — opens the existing full Notifications screen on its own
  // page with a proper back button. The page is wrapped in a Scaffold
  // (which also supplies the Material ancestor the screen needs when
  // shown outside AdminLayout), and tapping a notification inside it
  // closes the page first, then asks the layout to switch sections.
  void _openAllNotifications() {
    _notificationOverlayController.hide();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: const Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
                color: Color(0xFF374151),
              ),
              onPressed: () => Navigator.of(routeContext).pop(),
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          body: AdminNotificationsScreen(
            onNavigate: (int index) {
              Navigator.of(routeContext).pop();
              widget.onNavigate?.call(index);
            },
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            const Spacer(),

            // ── NOTIFICATION BELL ──
            CompositedTransformTarget(
              link: _notificationLayerLink,
              child: OverlayPortal(
                controller: _notificationOverlayController,
                overlayChildBuilder: (context) => _buildNotificationOverlay(),
                child: _buildNotificationBell(),
              ),
            ),

            const SizedBox(width: 12),

            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade200,
            ),

            const SizedBox(width: 12),

            // ── PROFILE SECTION — Realtime-aware ──
            authState.when(
              data: (state) {
                final user = state.session?.user;
                if (user == null) return const SizedBox.shrink();

                ref.watch(ownProfileRealtimeProvider); // activates the subscription
                final profileAsync = ref.watch(ownProfileProvider);

                return profileAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    String firstName = '';
                    String lastName = '';
                    String displayName = user.email ?? '';
                    String email = user.email ?? '';
                    String phone = '';
                    String role = '';

                    if (data != null) {
                      firstName = data['first_name'] ?? '';
                      lastName = data['last_name'] ?? '';
                      displayName = '$firstName $lastName'.trim();
                      if (displayName.isEmpty) displayName = user.email ?? '';
                      email = data['email'] ?? email;
                      phone = data['phone'] ?? '';
                      role = data['role'] ?? '';
                    }

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => ProfileDialog(
                            userId: user.id,
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            phone: phone,
                            role: role,
                            canEdit: false,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(
                              Icons.person,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hello',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}