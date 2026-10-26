import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'checkout_order_summary.dart' show formatPeso;

// ================================================
// CARD PAYMENT DIALOG
//
// In-house card form: the customer never leaves the app.
//
// WHAT CHANGED (the public API is exactly the same, so checkout needs no edit):
//   - Look: now follows the customer theme used by checkout (square corners,
//     #CFC4C5 borders, Inter / Archivo Narrow, black buttons). It used the
//     rounded admin look (radius 12/8, Tailwind greys) before.
//   - Validation: card number needs all 16 digits AND a valid checksum; the
//     expiry must be a real month and not in the past; the CVC is 3 digits.
//     Messages appear as soon as the customer has touched a field.
//   - Safety: a second tap (or Enter + tap) can never start a second payment;
//     system Back / Esc cannot close the dialog while a payment is processing;
//     the fields are locked while processing.
//   - Money: the total uses the shared peso format (₱1,234.50).
//   - Accessibility: every field has a spoken label, autofill hints, a Next /
//     Done keyboard action, and Enter in the last field submits.
//   - The "secured by PayMongo / encrypted" line now says what is true:
//     the payment is processed by PayMongo.
//
// WHAT IS INTENTIONALLY NOT HERE: a "payment successful" state. This dialog
// only knows that the payment call returned without an error. Whether that
// really means PayMongo confirmed the charge is decided in PaymongoService,
// and the caller shows the result. Do not add a success screen here until
// that service is confirmed to throw for anything that is not "succeeded".
//
// HOW TO USE (unchanged):
//   final bool? paid = await showCardPaymentDialog(
//     context:      context,
//     total:        total,
//     customerName: customerName,
//     onPay: (CardDetails details) async {
//       await PaymongoService().payWithCard(...);
//     },
//   );
// ================================================

/// Set to false when you go live with real PayMongo keys.
const bool _kShowTestNotice = true;

Future<bool?> showCardPaymentDialog({
  required BuildContext                        context,
  required double                              total,
  required String                              customerName,
  required Future<void> Function(CardDetails) onPay,
}) {
  return showDialog<bool>(
    context:            context,
    barrierDismissible: false,
    builder: (_) => CardPaymentDialog(
      total:        total,
      customerName: customerName,
      onPay:        onPay,
    ),
  );
}

// ================================================
// CARD DETAILS MODEL
//
// cardHolderName is filled in automatically from
// customerName (checkout) — there is no separate
// field asking the customer to type it again.
// ================================================
class CardDetails {
  final String cardNumber;
  final String expMonth;
  final String expYear;
  final String cvc;
  final String cardHolderName;

  const CardDetails({
    required this.cardNumber,
    required this.expMonth,
    required this.expYear,
    required this.cvc,
    required this.cardHolderName,
  });
}

// ================================================
// VALIDATORS
//
// Plain static functions, so they can be unit-tested without building the
// dialog. They check the SHAPE of the data only. The bank still decides
// whether the card can really be charged.
// ================================================
class CardValidators {
  CardValidators._();

  /// Luhn checksum, the check every real card number passes.
  static bool passesLuhn(String digits) {
    if (digits.isEmpty) return false;
    int sum = 0;
    bool doubleIt = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      final int? n = int.tryParse(digits[i]);
      if (n == null) return false;
      int value = n;
      if (doubleIt) {
        value *= 2;
        if (value > 9) value -= 9;
      }
      sum += value;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  static String? cardNumber(String? value) {
    final String digits = (value ?? '').replaceAll(' ', '');
    if (digits.isEmpty) return 'Enter your card number';
    if (digits.length < 16) return 'Enter all 16 digits of your card number';
    if (!passesLuhn(digits)) return 'This card number is not valid. Please check it';
    return null;
  }

  /// [now] is only here so tests can fix the date.
  static String? expiry(String? value, {DateTime? now}) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the expiration date';

    final Match? match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
    if (match == null) return 'Use the format MM/YY';

    final int month = int.parse(match.group(1)!);
    final int year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Month must be between 01 and 12';

    final DateTime today = now ?? DateTime.now();
    final bool expired =
        year < today.year || (year == today.year && month < today.month);
    if (expired) return 'This card has expired';
    if (year > today.year + 20) return 'Check the expiration year';
    return null;
  }

  static String? cvc(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the 3-digit security code';
    if (text.length != 3) return 'The security code has 3 digits';
    return null;
  }
}

// ================================================
// DIALOG WIDGET
// ================================================
class CardPaymentDialog extends StatefulWidget {
  final double                              total;
  final String                              customerName;
  final Future<void> Function(CardDetails) onPay;

  const CardPaymentDialog({
    super.key,
    required this.total,
    required this.customerName,
    required this.onPay,
  });

  @override
  State<CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends State<CardPaymentDialog> {
  static const Color _border   = Color(0xFFCFC4C5);
  static const Color _muted    = Color(0xFF656464);
  static const Color _errorRed = Color(0xFFBA1A1A);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberCtrl = TextEditingController();
  final TextEditingController _expiryCtrl     = TextEditingController();
  final TextEditingController _cvcCtrl        = TextEditingController();

  bool    _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  // ── Parse "MM/YY" → (month, year) ──────────────
  (String, String) _parseExpiry(String value) {
    final List<String> parts = value.split('/');
    if (parts.length != 2) return ('', '');
    final String month = parts[0].trim();
    final String short = parts[1].trim();
    final String year  = short.length == 2 ? '20$short' : short;
    return (month, year);
  }

  // Turns a technical error into one sentence the customer can act on.
  // The raw error text is never shown and never logged.
  String _friendlyError(Object error) {
    final String msg = error.toString();
    if (msg.contains('card_declined')) {
      return 'Your card was declined. Please try a different card.';
    }
    if (msg.contains('insufficient_funds')) {
      return 'Insufficient funds. Please try a different card.';
    }
    if (msg.contains('incorrect_cvc')) {
      return 'Incorrect security code. Please check it and try again.';
    }
    if (msg.contains('expired_card')) {
      return 'Your card has expired. Please use a different card.';
    }
    return 'Payment failed. Please check your details and try again.';
  }

  // ================================================
  // HANDLE PAY
  // ================================================
  Future<void> _handlePay() async {
    // Checked first, before anything else: two quick taps, or Enter followed
    // by a tap, must never send two payments.
    if (_isProcessing) return;

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final (String month, String year) = _parseExpiry(_expiryCtrl.text.trim());

      await widget.onPay(CardDetails(
        cardNumber:     _cardNumberCtrl.text.replaceAll(' ', ''),
        expMonth:       month,
        expYear:        year,
        cvc:            _cvcCtrl.text.trim(),
        // Always the checkout customer's name: no separate field to fill in.
        cardHolderName: widget.customerName,
      ));

      // Stays "processing" until the dialog closes, so the button cannot be
      // used again in between.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = _friendlyError(e);
      });
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    // canPop is false while paying: system Back / Esc cannot close the dialog
    // and leave a payment running behind it. The dialog's own pop(true) after
    // success is not affected by this.
    return PopScope(
      canPop: !_isProcessing,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:  440,
            maxHeight: screen.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── FIXED HEADER ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'CARD PAYMENT',
                              style: TextStyle(
                                fontFamily:    'Archivo Narrow',
                                fontSize:      24,
                                fontWeight:    FontWeight.w700,
                                letterSpacing: 0.5,
                                color:         Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontFamily:    'Inter',
                                  fontSize:      11,
                                  fontWeight:    FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color:         _muted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  formatPeso(widget.total),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Archivo Narrow',
                                    fontSize:   22,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, size: 22, color: _muted),
                    ),
                  ],
                ),
              ),

              // ── SCROLLABLE BODY ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Test-mode notice. Flip _kShowTestNotice at the top
                          // of this file to false when you go live.
                          if (_kShowTestNotice) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:  const Color(0xFFF3F3F4),
                                border: Border.all(color: _border),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.science_outlined,
                                      size: 16, color: Color(0xFF4C4546)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Test mode: use card 4343 4343 4343 4345, '
                                      'any future date, any 3-digit security code.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize:   12,
                                        height:     1.4,
                                        color:      Color(0xFF4C4546),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Card number, with Visa / Mastercard badges.
                          // Only those two: PayMongo does not process Amex or
                          // Discover, so showing them would invite a card that
                          // can never work.
                          _label('CARD NUMBER'),
                          const SizedBox(height: 8),
                          _field(
                            controller:     _cardNumberCtrl,
                            semanticsLabel: 'Card number',
                            hint:           '1234 5678 9012 3456',
                            inputType:      TextInputType.number,
                            action:         TextInputAction.next,
                            autofill:       const [AutofillHints.creditCardNumber],
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CardNumberInputFormatter(),
                            ],
                            suffix:    const _CardBrandBadges(),
                            validator: CardValidators.cardNumber,
                          ),

                          const SizedBox(height: 16),

                          // Expiry + security code, same height, side by side.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('EXPIRATION DATE'),
                                    const SizedBox(height: 8),
                                    _field(
                                      controller:     _expiryCtrl,
                                      semanticsLabel: 'Expiration date, month and year',
                                      hint:           'MM/YY',
                                      inputType:      TextInputType.number,
                                      action:         TextInputAction.next,
                                      autofill: const [
                                        AutofillHints.creditCardExpirationDate,
                                      ],
                                      formatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        ExpiryInputFormatter(),
                                      ],
                                      validator: (String? v) =>
                                          CardValidators.expiry(v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('SECURITY CODE'),
                                    const SizedBox(height: 8),
                                    _field(
                                      controller:     _cvcCtrl,
                                      semanticsLabel: 'Security code, 3 digits',
                                      hint:           '123',
                                      inputType:      TextInputType.number,
                                      action:         TextInputAction.done,
                                      obscureText:    true,
                                      autofill: const [
                                        AutofillHints.creditCardSecurityCode,
                                      ],
                                      suffix: const Icon(Icons.credit_card,
                                          size: 18, color: Color(0xFF9CA3AF)),
                                      formatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      validator: CardValidators.cvc,
                                      // Enter in the last field pays. Guarded
                                      // by _isProcessing inside _handlePay.
                                      onSubmitted: (_) => _handlePay(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Error from the payment attempt
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:  const Color(0xFFFEF2F2),
                                  border: Border.all(
                                      color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 16, color: _errorRed),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize:   12,
                                          height:     1.4,
                                          color:      Color(0xFF7A1212),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Pay button: normal, processing (disabled + spinner).
                          Semantics(
                            button: true,
                            enabled: !_isProcessing,
                            label: _isProcessing
                                ? 'Processing payment'
                                : 'Pay ${formatPeso(widget.total)}',
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _isProcessing ? null : _handlePay,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                color: _isProcessing
                                    ? const Color(0xFF656464)
                                    : Colors.black,
                                alignment: Alignment.center,
                                child: _isProcessing
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Processing...',
                                            style: TextStyle(
                                              fontFamily:    'Inter',
                                              fontSize:      14,
                                              fontWeight:    FontWeight.w600,
                                              letterSpacing: 2.0,
                                              color:         Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'PAY ${formatPeso(widget.total)}',
                                        style: const TextStyle(
                                          fontFamily:    'Inter',
                                          fontSize:      14,
                                          fontWeight:    FontWeight.w600,
                                          letterSpacing: 2.0,
                                          color:         Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock, size: 12, color: _muted),
                              SizedBox(width: 6),
                              Text(
                                'Payments are processed by PayMongo',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize:   11,
                                  color:      _muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily:    'Inter',
          fontSize:      12,
          fontWeight:    FontWeight.w700,
          letterSpacing: 1.5,
          color:         _muted,
        ),
      );

  Widget _field({
    required TextEditingController     controller,
    required String                    semanticsLabel,
    required String                    hint,
    required TextInputType             inputType,
    required TextInputAction           action,
    List<String>?                      autofill,
    List<TextInputFormatter>?          formatters,
    String? Function(String?)?         validator,
    ValueChanged<String>?              onSubmitted,
    bool                               obscureText = false,
    Widget?                            suffix,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:   BorderSide(color: color, width: width),
        );

    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: TextFormField(
        controller:      controller,
        enabled:         !_isProcessing,
        keyboardType:    inputType,
        textInputAction: action,
        autofillHints:   autofill,
        inputFormatters: formatters,
        validator:       validator,
        obscureText:     obscureText,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize:   15,
          color:      Colors.black,
        ),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize:   14,
            color:      Color(0xFF9CA3AF),
          ),
          filled:    true,
          fillColor: Colors.white,
          errorMaxLines: 2,
          errorStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize:   12,
            color:      _errorRed,
          ),
          // The small brand badges / card icon sit inside the right edge.
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: suffix,
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border:             border(_border, 1),
          enabledBorder:      border(_border, 1),
          disabledBorder:     border(_border, 1),
          focusedBorder:      border(Colors.black, 1.5),
          errorBorder:        border(_errorRed, 1),
          focusedErrorBorder: border(_errorRed, 1.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    );
  }
}

// ================================================
// CARD BRAND BADGES — shown inside the Card Number field, right side.
// Only Visa + Mastercard, because those are the only two card networks
// PayMongo actually processes here.
// ================================================
class _CardBrandBadges extends StatelessWidget {
  const _CardBrandBadges();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge('VISA', const Color(0xFF1A1F71)),
        const SizedBox(width: 6),
        _badge('MC', const Color(0xFFEB001B)),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily:    'Inter',
          fontSize:      9,
          fontWeight:    FontWeight.w700,
          color:         Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Card number formatter: "1234 5678 9012 3456", up to 16 digits ──────────
// Keeps the cursor where the customer is editing (the old version always
// jumped it to the end).
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return oldValue;

    final int rawCursor = newValue.selection.baseOffset;
    final int cursor = rawCursor < 0
        ? newValue.text.length
        : rawCursor.clamp(0, newValue.text.length).toInt();
    final int digitsBeforeCursor =
        newValue.text.substring(0, cursor).replaceAll(RegExp(r'\D'), '').length;

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final String text = buffer.toString();

    int position = digitsBeforeCursor +
        (digitsBeforeCursor > 0 ? (digitsBeforeCursor - 1) ~/ 4 : 0);
    if (position > text.length) position = text.length;

    return TextEditingValue(
      text:      text,
      selection: TextSelection.collapsed(offset: position),
    );
  }
}

// ── Expiry formatter: "MM/YY" ────────────────────────────────────────────────
// A first digit of 2 to 9 can only be a month typed without its zero, so "5"
// becomes "05/". Deleting works normally (the slash can be backspaced).
class ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;

    final bool typingForward = newValue.text.length > oldValue.text.length;

    if (digits.length == 1 &&
        typingForward &&
        digits != '0' &&
        digits != '1') {
      digits = '0$digits';
    }

    String text = digits;
    if (digits.length > 2 || (digits.length == 2 && typingForward)) {
      text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }

    return TextEditingValue(
      text:      text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}