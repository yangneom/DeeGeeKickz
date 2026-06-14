import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';

/// Profile avatar, display name, and membership tier badge.
/// Sits above the section cards on [ProfileScreen].
class ProfileHeader extends StatelessWidget {
  final CustomerAccount account;

  const ProfileHeader({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Avatar with edit button ──────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar circle / square
            LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    MediaQuery.of(context).size.width >= 768 ? 160.0 : 128.0;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE), // surface-container
                    border: Border.all(
                      color: const Color(0xFFCFC4C5), // outline-variant
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 56,
                    color: Color(0xFF656464),
                  ),
                );
              },
            ),

            // Edit button — bottom-right corner
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  // TODO: open image picker
                },
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.black, // bg-primary
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.white, // on-primary
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16), // mb-md

        // ── Display Name ─────────────────────────────────────────
        Text(
          account.fullName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: MediaQuery.of(context).size.width >= 768 ? 32 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 4),

        // ── Membership tier ──────────────────────────────────────
        Text(
          'PERFORMANCE ELITE MEMBER',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: Color(0xFF656464), // on-secondary-container
          ),
        ),
      ],
    );
  }
}