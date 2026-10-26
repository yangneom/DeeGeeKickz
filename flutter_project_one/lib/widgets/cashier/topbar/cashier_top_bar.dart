import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import '../../common/dialog/profile_dialog.dart';
import '../../common/dialog/password_reminder_dialog.dart';

class CashierTopBar extends ConsumerStatefulWidget {
  const CashierTopBar({super.key});

  @override
  ConsumerState<CashierTopBar> createState() => _CashierTopBarState();
}

class _CashierTopBarState extends ConsumerState<CashierTopBar> {
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
    // The same dialog for Admin, Super Admin and Cashier.
    showPasswordReminderDialog(
      context: context,
      onChangeNow: _openPasswordChange,
    );
  }

  // "Change Now": opens the profile dialog with the password section open.
  Future<void> _openPasswordChange() async {
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
        canEdit: false,
        autoOpenPasswordSection: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
                  String displayName = 'Cashier';
                  String email = user.email ?? '';
                  String phone = '';
                  String role = '';

                  if (data != null) {
                    firstName = data['first_name'] ?? '';
                    lastName = data['last_name'] ?? '';
                    displayName = '$firstName $lastName'.trim();
                    if (displayName.isEmpty) displayName = 'Cashier';
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Hello',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
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
    );
  }
}