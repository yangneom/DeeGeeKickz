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

  // ── PHONE BOX WITH A FIXED "+63" — the user types only the 10 digits after
  // it (for example 9171234567). Philippine mobile numbers start with 9.
  static String? nationalPhone(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Phone number is required.';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Use digits only.';
    if (!v.startsWith('9')) {
      return 'Philippine mobile numbers start with 9, for example 9171234567.';
    }
    if (v.length > 10) {
      return 'Too many digits. Enter exactly 10 digits after +63.';
    }
    if (v.length < 10) {
      return 'Too few digits. Enter all 10 digits after +63, for example 9171234567.';
    }
    return null;
  }

  // ── STRONG PASSWORD (the staff Profile Security change-password form) ──
  // At least 8 characters, an uppercase letter, a lowercase letter, a number and
  // a special character. "Special" = any ASCII punctuation or symbol, which is
  // what Supabase Auth's own "symbols" rule counts, so this form and the backend
  // do not disagree. A password is never trimmed or altered: one that starts or
  // ends with a space is refused with a message instead of being silently
  // changed. Returns the FIRST problem, in the order a person would fix them.
  static final RegExp _hasUpper = RegExp(r'[A-Z]');
  static final RegExp _hasLower = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'[0-9]');
  static final RegExp _hasSpecial = RegExp(r'[!-/:-@\[-`{-~]');

  static String? strongPassword(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'New password is required.';
    if (v != v.trim()) return 'Password can\'t start or end with a space.';
    if (v.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (!_hasUpper.hasMatch(v)) return 'Add at least one uppercase letter (A to Z).';
    if (!_hasLower.hasMatch(v)) return 'Add at least one lowercase letter (a to z).';
    if (!_hasDigit.hasMatch(v)) return 'Add at least one number (0 to 9).';
    if (!_hasSpecial.hasMatch(v)) {
      return 'Add at least one special character, for example ! @ # % &.';
    }
    return null;
  }

  // ── NEW PASSWORD (sign-up and reset). Not trimmed or altered here.
  // (The staff Profile Security form uses strongPassword above.)
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

  // ── GMAIL ONLY — customer sign-up (and, later, customer email change) ──
  // Login and "forgot password" keep using email() above, so a customer who
  // registered with another provider before this rule can still log in.
  //
  // "Valid Gmail" = letters and digits separated by single dots, optionally
  // followed by +something, then @gmail.com. Capital letters do not matter.
  // This is the SAME rule the database enforces (is_gmail_address), so the
  // form and the server always agree.
  static const String gmailOnlyMessage =
      'Please use a Gmail address that ends in @gmail.com.';

  static final RegExp _gmailLocalRegex =
      RegExp(r'^[a-z0-9]+(?:\.[a-z0-9]+)*(?:\+[^@\s]+)?$');

  static String? gmailEmail(String? value) {
    final String? general = email(value);
    if (general != null) return general;

    final String v = (value ?? '').trim().toLowerCase();
    final int at = v.lastIndexOf('@');
    if (v.substring(at + 1) != 'gmail.com') return gmailOnlyMessage;

    if (!_gmailLocalRegex.hasMatch(v.substring(0, at))) {
      return 'That doesn\'t look like a valid Gmail address.';
    }
    return null;
  }
}