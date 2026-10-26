import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;

// ================================================
// STAFF DEVICE RULES  (one definition, used everywhere)
//
// Admin, Super Admin and Cashier accounts are for a desktop or laptop screen.
// They are NOT allowed:
//   1. in the mobile app (anything that is not the web);
//   2. in a phone's web browser. The browser reports its platform (Android or
//      iOS), which still catches a phone turned sideways, where the screen is
//      wider than 768 and a width check alone would let it through;
//   3. on any other web screen narrower than 768.
//
// WHY THIS IS ONE FILE: the same rule used to be copied into the login form
// and the global auth listener, with gaps (not checked at app start, not
// checked for staff who still had to set a password, skipped when the login
// form had already been replaced by another screen). Now the login form, the
// auth listener, app start-up and the three staff layouts all ask THIS file.
//
// HONEST LIMIT: a server cannot reliably tell a phone from a laptop (the
// browser decides what it reports). So this is a client-side rule for the
// intended device policy. It does not replace the real data protection, which
// stays in the database rules, and it can't stop someone who builds their own
// client. What it does is make sure every way into the staff screens through
// THIS app goes through the same check.
// ================================================

enum StaffDeviceBlock {
  /// The mobile app. It is Customer-only by design.
  nativeApp,

  /// A phone's web browser (reports Android or iOS).
  mobileBrowser,

  /// Any other web screen narrower than [StaffDeviceGuard.minDesktopWidth].
  smallScreen;

  /// The message shown to the person. [role] is only used to name the account.
  String messageFor(String? role) {
    final String who = (role == null || role.isEmpty) ? 'a staff account' : role;
    switch (this) {
      case StaffDeviceBlock.nativeApp:
        return 'This account type isn\'t supported on the mobile app. '
            'Please use the web version to log in as $who.';
      case StaffDeviceBlock.mobileBrowser:
      case StaffDeviceBlock.smallScreen:
        return 'The staff portal requires a desktop or laptop screen. '
            'Please log in as $who from a larger device.';
    }
  }
}

class StaffDeviceGuard {
  StaffDeviceGuard._();

  /// Narrower than this on the web counts as "not a desktop screen".
  static const double minDesktopWidth = 768;

  /// The roles the rule applies to. Customers are never affected.
  static const List<String> staffRoles = ['Admin', 'Super Admin', 'Cashier'];

  static bool isStaff(String? role) => role != null && staffRoles.contains(role);

  /// The rule itself, with every input passed in so it can be tested.
  /// Returns null when staff MAY use this device.
  ///
  /// [width] is the logical screen width, or null when it isn't known yet.
  /// An unknown width never blocks by itself (that would lock out a desktop
  /// during start-up); the platform rules still apply.
  static StaffDeviceBlock? blockFor({
    required bool isWeb,
    required TargetPlatform platform,
    required double? width,
  }) {
    if (!isWeb) return StaffDeviceBlock.nativeApp;

    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return StaffDeviceBlock.mobileBrowser;
    }

    if (width != null && width > 0 && width < minDesktopWidth) {
      return StaffDeviceBlock.smallScreen;
    }

    return null;
  }

  /// The rule applied to the device this code is running on.
  static StaffDeviceBlock? blockForThisDevice({double? width}) {
    return blockFor(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      width: width ?? currentLogicalWidth(),
    );
  }

  /// The logical width of the window, readable before any screen is built
  /// (for example in main(), or in a listener with no BuildContext).
  static double? currentLogicalWidth() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final view = views.first;
    final double ratio = view.devicePixelRatio;
    if (ratio <= 0) return null;
    return view.physicalSize.width / ratio;
  }
}