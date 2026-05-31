import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';

// ================================================
// SUPER ADMIN TOP BAR
// same pattern as admin_top_bar.dart
// ================================================
class SuperTopBar extends ConsumerWidget {
  const SuperTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

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
                      .select('first_name, last_name')
                      .eq('id', user.id)
                      .single()
                      .then((v) => v),
                  builder: (context, snapshot) {

                    String displayName = user.email ?? '';

                    if (snapshot.hasData && snapshot.data != null) {
                      final first = snapshot.data!['first_name'] ?? '';
                      final last = snapshot.data!['last_name'] ?? '';
                      displayName = '$first $last'.trim();
                      if (displayName.isEmpty) {
                        displayName = user.email ?? '';
                      }
                    }

                    return Row(
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