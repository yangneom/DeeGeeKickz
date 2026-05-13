import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth/auth_provider.dart';

// ================================================
// CASHIER TOP BAR
//
// Shows "Hello, [cashier name]" + profile icon
// on the top right — same pattern as admin
// ================================================
class CashierTopBar extends ConsumerWidget {
  const CashierTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Watch the current logged-in user
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

          // ── HELLO + NAME ──
          authState.when(
            data: (user) {
              if (user == null) {
                return const SizedBox.shrink();
              }

              // Fetch the cashier's first name from Firestore
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('user')
                    .doc(user.uid)
                    .get(),
                builder: (context, snapshot) {

                  String displayName = '';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final firstName = data['first_name'] as String? ?? '';
                    final lastName = data['last_name'] as String? ?? '';
                    displayName = '$firstName $lastName'.trim();
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
                        displayName.isEmpty ? 'Cashier' : displayName,
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

          // ── PROFILE ICON ──
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