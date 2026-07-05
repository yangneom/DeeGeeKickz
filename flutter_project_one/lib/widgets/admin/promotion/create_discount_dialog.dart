import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';

// ================================================
// CREATE DISCOUNT DIALOG
//
// Lets the admin create a new discount for a real
// product, wired to Supabase via DiscountService.
//
// Fields:
//   - Select Product (search-as-you-type, backed by
//     DiscountService.searchProducts())
//   - Discount Type (Percentage OR Fixed Amount)
//   - Discount Value (number input)
//   - Start Date + End Date (date pickers)
//   - Show countdown timer checkbox (UI-only for now —
//     there's no matching column on `discount` yet,
//     so this isn't persisted. Flagging in case a
//     `show_countdown` column gets added later.)
//
// How to open:
//   showCreateDiscountDialog(context);
// Returns `true` on success — DiscountsTable re-fetches
// from Supabase rather than receiving a Map back.
// ================================================

Future<bool?> showCreateDiscountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const CreateDiscountDialog();
    },
  );
}

class CreateDiscountDialog extends StatefulWidget {
  const CreateDiscountDialog({super.key});

  @override
  State<CreateDiscountDialog> createState() => _CreateDiscountDialogState();
}

class _CreateDiscountDialogState extends State<CreateDiscountDialog> {
  final DiscountService _discountService = DiscountService();

  // ── PRODUCT SEARCH ──
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  int? _selectedProductId;
  String? _selectedProductName;
  double _selectedOriginalPrice = 0;

  // ── DISCOUNT TYPE ──
  // Must match Discount.fromMap's literal check ('Percentage' vs
  // anything else treated as fixed) — use these exact strings.
  String _discountType = 'Percentage';

  final TextEditingController _valueController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _showCountdown = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  // ================================================
  // SEARCH PRODUCTS (debounced-free, simple version)
  // ================================================
  Future<void> _handleSearchChanged(String query) async {
    // Typing again after a product was selected clears the selection —
    // admin must re-pick from fresh results.
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _selectedOriginalPrice = 0;
    });

    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    final List<Map<String, dynamic>> results =
        await _discountService.searchProducts(query.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectProduct(Map<String, dynamic> result) {
    setState(() {
      _selectedProductId = result['productId'] as int;
      _selectedProductName = result['productName'] as String;
      _selectedOriginalPrice = result['originalPrice'] as double;
      _searchController.text = _selectedProductName!;
      _searchResults = [];
    });
  }

  // ================================================
  // DATE PICKER
  // ================================================
  Future<void> _pickDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ================================================
  // CALCULATE FINAL PRICE (live preview)
  // Same logic as Discount.finalPrice — kept in sync
  // manually since this dialog runs before the row exists.
  // ================================================
  double _calculateFinalPrice() {
    if (_selectedProductId == null) return 0;
    final double discountValue = double.tryParse(_valueController.text) ?? 0;

    double finalPrice;
    if (_discountType == 'Percentage') {
      final double discountAmount = _selectedOriginalPrice * (discountValue / 100);
      finalPrice = _selectedOriginalPrice - discountAmount;
    } else {
      finalPrice = _selectedOriginalPrice - discountValue;
    }
    if (finalPrice < 0) finalPrice = 0;
    return finalPrice;
  }

  String _addCommas(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = numStr[i] + result;
      count++;
    }
    return result;
  }

  // ================================================
  // HANDLE APPLY
  // ================================================
  Future<void> _handleApply() async {
    if (_selectedProductId == null) {
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

    final double? discountValue = double.tryParse(_valueController.text);
    if (discountValue == null) {
      _showError('Discount value must be a number.');
      return;
    }

    setState(() => _isSaving = true);

    final String? error = await _discountService.addDiscount(
      productId: _selectedProductId!,
      discountType: _discountType,
      discountValue: discountValue,
      startDate: _startDate!,
      endDate: _endDate!,
      status: 'Active',
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showError('Failed to create discount: $error');
      return;
    }

    Navigator.pop(context, true);
  }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  GestureDetector(
                    onTap: _isSaving ? null : () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildLabel('Select Product'),
              const SizedBox(height: 8),
              _buildProductSearchField(),

              const SizedBox(height: 20),

              _buildLabel('Discount Type'),
              const SizedBox(height: 8),
              _buildDiscountTypeSelector(),

              const SizedBox(height: 20),

              _buildLabel('Discount Value'),
              const SizedBox(height: 8),
              _buildValueInput(),

              if (_selectedProductId != null && _valueController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Final price: ₱${_addCommas(_calculateFinalPrice().toInt())}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              _buildLabel('Duration'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
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

              _buildCountdownCheckbox(),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Apply Discount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
    );
  }

  // ================================================
  // PRODUCT SEARCH FIELD
  // Type-ahead against DiscountService.searchProducts().
  // ================================================
  Widget _buildProductSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _handleSearchChanged,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: 'Search for a product...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final Map<String, dynamic> result = _searchResults[index];
                return InkWell(
                  onTap: () => _selectProduct(result),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            result['productName'] as String,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₱${_addCommas((result['originalPrice'] as double).toInt())}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_selectedProductId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Selected: $_selectedProductName (₱${_addCommas(_selectedOriginalPrice.toInt())})',
              style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscountTypeSelector() {
    return Row(
      children: [
        Expanded(child: _buildTypeCard(label: 'Percentage', icon: '%', value: 'Percentage')),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeCard(label: 'Fixed Amount', icon: '₱', value: 'Fixed')),
      ],
    );
  }

  Widget _buildTypeCard({
    required String label,
    required String icon,
    required String value,
  }) {
    bool isSelected = _discountType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _discountType = value;
          _valueController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput() {
    return TextField(
      controller: _valueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: _discountType == 'Percentage' ? '20' : '500',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        suffixText: _discountType == 'Percentage' ? '%' : '₱',
        suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                date != null ? _formatDate(date) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _showCountdown = !_showCountdown),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _showCountdown,
              onChanged: (bool? value) => setState(() => _showCountdown = value ?? false),
              activeColor: const Color(0xFF2563EB),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Show countdown timer on product page',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}