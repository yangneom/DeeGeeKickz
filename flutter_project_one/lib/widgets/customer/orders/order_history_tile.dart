import 'package:flutter/material.dart';

/// Horizontally scrollable filter chips for Order History screen.
/// Emits [onFilterChanged] with the selected status string.
/// 'All' means no filter.
class OrderHistoryFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const OrderHistoryFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  static const List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'Preparing',
    'Shipped',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter   = _filters[i];
          final isActive = filter == selectedFilter;

          return GestureDetector(
            onTap: () => onFilterChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.black : Colors.white,
                border: Border.all(
                  color: isActive
                      ? Colors.black
                      : const Color(0xFFCFC4C5),
                ),
              ),
              child: Text(
                filter.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isActive ? Colors.white : const Color(0xFF656464),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}