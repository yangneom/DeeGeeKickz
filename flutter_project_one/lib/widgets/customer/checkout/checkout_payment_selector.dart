import 'package:flutter/material.dart';

class CheckoutPaymentSelector extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const CheckoutPaymentSelector({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
  });

  static const List<_PaymentOption> _options = [
    _PaymentOption(
      id:      'gcash',
      label:   'GCash',
      color:   Color(0xFF007DFE),
      icon:    Icons.account_balance_wallet_outlined,
    ),
    _PaymentOption(
      id:      'card',
      label:   'Credit / Debit Card',
      color:   Color(0xFF4C4546),
      icon:    Icons.credit_card,
    ),
    _PaymentOption(
      id:      'cod',
      label:   'Cash on Delivery',
      color:   Color(0xFF16A34A),
      icon:    Icons.payments_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontFamily:    'Archivo Narrow',
            fontSize:      32,
            fontWeight:    FontWeight.w600,
            letterSpacing: -0.5,
            color:         Colors.black,
          ),
        ),
        const SizedBox(height: 8),
                Column(
          children: [
            for (final _PaymentOption o in _options) ...[
              _PaymentTile(
                option:     o,
                isSelected: selectedMethod == o.id,
                onTap:      () => onChanged(o.id),
              ),
              // The chosen method's instructions sit directly under its card,
              // in one calm style (the brand colour stays on the card's icon).
              if (selectedMethod == o.id)
                _buildNote(
                  color:      const Color(0xFFF3F3F4),
                  border:     const Color(0xFFCFC4C5),
                  iconColor:  const Color(0xFF4C4546),
                  textColor:  const Color(0xFF4C4546),
                  icon: o.id == 'gcash'
                      ? Icons.open_in_new
                      : o.id == 'card'
                          ? Icons.lock_outline
                          : Icons.info_outline,
                  text: o.id == 'gcash'
                      ? 'You will be taken to a secure GCash payment page. '
                        'Your order stays pending until the payment is confirmed.'
                      : o.id == 'card'
                          ? 'You will enter your card details on the next step. '
                            'They are sent securely to our payment partner.'
                          : 'Pay in cash when your order arrives. '
                            'Our team will verify your address before confirming.',
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNote({
    required Color    color,
    required Color    border,
    required Color    iconColor,
    required Color    textColor,
    required IconData icon,
    required String   text,
  }) {
    return Container(
      margin:  const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:  color,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize:   12,
                color:      textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final _PaymentOption option;
  final bool           isSelected;
  final VoidCallback   onTap;

  const _PaymentTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF3F3F4)
              : const Color(0xFFF9F9F9),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFCFC4C5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        option.color,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Icon(option.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  fontFamily:    'Inter',
                  fontSize:      14,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 0.7,
                  color:         Colors.black,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity:  isSelected ? 1.0 : 0.0,
              child: const Icon(
                  Icons.check_circle, color: Colors.black, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption {
  final String   id;
  final String   label;
  final Color    color;
  final IconData icon;

  const _PaymentOption({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
  });
}