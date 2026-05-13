import 'package:flutter/material.dart';

// ================================================
// CUSTOMER LIST ITEM
//
// This is ONE customer in the left side list
//
// Shows:
//   - Avatar with initials
//   - Customer name
//   - Last message preview
//   - Time stamp
//   - Unread badge (if has unread messages)
//
// Example:
// ┌─────────────────────────────────┐
// │ AT  Angel Tuazon        2:45 PM │
// │     Hello! I want to...      3  │
// └─────────────────────────────────┘
// ================================================
class CustomerListItem extends StatelessWidget {

  // customer name
  final String customerName;

  // last message preview
  final String lastMessage;

  // time of last message
  final String time;

  // number of unread messages
  // if 0 = no badge shown
  final int unreadCount;

  // is this customer currently selected
  final bool isSelected;

  // what happens when user taps this item
  final VoidCallback onTap;

  const CustomerListItem({
    super.key,
    required this.customerName,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isSelected,
    required this.onTap,
  });

  // ================================================
  // GET INITIALS
  // gets first letter of each word in name
  // example: 'Angel Tuazon' → 'AT'
  // ================================================
  String _getInitials(String name) {

    // split name by spaces
    List<String> words = name.split(' ');

    // this will hold initials
    String initials = '';

    // loop through each word
    for (int i = 0; i < words.length; i = i + 1) {

      // only take first 2 words
      if (i >= 2) {
        break;
      }

      // add first letter of each word
      if (words[i].isNotEmpty) {
        initials = initials + words[i][0].toUpperCase();
      }
    }

    return initials;
  }

  // ================================================
  // GET AVATAR COLOR
  // picks a color based on first letter of name
  // so same person always gets same color
  // ================================================
  Color _getAvatarBackgroundColor(String name) {

    // list of soft background colors
    List<Color> colors = [
      const Color(0xFFDBEAFE), // blue
      const Color(0xFFDCFCE7), // green
      const Color(0xFFFEF3C7), // amber
      const Color(0xFFFCE7F3), // pink
      const Color(0xFFEDE9FE), // purple
      const Color(0xFFFFEDD5), // orange
    ];

    // pick color based on first letter code
    int index = name.codeUnitAt(0) % colors.length;

    return colors[index];
  }

  // ================================================
  // GET AVATAR TEXT COLOR
  // darker version of background color
  // ================================================
  Color _getAvatarTextColor(String name) {

    List<Color> colors = [
      const Color(0xFF1D4ED8), // blue
      const Color(0xFF15803D), // green
      const Color(0xFFB45309), // amber
      const Color(0xFF9D174D), // pink
      const Color(0xFF6D28D9), // purple
      const Color(0xFFC2410C), // orange
    ];

    int index = name.codeUnitAt(0) % colors.length;

    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(

          // light blue background if selected
          // transparent if not selected
          color: isSelected == true
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,

          // blue left border if selected
          border: Border(
            left: BorderSide(
              color: isSelected == true
                  ? const Color(0xFF2563EB)
                  : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [

            // ── AVATAR CIRCLE ──
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _getAvatarBackgroundColor(customerName),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(customerName),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _getAvatarTextColor(customerName),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ── CUSTOMER INFO ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // customer name
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected == true
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // last message preview
                  Text(
                    lastMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── TIME + UNREAD BADGE ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                // time
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),

                const SizedBox(height: 4),

                // unread badge — only show if unreadCount > 0
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}