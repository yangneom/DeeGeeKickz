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
        const Text(
          'Secure payments powered by PayMongo',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize:   16,
            fontWeight: FontWeight.w400,
            color:      Color(0xFF4C4546),
          ),
        ),
        const SizedBox(height: 24),
        Column(
          children: _options
              .map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PaymentTile(
                      option:     o,
                      isSelected: selectedMethod == o.id,
                      onTap:      () => onChanged(o.id),
                    ),
                  ))
              .toList(),
        ),

        // ── Method-specific notes ──
        if (selectedMethod == 'gcash')
          _buildNote(
            color:      const Color(0xFFEFF6FF),
            border:     const Color(0xFFBFDBFE),
            iconColor:  const Color(0xFF1D4ED8),
            textColor:  const Color(0xFF1D4ED8),
            icon:       Icons.open_in_new,
            text:       'You will be redirected to the GCash app '
                        'to complete payment securely.',
          ),

        if (selectedMethod == 'card')
          _buildNote(
            color:      const Color(0xFFF8F9FA),
            border:     const Color(0xFFE5E7EB),
            iconColor:  const Color(0xFF6B7280),
            textColor:  const Color(0xFF6B7280),
            icon:       Icons.lock_outline,
            text:       'Your card details are encrypted and '
                        'never stored. Powered by PayMongo.',
          ),

        if (selectedMethod == 'cod')
          _buildNote(
            color:      const Color(0xFFF0FDF4),
            border:     const Color(0xFF86EFAC),
            iconColor:  const Color(0xFF16A34A),
            textColor:  const Color(0xFF16A34A),
            icon:       Icons.info_outline,
            text:       'Pay in cash when your order arrives. '
                        'Admin will verify your address before confirming.',
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