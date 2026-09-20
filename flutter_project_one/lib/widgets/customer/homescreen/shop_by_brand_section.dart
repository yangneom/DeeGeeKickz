import 'package:flutter/material.dart';

class ShopByBrandSection extends StatelessWidget {
  final List<String> brands;
  final String? selectedBrand;
  final ValueChanged<String?> onBrandSelected;

  const ShopByBrandSection({
    super.key,
    required this.brands,
    required this.selectedBrand,
    required this.onBrandSelected,
  });

  static const double _mdBreakpoint = 768;

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: isSelected ? Colors.black : const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _mdBreakpoint;
    final double hPad = isDesktop ? 48.0 : 16.0;
    final List<String> allOptions = ['All', ...brands];

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shop by Brand',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allOptions.length,
              itemBuilder: (context, index) {
                final String option = allOptions[index];
                final bool isSelected = option == 'All' ? selectedBrand == null : selectedBrand == option;
                return _chip(option, isSelected, () => onBrandSelected(option == 'All' ? null : option));
              },
            ),
          ),
        ],
      ),
    );
  }
}