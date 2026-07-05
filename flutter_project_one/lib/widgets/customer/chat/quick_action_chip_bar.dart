// lib/widgets/customer/chat/quick_action_chip_bar.dart

import 'package:flutter/material.dart';

class QuickActionChipBar extends StatelessWidget {
  final void Function(String chipText) onChipTapped;

  const QuickActionChipBar({super.key, required this.onChipTapped});

  static const List<String> _chips = [
    'Shipping Status',
    'Return Policy',
    'Sizing Guide',
    'Track Order',
    'Contact Us',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _QuickChip(
            label: _chips[index],
            onTap: () => onChipTapped(_chips[index]),
          );
        },
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5)),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Color(0xFF1A1C1C),
          ),
        ),
      ),
    );
  }
}