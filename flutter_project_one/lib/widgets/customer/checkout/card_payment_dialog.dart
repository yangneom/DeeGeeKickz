import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================================================
// CARD PAYMENT DIALOG
//
// In-house card payment form — customer never
// leaves the app.
//
// NOTE: No "Cardholder Name" field anymore. PayMongo's
// billing.name just needs SOME name — we now always send
// the customer's name from checkout (customerName), so the
// customer never has to type it twice.
//
// HOW TO USE:
//   final bool? paid = await showCardPaymentDialog(
//     context:      context,
//     total:        total,
//     customerName: customerName,
//     onPay: (CardDetails details) async {
//       await PaymongoService().payWithCard(
//         orderId: orderId,
//         amount:  total,
//         card:    details,
//         customerName:  customerName,
//         customerEmail: customerEmail,
//       );
//     },
//   );
//   if (paid == true) { ... navigate to order history }
// ================================================

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
// field asking the customer to type it anymore.
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

  final _formKey         = GlobalKey<FormState>();
  // NOTE: _nameCtrl was removed — we no longer show a Cardholder
  // Name field. widget.customerName is used directly instead.
  final _cardNumberCtrl  = TextEditingController();
  final _expiryCtrl      = TextEditingController();
  final _cvcCtrl         = TextEditingController();

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
    final parts = value.split('/');
    if (parts.length != 2) return ('', '');
    final month = parts[0].trim();
    final short = parts[1].trim();
    final year  = short.length == 2 ? '20$short' : short;
    return (month, year);
  }

  // ================================================
  // HANDLE PAY
  // ================================================
  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final (month, year) = _parseExpiry(_expiryCtrl.text.trim());

      await widget.onPay(CardDetails(
        cardNumber:     _cardNumberCtrl.text.replaceAll(' ', ''),
        expMonth:       month,
        expYear:        year,
        cvc:            _cvcCtrl.text.trim(),
        // Always use the checkout customer's name — no separate
        // field for the customer to fill in.
        cardHolderName: widget.customerName,
      ));

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      final msg = e.toString();
      setState(() {
        _isProcessing = false;
        _errorMessage = msg.contains('card_declined')
            ? 'Your card was declined. Please try a different card.'
            : msg.contains('insufficient_funds')
            ? 'Insufficient funds. Please try a different card.'
            : msg.contains('incorrect_cvc')
            ? 'Incorrect CVC. Please check and try again.'
            : msg.contains('expired_card')
            ? 'Your card has expired. Please use a different card.'
            : 'Payment failed. Please check your details and try again.';
      });
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  480,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Card Payment',
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                          color:      Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ₱${widget.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE BODY ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Sandbox notice — keep this while you're
                      // still testing. Remove this whole Container
                      // (and the SizedBox right after it) once you
                      // go live with real PayMongo keys.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:  const Color(0xFFFEF3C7),
                          border: Border.all(
                              color: const Color(0xFFFCD34D)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.science_outlined,
                                size: 14, color: Color(0xFF92400E)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Test mode — use card '
                                '4343 4343 4343 4345, '
                                'any future date, any 3-digit CVC.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:    Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Card number — with Visa/Mastercard badges.
                      // NOTE: only Visa + Mastercard shown here
                      // because PayMongo does not support Amex or
                      // Discover cards — showing those would let a
                      // customer try a card that will always fail.
                      _label('Card Number'),
                      const SizedBox(height: 6),
                      _field(
                        controller:  _cardNumberCtrl,
                        hint:        '1234 5678 9012 3456',
                        inputType:   TextInputType.number,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _CardNumberFormatter(),
                        ],
                        suffix: const _CardBrandBadges(),
                        validator: (v) {
                          final d = v?.replaceAll(' ', '') ?? '';
                          return d.length < 16
                              ? 'Enter a valid 16-digit card number'
                              : null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Expiry + CVC
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _label('Expiration date'),
                                const SizedBox(height: 6),
                                _field(
                                  controller: _expiryCtrl,
                                  hint:       'MM/YY',
                                  inputType:  TextInputType.number,
                                  formatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly,
                                    _ExpiryFormatter(),
                                  ],
                                  validator: (v) =>
                                      (v == null || v.length < 5)
                                          ? 'Enter MM/YY'
                                          : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _label('Security code'),
                                const SizedBox(height: 6),
                                _field(
                                  controller:  _cvcCtrl,
                                  hint:        '123',
                                  inputType:   TextInputType.number,
                                  obscureText: true,
                                  suffix: const Icon(Icons.credit_card,
                                      size: 18, color: Color(0xFF9CA3AF)),
                                  formatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (v) =>
                                      (v == null || v.length != 3)
                                          ? 'Enter a 3-digit CVC'
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Error
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:  const Color(0xFFFEE2E2),
                            border: Border.all(
                                color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size:  14,
                                  color: Color(0xFF991B1B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color:    Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Pay button
                      GestureDetector(
                        onTap: _isProcessing ? null : _handlePay,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          color: _isProcessing
                              ? const Color(0xFF6B7280)
                              : Colors.black,
                          child: Center(
                            child: _isProcessing
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Processing...',
                                          style: TextStyle(
                                            fontSize:   14,
                                            fontWeight: FontWeight.w600,
                                            color:      Colors.white,
                                          )),
                                    ],
                                  )
                                : Text(
                                    'PAY ₱${widget.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize:      14,
                                      fontWeight:    FontWeight.w600,
                                      letterSpacing: 1.5,
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
                          Icon(Icons.lock,
                              size: 12, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 4),
                          Text(
                            'Encrypted & secured by PayMongo',
                            style: TextStyle(
                              fontSize: 11,
                              color:    Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.w600,
          color:      Color(0xFF374151),
        ),
      );

  Widget _field({
    required TextEditingController     controller,
    required String                    hint,
    required TextInputType             inputType,
    List<TextInputFormatter>?          formatters,
    String? Function(String?)?         validator,
    bool                               obscureText = false,
    Widget?                            suffix,
  }) =>
      TextFormField(
        controller:      controller,
        keyboardType:    inputType,
        inputFormatters: formatters,
        validator:       validator,
        obscureText:     obscureText,
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              fontSize: 13, color: Color(0xFF9CA3AF)),
          // suffixIcon shows the small brand badges / card icon
          // inside the right edge of the field, same spot as the
          // reference screenshot.
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffix,
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF111827)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFEF4444)),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      );
}

// ================================================
// CARD BRAND BADGES — shown inside the Card Number
// field, right side. Only Visa + Mastercard, because
// those are the only two card networks PayMongo
// actually processes — no Amex, no Discover.
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize:      9,
          fontWeight:    FontWeight.w700,
          color:         Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Card number formatter ────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    if (digits.length > 16) return old;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final result = buf.toString();
    return TextEditingValue(
      text:      result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ── Expiry formatter ─────────────────────────────
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll('/', '');
    if (digits.length > 4) return old;
    String result = digits;
    if (digits.length >= 3) {
      result = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text:      result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}