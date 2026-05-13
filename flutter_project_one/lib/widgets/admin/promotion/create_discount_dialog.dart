import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================================================
// CREATE DISCOUNT DIALOG
//
// This dialog lets the admin create a new discount
// for a product.
//
// Fields:
//   - Select Product (dropdown)
//   - Discount Type (Percentage OR Fixed Amount)
//     shown as two clickable cards — no radio needed
//   - Discount Value (number input)
//   - Start Date + End Date (date pickers)
//   - Show countdown timer checkbox
//
// How to open:
//   showCreateDiscountDialog(context);
// ================================================

// ── FAKE PRODUCT LIST ──
// These are the products in the dropdown
// Replace with real data from Firestore later
const List<String> _productOptions = [
  'Nike Air Max 270',
  'Nike Panda',
  'Jordan 1 Retro High',
  'Adidas Ultraboost 22',
];

// ================================================
// SHOW FUNCTION
// Call this from DiscountsTable to open the dialog
// ================================================
Future<Map<String, dynamic>?> showCreateDiscountDialog(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const CreateDiscountDialog();
    },
  );
}

// ================================================
// STATEFUL WIDGET
// We need state because user fills in the form
// ================================================
class CreateDiscountDialog extends StatefulWidget {
  const CreateDiscountDialog({super.key});

  @override
  State<CreateDiscountDialog> createState() => _CreateDiscountDialogState();
}

class _CreateDiscountDialogState extends State<CreateDiscountDialog> {

  // ── SELECTED PRODUCT ──
  // null means nothing selected yet
  String? _selectedProduct;

  // ── DISCOUNT TYPE ──
  // 'percent' = percentage (e.g. 20%)
  // 'fixed'   = fixed amount (e.g. ₱500)
  // default is 'percent'
  String _discountType = 'percent';

  // ── DISCOUNT VALUE ──
  // the number the user types in
  final TextEditingController _valueController = TextEditingController();

  // ── DATES ──
  // null means not picked yet
  DateTime? _startDate;
  DateTime? _endDate;

  // ── COUNTDOWN TIMER ──
  // checkbox at the bottom
  bool _showCountdown = false;

  // ================================================
  // OPEN DATE PICKER
  // Shows Flutter's built-in date picker
  // Updates either start or end date
  // ================================================
  Future<void> _pickDate({required bool isStart}) async {

    // show the date picker dialog
    DateTime? picked = await showDatePicker(
      context: context,
      // start from today
      initialDate: DateTime.now(),
      // earliest allowed date is today
      firstDate: DateTime.now(),
      // latest allowed date is 2 years from now
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    // if user picked a date (didn't cancel)
    if (picked != null) {
      setState(() {
        if (isStart == true) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ================================================
  // FORMAT DATE
  // Converts DateTime to "Jun 1, 2026" string
  // ================================================
  String _formatDate(DateTime date) {

    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String month = months[date.month - 1];
    String day = date.day.toString();
    String year = date.year.toString();

    return '$month $day, $year';
  }

  // ================================================
  // FORMAT DATE RANGE
  // Combines start and end into "Jun 1 – Jun 30"
  // ================================================
  String _formatDateRange(DateTime start, DateTime end) {

    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String startStr = '${months[start.month - 1]} ${start.day}';
    String endStr = '${months[end.month - 1]} ${end.day}';

    return '$startStr – $endStr';
  }

  // ================================================
  // CALCULATE FINAL PRICE
  // Returns a display string like "₱4,400"
  // We need a base price to calculate from
  // For now we use fake prices per product
  // ================================================
  String _calculateFinalPrice() {

    // fake original prices per product
    // replace with real data later
    Map<String, double> prices = {
      'Nike Air Max 270': 5500,
      'Nike Panda': 2500,
      'Jordan 1 Retro High': 8500,
      'Adidas Ultraboost 22': 7200,
    };

    // if no product selected return empty
    if (_selectedProduct == null) return '';

    // get the original price
    double originalPrice = prices[_selectedProduct] ?? 0;

    // get the value typed by user
    double discountValue = double.tryParse(_valueController.text) ?? 0;

    // calculate the final price
    double finalPrice = 0;

    if (_discountType == 'percent') {
      // percentage discount: e.g. 20% off 5500 = 4400
      double discountAmount = originalPrice * (discountValue / 100);
      finalPrice = originalPrice - discountAmount;
    } else {
      // fixed discount: e.g. ₱1000 off 5500 = 4500
      finalPrice = originalPrice - discountValue;
    }

    // make sure final price is not negative
    if (finalPrice < 0) finalPrice = 0;

    // format with commas
    return '₱${_addCommas(finalPrice.toInt())}';
  }

  // ================================================
  // ADD COMMAS TO NUMBER
  // Converts 5500 to "5,500"
  // ================================================
  String _addCommas(int number) {

    String numStr = number.toString();
    String result = '';
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i = i - 1) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = numStr[i] + result;
      count = count + 1;
    }

    return result;
  }

  // ================================================
  // HANDLE APPLY
  // Validates the form and returns the new discount
  // ================================================
  void _handleApply() {

    // ── VALIDATION ──

    if (_selectedProduct == null) {
      _showError('Please select a product.');
      return;
    }

    if (_valueController.text.isEmpty) {
      _showError('Please enter a discount value.');
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showError('Please pick a start and end date.');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showError('End date must be after start date.');
      return;
    }

    // ── BUILD RESULT ──

    // format the discount display string
    String discountDisplay = '';
    if (_discountType == 'percent') {
      discountDisplay = '${_valueController.text}%';
    } else {
      discountDisplay = '₱${_valueController.text}';
    }

    // fake original prices per product
    Map<String, String> originalPrices = {
      'Nike Air Max 270': '₱5,500',
      'Nike Panda': '₱2,500',
      'Jordan 1 Retro High': '₱8,500',
      'Adidas Ultraboost 22': '₱7,200',
    };

    Map<String, dynamic> result = {
      'productName': _selectedProduct,
      'originalPrice': originalPrices[_selectedProduct] ?? '',
      'discount': discountDisplay,
      'discountType': _discountType,
      'finalPrice': _calculateFinalPrice(),
      'duration': _formatDateRange(_startDate!, _endDate!),
      'status': 'Active',
    };

    // close dialog and return result
    Navigator.pop(context, result);
  }

  // ================================================
  // SHOW ERROR SNACKBAR
  // ================================================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TITLE ROW ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Discount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  // X close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── SELECT PRODUCT ──
              _buildLabel('Select Product'),
              const SizedBox(height: 8),
              _buildProductDropdown(),

              const SizedBox(height: 20),

              // ── DISCOUNT TYPE ──
              _buildLabel('Discount Type'),
              const SizedBox(height: 8),
              _buildDiscountTypeSelector(),

              const SizedBox(height: 20),

              // ── DISCOUNT VALUE ──
              _buildLabel('Discount Value'),
              const SizedBox(height: 8),
              _buildValueInput(),

              // ── FINAL PRICE PREVIEW ──
              // shows live calculation as user types
              if (_selectedProduct != null && _valueController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Final price: ${_calculateFinalPrice()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── START DATE + END DATE ──
              _buildLabel('Duration'),
              const SizedBox(height: 8),
              Row(
                children: [

                  // Start date picker
                  Expanded(
                    child: _buildDatePicker(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // End date picker
                  Expanded(
                    child: _buildDatePicker(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── COUNTDOWN TIMER CHECKBOX ──
              _buildCountdownCheckbox(),

              const SizedBox(height: 28),

              // ── BOTTOM BUTTONS ──
              Row(
                children: [

                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Apply Discount
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Apply Discount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD LABEL
  // A simple bold label above each field
  // ================================================
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    );
  }

  // ================================================
  // BUILD PRODUCT DROPDOWN
  // ================================================
  Widget _buildProductDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProduct,
          hint: const Text(
            'Choose a product...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
          items: _productOptions.map((String product) {
            return DropdownMenuItem<String>(
              value: product,
              child: Text(
                product,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedProduct = newValue;
            });
          },
        ),
      ),
    );
  }

  // ================================================
  // BUILD DISCOUNT TYPE SELECTOR
  //
  // Two clickable cards side by side:
  //   [% Percentage]   [₱ Fixed Amount]
  //
  // The selected card gets a blue border and background.
  // This is simpler and cleaner than radio buttons.
  // ================================================
  Widget _buildDiscountTypeSelector() {
    return Row(
      children: [

        // Percentage card
        Expanded(
          child: _buildTypeCard(
            label: 'Percentage',
            icon: '%',
            value: 'percent',
          ),
        ),

        const SizedBox(width: 12),

        // Fixed Amount card
        Expanded(
          child: _buildTypeCard(
            label: 'Fixed Amount',
            icon: '₱',
            value: 'fixed',
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD TYPE CARD
  // One selectable card for discount type
  // ================================================
  Widget _buildTypeCard({
    required String label,
    required String icon,
    required String value,
  }) {

    // check if this card is the selected one
    bool isSelected = _discountType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _discountType = value;
          // clear the value when switching types
          _valueController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          // blue background if selected, white if not
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.white,
          // blue border if selected, gray if not
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // icon badge
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // label
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD VALUE INPUT
  // Text field with % or ₱ suffix/prefix depending
  // on the selected discount type
  // ================================================
  Widget _buildValueInput() {
    return TextField(
      controller: _valueController,
      // only allow numbers and decimal points
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // only allow digits and one dot
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      // rebuild to update final price preview
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: _discountType == 'percent' ? '20' : '500',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF9CA3AF),
        ),
        // show % or ₱ at the end of the field
        suffixText: _discountType == 'percent' ? '%' : '₱',
        suffixStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
    );
  }

  // ================================================
  // BUILD DATE PICKER
  // A tappable box that shows the date when picked
  // ================================================
  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // show date if picked, else show label as hint
                date != null ? _formatDate(date) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD COUNTDOWN CHECKBOX
  // ================================================
  Widget _buildCountdownCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCountdown = !_showCountdown;
        });
      },
      child: Row(
        children: [
          // the checkbox
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _showCountdown,
              onChanged: (bool? value) {
                setState(() {
                  _showCountdown = value ?? false;
                });
              },
              activeColor: const Color(0xFF2563EB),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // the label
          const Text(
            'Show countdown timer on product page',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}