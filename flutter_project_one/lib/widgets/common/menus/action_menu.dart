import 'package:flutter/material.dart';

// ================================================
// ACTION MENU STYLE: the one look for the three-dot menu in a table row.
//
// It copies the Inventory table's menu exactly, so every table menu looks the
// same: a plain WHITE card (no Material 3 tint), a thin grey border, rounded
// corners, a soft shadow, at least 168px wide, and 40px rows with a 16px icon
// and 13px text. It opens just under the button.
//
// WHY the old Admin Account menu was pink: a PopupMenuButton that is not given
// a colour takes the theme's surface colour, and your theme is built from a
// black seed, which Material 3 turns into a pinkish tint. Giving the menu an
// explicit white colour and no tint removes it.
//
// Destructive actions stay recognisable by a red icon and red text, not by
// colouring the whole menu.
//
// The Inventory menu itself is NOT changed by this file.
// ================================================
class ActionMenuStyle {
  ActionMenuStyle._();

  static const Color background = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color text = Color(0xFF374151);
  static const Color icon = Color(0xFF6B7280);
  static const Color destructive = Color(0xFFDC2626);

  static const double elevation = 4;
  // Black at 20%: the same soft shadow the Inventory menu uses.
  static const Color shadow = Color(0x33000000);
  static const double minWidth = 168;
  static const double rowHeight = 40;

  static ShapeBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: border),
      );
}

/// One row of the menu: an icon and a label. Pass [destructive] for actions
/// like Disable or Reset 2FA.
PopupMenuItem<T> actionMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool destructive = false,
}) {
  final Color iconColor =
      destructive ? ActionMenuStyle.destructive : ActionMenuStyle.icon;
  final Color textColor =
      destructive ? ActionMenuStyle.destructive : ActionMenuStyle.text;

  return PopupMenuItem<T>(
    value: value,
    height: ActionMenuStyle.rowHeight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: textColor)),
      ],
    ),
  );
}