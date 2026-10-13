// ================================================
// FORM VALIDATORS — one place for the rules and the wording.
//
// Messages say what is wrong and how to fix it, always end with a
// period, and use the same phrasing on every form:
//   "First name is required."
//   "Please enter a valid email address."
//
// Name, Philippine phone and password rules are taken from the rules
// that were already live, so there is exactly one definition of each,
// not one per screen.
// ================================================

class FormValidators {
  FormValidators._();

  // Same pattern the login form and Add Account dialog already used.
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// "<Label> is required." — whitespace-only counts as empty.
  /// Pass trim: false for values that must never be modified or judged by
  /// their spaces (passwords).
  static String? requiredField(String? value, String label, {bool trim = true}) {
    final String v = trim ? (value ?? '').trim() : (value ?? '');
    return v.isEmpty ? '$label is required.' : null;
  }

  // ── PASSWORD POLICY — ONE number. Change it here and every form follows.
  // (Sign-up, reset and change-password used to disagree: 6 in some places,
  // 8 in others, with messages that didn't match the check.)
  static const int minPasswordLength = 8;

  // ── NAMES — letters of ANY language, so "José", "Peña", "Niño" and
  // "Dela Peña" are accepted (the old sign-up rule only allowed A–Z and
  // rejected them), plus spaces, hyphens, apostrophes and periods
  // ("De la Cruz", "O'Neil", "Jr.").
  static const int maxNameLength = 50;
  static final RegExp _nameRegex =
      RegExp(r"^[\p{L}][\p{L}\s\-'.]*$", unicode: true);

  /// [label] reads like "First name" — used at the start of the message.
  static String? personName(String? value, String label) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return '$label is required.';
    if (v.length > maxNameLength) {
      return '$label must be $maxNameLength characters or fewer.';
    }
    if (!_nameRegex.hasMatch(v)) {
      return '$label can only contain letters, spaces, hyphens, apostrophes and periods.';
    }
    return null;
  }

  // ── PHONE — the same Philippine mobile rule sign-up already used.
  static final RegExp _phPhoneRegex = RegExp(r'^(09\d{9}|\+639\d{9})$');

  static String? philippinePhone(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Phone number is required.';
    if (!_phPhoneRegex.hasMatch(v)) {
      return 'Enter a valid Philippine mobile number, for example 09171234567.';
    }
    return null;
  }

  // ── NEW PASSWORD (sign-up and reset). Not trimmed or altered here.
  static String? newPassword(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Please confirm your password.';
    if (v != original) return 'Passwords do not match.';
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required.';
    if (!_emailRegex.hasMatch(v)) return 'Please enter a valid email address.';
    return null;
  }
}