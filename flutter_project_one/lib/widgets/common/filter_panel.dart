import 'package:flutter/material.dart';

// ================================================
// FILTER OPTION — one radio button choice
// example: FilterOption(label: 'Available', value: 'Available')
// ================================================
class FilterOption {
  String label; // text shown on screen
  String value; // actual value used in logic

  FilterOption({
    required this.label,
    required this.value,
  });
}

// ================================================
// FILTER SECTION — a group of radio options
// example: Status section with Available, Low Stock, Out of Stock
// ================================================
class FilterSection {
  String title;               // section title like "Status"
  List<FilterOption> options; // list of choices under this section

  FilterSection({
    required this.title,
    required this.options,
  });
}

// ================================================
// FILTER PANEL — the actual UI popup
// ================================================
class FilterPanel extends StatelessWidget {

  // things this widget needs from the parent screen
  final List<FilterSection> sections;      // list of filter sections
  final String? selectedValue;             // currently selected value
  final Function(String?) onValueChanged;  // when user picks an option
  final VoidCallback onClear;              // when user clicks clear
  final VoidCallback onApply;              // when user clicks apply

  const FilterPanel({
    super.key,
    required this.sections,
    required this.selectedValue,
    required this.onValueChanged,
    required this.onClear,
    required this.onApply,
  });

  // ================================================
  // BUILD ONE RADIO BUTTON
  // ================================================
  Widget _buildRadioOption(FilterOption option) {

    // check if this option is currently selected
    bool isSelected = selectedValue == option.value;

    return GestureDetector(

      // when user taps this option
      onTap: () {

        // if already selected → deselect it (set to null)
        // if not selected → select it
        if (isSelected == true) {
          onValueChanged(null);
        } else {
          onValueChanged(option.value);
        }
      },

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [

            // the circle radio button
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                // blue border if selected, gray if not
                border: Border.all(
                  color: isSelected == true
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),

                // blue fill if selected, white if not
                color: isSelected == true
                    ? const Color(0xFF2563EB)
                    : Colors.white,
              ),

              // show white dot inside if selected
              child: isSelected == true
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 8),

            // the label text beside the radio button
            Text(
              option.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD THE WHOLE FILTER PANEL
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── TITLE ──
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 12),

          // ── DYNAMIC SECTIONS ──
          // loop through each section and build it
          for (FilterSection section in sections) ...[

            // section title like "Status"
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 6),

            // loop through each option and build radio button
            for (FilterOption option in section.options)
              _buildRadioOption(option),

            const SizedBox(height: 12),
          ],

          // ── CLEAR AND APPLY BUTTONS ──
          Row(
            children: [

              // Clear button
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Apply button
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Filter',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}