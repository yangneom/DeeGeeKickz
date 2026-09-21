import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import '../../common/dialog/profile_dialog.dart';

class SuperTopBar extends ConsumerStatefulWidget {
  const SuperTopBar({super.key});

  @override
  ConsumerState<SuperTopBar> createState() => _SuperTopBarState();
}

class _SuperTopBarState extends ConsumerState<SuperTopBar> {
  final AuthService _authService = AuthService();
  bool _reminderChecked = false;

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Time to update your password'),
        content: const Text(
          'For account security, please update your password. '
          'It\'s been 30 days or more since your last change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

                       final data = await ref.read(ownProfileProvider.future);

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => ProfileDialog(
                  userId: user.id,
                  firstName: data?['first_name'] ?? '',
                  lastName: data?['last_name'] ?? '',
                  email: data?['email'] ?? user.email ?? '',
                  phone: data?['phone'] ?? '',
                  role: data?['role'] ?? '',
                  canEdit: true,
                  autoOpenPasswordSection: true,
                ),
              );
            },
            child: const Text('Change Now'),
          ),
        ],
      ),
    );
  }

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
            GestureDetector(
              onTap: () => print('Notification tapped'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade200,
            ),

            const SizedBox(width: 12),

            // ── PROFILE SECTION ──
            authState.when(
              data: (state) {
                final user = state.session?.user;
                if (user == null) return const SizedBox.shrink();

                ref.watch(ownProfileRealtimeProvider);
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
                      if (displayName.isEmpty) {
                        displayName = user.email ?? '';
                      }
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
                            canEdit: true,
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