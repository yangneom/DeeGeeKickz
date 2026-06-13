import 'package:flutter/material.dart';

/// Payment method selector — GCash, Maya, Credit/Debit, Online Banking.
/// Frontend UI only. 
/// Supabase-ready: wire selectedMethod to a checkout provider + 
/// PayMongo SDK integration when ready.
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
      id: 'gcash',
      label: 'GCash',
      color: Color(0xFF007DFE),
      initial: 'G',
    ),
    _PaymentOption(
      id: 'maya',
      label: 'Maya',
      color: Color(0xFF16C60C),
      initial: 'M',
    ),
    _PaymentOption(
      id: 'card',
      label: 'Credit / Debit Card',
      color: Color(0xFF4C4546),
      initial: null,
      icon: Icons.credit_card,
    ),
    _PaymentOption(
      id: 'banking',
      label: 'Online Banking',
      color: Color(0xFF5F5E5E),
      initial: null,
      icon: Icons.account_balance,
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
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Secure payments powered by PayMongo',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF4C4546),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          return isWide
              ? _WideGrid(
                  options: _options,
                  selectedMethod: selectedMethod,
                  onChanged: onChanged,
                )
              : _NarrowList(
                  options: _options,
                  selectedMethod: selectedMethod,
                  onChanged: onChanged,
                );
        }),
      ],
    );
  }
}

class _WideGrid extends StatelessWidget {
  final List<_PaymentOption> options;
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const _WideGrid({
    required this.options,
    required this.selectedMethod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: options
              .sublist(0, 2)
              .map((o) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: o == options[0] ? 6 : 0,
                          left: o == options[1] ? 6 : 0),
                      child: _PaymentTile(
                        option: o,
                        isSelected: selectedMethod == o.id,
                        onTap: () => onChanged(o.id),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: options
              .sublist(2, 4)
              .map((o) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: o == options[2] ? 6 : 0,
                          left: o == options[3] ? 6 : 0),
                      child: _PaymentTile(
                        option: o,
                        isSelected: selectedMethod == o.id,
                        onTap: () => onChanged(o.id),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _NarrowList extends StatelessWidget {
  final List<_PaymentOption> options;
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const _NarrowList({
    required this.options,
    required this.selectedMethod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaymentTile(
                  option: o,
                  isSelected: selectedMethod == o.id,
                  onTap: () => onChanged(o.id),
                ),
              ))
          .toList(),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final _PaymentOption option;
  final bool isSelected;
  final VoidCallback onTap;

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
            // Brand icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: option.color,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: option.icon != null
                  ? Icon(option.icon, color: Colors.white, size: 20)
                  : Text(
                      option.initial!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Colors.black,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isSelected ? 1.0 : 0.0,
              child: const Icon(Icons.check_circle,
                  color: Colors.black, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption {
  final String id;
  final String label;
  final Color color;
  final String? initial;
  final IconData? icon;

  const _PaymentOption({
    required this.id,
    required this.label,
    required this.color,
    this.initial,
    this.icon,
  });
}