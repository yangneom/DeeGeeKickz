import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/discount_model.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';

// ================================================
// EDIT DISCOUNT DIALOG
//
// Product is NOT editable once a discount is created
// (matches DiscountService.updateDiscount's contract) —
// only type, value, duration, and status can change.
//
// How to open:
//   showEditDiscountDialog(context, discount: discount);
// ================================================

Future<bool?> showEditDiscountDialog(
  BuildContext context, {
  required Discount discount,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return EditDiscountDialog(discount: discount);
    },
  );
}

class EditDiscountDialog extends StatefulWidget {
  final Discount discount;

  const EditDiscountDialog({super.key, required this.discount});

  @override
  State<EditDiscountDialog> createState() => _EditDiscountDialogState();
}

class _EditDiscountDialogState extends State<EditDiscountDialog> {
  final DiscountService _discountService = DiscountService();

  late String _discountType;
  late TextEditingController _valueController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedStatus;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _discountType = widget.discount.discountType == 'Percentage' ? 'Percentage' : 'Fixed';
    _valueController = TextEditingController(
      text: _trimNumber(widget.discount.discountValue),
    );
    _startDate = widget.discount.startDate;
    _endDate = widget.discount.endDate;
    _selectedStatus = widget.discount.status;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String _trimNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

  double _calculateFinalPrice() {
    final double discountValue = double.tryParse(_valueController.text) ?? 0;
    double finalPrice;
    if (_discountType == 'Percentage') {
      finalPrice = widget.discount.originalPrice - (widget.discount.originalPrice * (discountValue / 100));
    } else {
      finalPrice = widget.discount.originalPrice - discountValue;
    }
    if (finalPrice < 0) finalPrice = 0;
    return finalPrice;
  }

  String _addCommas(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = ',$result';
      result = numStr[i] + result;
      count++;
    }
    return result;
  }

  Future<void> _handleSave() async {
    if (_valueController.text.isEmpty) {
      _showError('Please enter a discount value.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showError('End date must be after start date.');
      return;
    }
    final double? discountValue = double.tryParse(_valueController.text);
    if (discountValue == null) {
      _showError('Discount value must be a number.');
      return;
    }

    setState(() => _isSaving = true);

    final String? error = await _discountService.updateDiscount(
      discountId: widget.discount.discountId,
      discountType: _discountType,
      discountValue: discountValue,
      startDate: _startDate,
      endDate: _endDate,
      status: _selectedStatus,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showError('Failed to save changes: $error');
      return;
    }

    Navigator.pop(context, true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Discount',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                  GestureDetector(
                    onTap: _isSaving ? null : () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Product — locked, display only
              const Text('Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.discount.productName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      widget.discount.originalPriceDisplay,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Product can\'t be changed after a discount is created.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ),

              const SizedBox(height: 20),

              const Text('Discount Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              _buildDiscountTypeSelector(),

              const SizedBox(height: 20),

              const Text('Discount Value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              _buildValueInput(),

              if (_valueController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Final price: ₱${_addCommas(_calculateFinalPrice().toInt())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                  ),
                ),

              const SizedBox(height: 20),

              const Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDatePicker(label: 'Start Date', date: _startDate, onTap: () => _pickDate(isStart: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDatePicker(label: 'End Date', date: _endDate, onTap: () => _pickDate(isStart: false))),
                ],
              ),

              const SizedBox(height: 20),

              const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRadio(label: 'Active', value: 'Active'),
                  const SizedBox(width: 24),
                  _buildRadio(label: 'Inactive', value: 'Inactive'),
                ],
              ),

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
                      onPressed: _isSaving ? null : _handleSave,
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
                          : const Text('Save Changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildDiscountTypeSelector() {
    return Row(
      children: [
        Expanded(child: _buildTypeCard(label: 'Percentage', icon: '%', value: 'Percentage')),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeCard(label: 'Fixed Amount', icon: '₱', value: 'Fixed')),
      ],
    );
  }

  Widget _buildTypeCard({required String label, required String icon, required String value}) {
    final bool isSelected = _discountType == value;
    return GestureDetector(
      onTap: () => setState(() => _discountType = value),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151)),
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
        suffixText: _discountType == 'Percentage' ? '%' : '₱',
        suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Row(
          children: [
            Expanded(child: Text(_formatDate(date), style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio({required String label, required String value}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _selectedStatus,
            onChanged: (String? newValue) {
              if (newValue != null) setState(() => _selectedStatus = newValue);
            },
            activeColor: const Color(0xFF2563EB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}