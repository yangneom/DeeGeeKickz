import 'package:flutter/material.dart';
import 'filter_panel.dart';

// ================================================
// FILTER BUTTON — the icon button that shows/hides
// the filter panel when clicked
// ================================================
class FilterButton extends StatelessWidget {

  // things this widget needs from parent screen
  final bool isOpen;                      // is filter panel open or closed
  final VoidCallback onTap;              // when user taps the button
  final List<FilterSection> sections;    // filter sections to show
  final String? selectedValue;           // currently selected value
  final Function(String?) onValueChanged; // when user picks an option
  final VoidCallback onClear;            // when user clicks clear
  final VoidCallback onApply;            // when user clicks apply

  const FilterButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    required this.sections,
    required this.selectedValue,
    required this.onValueChanged,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [

        // ── FILTER ICON BUTTON ──
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(

              // blue background if open, white if closed
              color: isOpen == true
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(
                // blue border if open, gray if closed
                color: isOpen == true
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            child: Icon(
              Icons.filter_list,
              size: 18,
              // blue icon if open, gray if closed
              color: isOpen == true
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),

        // ── FILTER PANEL — appears below button when open ──
        if (isOpen == true)
          Positioned(
            top: 48,
            left: 0,
            child: GestureDetector(
              // prevent tapping inside panel from closing it
              onTap: () {},
              child: FilterPanel(
                sections: sections,
                selectedValue: selectedValue,
                onValueChanged: onValueChanged,
                onClear: onClear,
                onApply: onApply,
              ),
            ),
          ),
      ],
    );
  }
}