import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import '../../common/dialog/profile_dialog.dart';

class AdminTopBar extends ConsumerStatefulWidget {
  const AdminTopBar({super.key});

  @override
  ConsumerState<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends ConsumerState<AdminTopBar> {
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

                return FutureBuilder<Map<String, dynamic>?>(
                  future: Supabase.instance.client
                      .from('users')
                      .select('first_name, last_name, email, phone, role')
                      .eq('id', user.id)
                      .single()
                      .then((v) => v),
                  builder: (context, snapshot) {
                    String firstName = '';
                    String lastName = '';
                    String displayName = user.email ?? '';
                    String email = user.email ?? '';
                    String phone = '';
                    String role = '';

                    if (snapshot.hasData && snapshot.data != null) {
                      final data = snapshot.data!;
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