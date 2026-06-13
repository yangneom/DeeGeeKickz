import 'package:flutter/material.dart';

enum ShopSortOption {
  featured('Featured'),
  priceLowHigh('Price: Low → High'),
  priceHighLow('Price: High → Low'),
  topRated('Top Rated');

  final String label;
  const ShopSortOption(this.label);
}

/// Sort button that opens a dropdown menu.
/// Matches the HTML "Sort ▾" button in the controls row.
class ShopSortDropdown extends StatelessWidget {
  final ShopSortOption selected;
  final ValueChanged<ShopSortOption> onChanged;

  const ShopSortDropdown({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<ShopSortOption>(
      context: context,
      position: position,
      color: const Color(0xFFF9F9F9),
      elevation: 4,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: ShopSortOption.values
          .map(
            (opt) => PopupMenuItem<ShopSortOption>(
              value: opt,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                opt.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: opt == selected ? FontWeight.w700 : FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF7E7576)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SORT',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 20, color: Colors.black),
          ],
        ),
      ),
    );
  }
}