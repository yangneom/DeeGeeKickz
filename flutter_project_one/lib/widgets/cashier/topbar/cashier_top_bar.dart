import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';

class CashierTopBar extends ConsumerWidget {
  const CashierTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

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

              return FutureBuilder<Map<String, dynamic>?>(
                future: Supabase.instance.client
                    .from('users')
                    .select('first_name, last_name')
                    .eq('id', user.id)
                    .single()
                    .then((v) => v),
                builder: (context, snapshot) {
                  String displayName = 'Cashier';

                  if (snapshot.hasData && snapshot.data != null) {
                    final first = snapshot.data!['first_name'] ?? '';
                    final last = snapshot.data!['last_name'] ?? '';
                    displayName = '$first $last'.trim();
                    if (displayName.isEmpty) displayName = 'Cashier';
                  }

                  return Column(
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
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(width: 12),

          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 20,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}