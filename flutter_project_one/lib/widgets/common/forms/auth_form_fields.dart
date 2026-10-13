import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================================================
// AUTH FORM FIELDS — the one look for every auth form.
//
//   AuthTextField      label above the input, outlined box, error text
//                      directly under the input
//   AuthPasswordField  same, plus a show/hide eye with an accessible name
//   AuthFormError      the red box for a whole-form problem (for example
//                      "Incorrect email or password")
//   AuthPrimaryButton  black full-width button with a loading state
//
// Rules these follow:
//   - The label is always visible above the field (a placeholder is only a
//     hint, never a replacement for the label).
//   - A problem with ONE field is shown under that field, never as a toast.
//   - Colour is never the only signal: errors also carry text (and the
//     form-level box carries an icon).
// ================================================

class AuthFieldStyle {
  AuthFieldStyle._();

  static const Color text = Color(0xFF111827);
  static const Color label = Color(0xFF374151);
  // Darker than the usual light grey so the placeholder stays readable.
  static const Color hint = Color(0xFF6B7280);
  static const Color border = Color(0xFFD1D5DB);
  static const Color focus = Colors.black;
  static const Color error = Color(0xFFDC2626);

  static OutlineInputBorder _outline(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static InputDecoration decoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AuthFieldStyle.hint),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      // Hides the "0/50" counter when a maxLength is set.
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _outline(border),
      enabledBorder: _outline(border),
      disabledBorder: _outline(const Color(0xFFE5E7EB)),
      focusedBorder: _outline(focus, 1.5),
      errorBorder: _outline(error),
      focusedErrorBorder: _outline(error, 1.5),
      errorStyle: const TextStyle(fontSize: 12, color: error, height: 1.3),
      errorMaxLines: 3,
    );
  }
}

// Label above + field, merged into ONE accessibility node so a screen
// reader announces "Email Address, text field, Enter your email" instead
// of two unrelated pieces.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget field;

  const _LabeledField({required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AuthFieldStyle.label,
            ),
          ),
          const SizedBox(height: 8),
          field,
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;
  // Lets the screen re-check ONE field (for example Confirm Password after
  // the Password field changes) without re-checking the whole form.
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.fieldKey,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: label,
      field: TextFormField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AuthFieldStyle.text),
        decoration: AuthFieldStyle.decoration(hint: hint),
      ),
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  const AuthPasswordField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.fieldKey,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  // Only the display changes; the typed password is never cleared or
  // modified by showing/hiding it.
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: widget.label,
      field: TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        validator: widget.validator,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints ?? const [AutofillHints.password],
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14, color: AuthFieldStyle.text),
        decoration: AuthFieldStyle.decoration(
          hint: widget.hint,
          suffixIcon: IconButton(
            // Spoken name + hover text, and a click target of at least 40px.
            tooltip: _obscure ? 'Show password' : 'Hide password',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: AuthFieldStyle.hint,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

/// Red box for a problem with the WHOLE form (not one field). Has an icon
/// as well as colour, and is announced by screen readers when it appears.
class AuthFormError extends StatelessWidget {
  final String message;

  const AuthFormError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        // Disabled while loading, so a double tap or Enter can't send the
        // request twice.
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          // Visible white-on-dark spinner while loading.
          disabledBackgroundColor: const Color(0xFF374151),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

/// "Back" / "Back to Login" link. A real button, so it can be reached and
/// activated with the keyboard and is announced by screen readers (the old
/// ones were plain tappable text).
class AuthBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AuthBackButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF4B5563),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}