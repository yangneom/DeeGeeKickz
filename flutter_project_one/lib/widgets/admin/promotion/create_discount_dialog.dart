import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../common/dialog/app_toast.dart';// ================================================
// CREATE DISCOUNT DIALOG
//
// Lets the admin create a new discount for a real
// product, wired to Supabase via DiscountService.
//
// Fields:
//   - Select Product (search-as-you-type)
//   - Apply To: Whole Product (default) OR a specific
//     color/variant — only shown once a product with
//     more than one variant is selected.
//   - Discount Type (Percentage OR Fixed Amount)
//   - Discount Value (number input)
//   - Start Date + End Date (date pickers)
//   - Show countdown timer checkbox (UI-only, no
//     matching column yet)
//
// How to open:
//   showCreateDiscountDialog(context);
// Returns `true` on success — DiscountsTable re-fetches.
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
  double _selectedOriginalPrice = 0; // whole-product min price

  // ── APPLY TO (variant targeting) ──
  // false = whole product (default), true = specific color.
  bool _applyToSpecificVariant = false;
  bool _isLoadingVariants = false;
  List<Map<String, dynamic>> _productVariants = []; // {variantId, color, retailPrice}
  int? _selectedVariantId;
  String? _selectedVariantColor;

  // ── DISCOUNT TYPE ──
  String _discountType = 'Percentage';

  final TextEditingController _valueController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _showCountdown = false;
  bool _isSaving = false;

  // Inline errors, each shown under the field it belongs to.
  String? _productError;
  String? _variantError;
  String? _valueError;
  String? _dateError;
  @override
  void dispose() {
    _searchController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  // ================================================
  // SEARCH PRODUCTS
  // ================================================
  Future<void> _handleSearchChanged(String query) async {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _selectedOriginalPrice = 0;
      _applyToSpecificVariant = false;
      _productVariants = [];
      _selectedVariantId = null;
      _selectedVariantColor = null;
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

  Future<void> _selectProduct(Map<String, dynamic> result) async {
    setState(() {
      _selectedProductId = result['productId'] as int;
      _productError = null;
      _selectedProductName = result['productName'] as String;
      _selectedOriginalPrice = result['originalPrice'] as double;
      _searchController.text = _selectedProductName!;
      _searchResults = [];
      _applyToSpecificVariant = false;
      _selectedVariantId = null;
      _selectedVariantColor = null;
      _isLoadingVariants = true;
    });

    final List<Map<String, dynamic>> variants =
        await _discountService.fetchVariantsForProduct(_selectedProductId!);
    if (!mounted) return;
    setState(() {
      _productVariants = variants;
      _isLoadingVariants = false;
    });
  }

  void _selectVariant(Map<String, dynamic> variant) {
    setState(() {
      _selectedVariantId = variant['variantId'] as int;
      _variantError = null;
      _selectedVariantColor = variant['color'] as String;
    });
  }

  // The price basis for the live preview — the selected variant's
  // own price if targeting a specific color, otherwise the
  // whole-product min price.
 double get _previewOriginalPrice {
  if (_applyToSpecificVariant && _selectedVariantId != null) {
    for (final Map<String, dynamic> v in _productVariants) {
      if (v['variantId'] == _selectedVariantId) {
        return (v['retailPrice'] as num).toDouble();
      }
    }
  }
  return _selectedOriginalPrice;
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
          _dateError = null;
        } else {
          _endDate = picked;
          _dateError = null;
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

  double _calculateFinalPrice() {
    if (_selectedProductId == null) return 0;
    final double discountValue = double.tryParse(_valueController.text) ?? 0;
    final double basis = _previewOriginalPrice;

    double finalPrice;
    if (_discountType == 'Percentage') {
      finalPrice = basis - (basis * (discountValue / 100));
    } else {
      finalPrice = basis - discountValue;
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
Future<void> _handleApply() async {
  setState(() {
    _productError = null;
    _variantError = null;
    _valueError = null;
    _dateError = null;
  });  if (_selectedProductId == null) {
   setState(() => _productError = 'Please select a product.');
    return;
  }
  if (_applyToSpecificVariant && _selectedVariantId == null) {
    setState(() => _variantError = 'Please select which color this discount applies to.');
    return;
  }
  if (_valueController.text.isEmpty) {
    setState(() => _valueError = 'Please enter a discount value.');
    return;
  }
  if (_startDate == null || _endDate == null) {
    setState(() => _dateError = 'Please pick a start and end date.');
    return;
  }
  if (_endDate!.isBefore(_startDate!)) {
    setState(() => _dateError = 'End date must be after the start date.');
    return;
  }

  final double? discountValue = double.tryParse(_valueController.text);
  if (discountValue == null) {
    setState(() => _valueError = 'Discount value must be a number.');
    return;
  }
  if (_discountType == 'Percentage' && discountValue > 100) {
    setState(() => _valueError = 'Percentage discount cannot exceed 100%.');
    return;
  }
  if (discountValue <= 0) {
    setState(() => _valueError = 'Discount value must be greater than 0.');
    return;
  }

  setState(() => _isSaving = true);

  // NEW: block overlapping discounts for the same scope + date range.
  final bool overlaps = await _discountService.hasOverlappingDiscount(
    productId: _selectedProductId!,
    variantId: _applyToSpecificVariant ? _selectedVariantId : null,
    startDate: _startDate!,
    endDate: _endDate!,
  );

  if (!mounted) return;

  if (overlaps) {
    setState(() => _isSaving = false);
    _showError(
      _applyToSpecificVariant
          ? 'This color already has an active discount during this period.'
          : 'This product already has an active whole-product discount during this period.',
    );
    return;
  }

  // Cross-scope check: does the OTHER scope have an active discount
  // overlapping this period? Not blocked — just confirmed, since the
  // variant-specific one will still correctly win at checkout.
  if (_applyToSpecificVariant) {
    final bool wholeProductOverlap = await _discountService.hasOverlappingDiscount(
      productId: _selectedProductId!,
      variantId: null, // check the WHOLE-PRODUCT scope instead
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    if (wholeProductOverlap) {
      setState(() => _isSaving = false);
      final bool? confirmed = await showConfirmDialog(
        context: context,
        title: 'Overlaps a whole-product discount',
        message: 'This product already has an active whole-product discount '
            'during this period. If you continue, this color will use its '
            'own discount instead of the whole-product one during the '
            'overlap — the whole-product discount still applies to the '
            'other colors.',
        confirmLabel: 'Continue Anyway',
        confirmColor: const Color(0xFF2563EB),
      );
      if (confirmed != true) return;
      setState(() => _isSaving = true);
    }
  }

  final String? error = await _discountService.addDiscount(
    productId: _selectedProductId!,
    variantId: _applyToSpecificVariant ? _selectedVariantId : null,
    discountType: _discountType,
    discountValue: discountValue,
    startDate: _startDate!,
    endDate: _endDate!,
    status: 'Active',
  );

  if (!mounted) return;
  setState(() => _isSaving = false);

  if (error != null) {
    _showError('We could not create the discount. Please try again.');
    return;
  }

  Navigator.pop(context, true);
}

  void _showError(String message) {
    AppToast.error(context, message, title: 'Discount not saved');
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
              const Text(
                'Create Discount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set up a new discount for a product.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 24),

              _buildLabel('Select Product'),
              const SizedBox(height: 8),
              _buildProductSearchField(), 
              _buildFieldError(_productError),

              // ── APPLY TO — only shown once a product with 2+
              // variants is selected. Single-variant products skip
              // this entirely since "whole product" and "that one
              // variant" are the same thing.
              if (_selectedProductId != null && _productVariants.length > 1) ...[
                const SizedBox(height: 20),
                _buildLabel('Apply To'),
                const SizedBox(height: 8),
                _buildApplyToSelector(),
                if (_applyToSpecificVariant) ...[
                  const SizedBox(height: 12),
                  _buildVariantColorPicker(),
                  _buildFieldError(_variantError),
                ],
              ],

              const SizedBox(height: 20),

              _buildLabel('Discount Type'),
              const SizedBox(height: 8),
              _buildDiscountTypeSelector(),

              const SizedBox(height: 20),

              _buildLabel('Discount Value'),
              const SizedBox(height: 8),
              _buildValueInput(),
              _buildFieldError(_valueError),

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
                            _buildFieldError(_dateError),
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

  Widget _buildFieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
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
        if (_searchController.text.trim().isNotEmpty &&
            _searchResults.isEmpty &&
            !_isSearching &&
            _selectedProductId == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No matching in-stock products found. Products with no '
              'available stock can\'t be discounted until restocked.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
              _isLoadingVariants
                  ? 'Selected: $_selectedProductName (loading colors...)'
                  : 'Selected: $_selectedProductName (₱${_addCommas(_previewOriginalPrice.toInt())})',
              style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  // ================================================
  // APPLY TO SELECTOR
  // Whole Product (default) vs Specific Color
  // ================================================
  Widget _buildApplyToSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildApplyToCard(
            label: 'Whole Product',
            subtitle: 'All colors',
            selected: !_applyToSpecificVariant,
            onTap: () => setState(() {
              _applyToSpecificVariant = false;
              _selectedVariantId = null;
              _selectedVariantColor = null;
              _variantError = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildApplyToCard(
            label: 'Specific Color',
            subtitle: 'One variant only',
            selected: _applyToSpecificVariant,
            onTap: () => setState(() => _applyToSpecificVariant = true),
          ),
        ),
      ],
    );
  }

  Widget _buildApplyToCard({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // VARIANT COLOR PICKER
  // Shown only when "Specific Color" is selected.
  // ================================================
  Widget _buildVariantColorPicker() {
    if (_isLoadingVariants) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _productVariants.map((variant) {
        final bool isSelected = _selectedVariantId == variant['variantId'];
        return GestureDetector(
          onTap: () => _selectVariant(variant),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${variant['color']} · ₱${_addCommas((variant['retailPrice'] as double).toInt())}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
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
          _valueError = null;
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
      onChanged: (_) => setState(() => _valueError = null),
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