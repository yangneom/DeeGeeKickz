import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth/auth_provider.dart';
// ================================================
// ADMIN TOP BAR
//
// This is the bar that appears at the very TOP
// of every admin screen.
//
// It contains:
//   - Notification bell icon on the right
//   - Profile avatar + name on the right
//
// The sidebar is on the LEFT side
// This top bar is at the TOP
// ================================================
class AdminTopBar extends ConsumerWidget {

  const AdminTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // ── GET CURRENT USER ──
    // watch the auth state to get logged in user info
    final authState = ref.watch(authStateProvider);

    // this will hold the user's name
    String userName = '';

    // get the user name from auth state
    authState.whenData((user) {

      // check if user is logged in
      if (user != null) {

        // use display name if available
        // otherwise use email
        if (user.displayName != null) {
          userName = user.displayName!;
        } else if (user.email != null) {
          userName = user.email!;
        }
      }
    });

    // ── BUILD THE TOP BAR ──
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        // white background
        color: Colors.white,

        // bottom border line
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

            // spacer pushes notification and profile
            // all the way to the RIGHT side
            const Spacer(),

            // ── NOTIFICATION BELL ICON ──
            GestureDetector(
              onTap: () {
                // TODO: open notifications later
                print('Notification tapped');
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // light gray background
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

            // ── VERTICAL DIVIDER LINE ──
            // thin line between bell and profile
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade200,
            ),

            const SizedBox(width: 12),

            // ── PROFILE SECTION ──
            // shows avatar circle + hello + name
            Row(
              children: [

                // gray circle with person icon
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

                // hello text and user name
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // small "Hello" label above name
                    const Text(
                      'Hello',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // user name below hello
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      // if name is too long show ...
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}