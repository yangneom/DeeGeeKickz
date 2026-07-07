import 'package:flutter/material.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../common/buttons/table_pill_button.dart';
import 'create_discount_dialog.dart';
import 'edit_discount_dialog.dart';
import '../../../models/discount_model.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';

class DiscountsTable extends StatefulWidget {
  const DiscountsTable({super.key});

  @override
  State<DiscountsTable> createState() => _DiscountsTableState();
}

class _DiscountsTableState extends State<DiscountsTable> {
  final DiscountService _discountService = DiscountService();
  List<Discount> _discounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiscounts();
  }

  Future<void> _fetchDiscounts() async {
    setState(() => _isLoading = true);
    final List<Discount> result = await _discountService.fetchDiscounts();
    if (!mounted) return;
    setState(() {
      _discounts = result;
      _isLoading = false;
    });
  }

  String _formatDateRange(DateTime start, DateTime end) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String startStr = '${months[start.month - 1]} ${start.day}';
    final String endStr = '${months[end.month - 1]} ${end.day}';
    return '$startStr – $endStr';
  }

  // ================================================
  // OPEN CREATE DISCOUNT DIALOG
  // ================================================
  Future<void> _handleCreateDiscount() async {
    final bool? result = await showCreateDiscountDialog(context);
    if (result != true) return;
    await _fetchDiscounts();
  }

  Future<void> _handleEditDiscount(Discount discount) async {
    final bool? result = await showEditDiscountDialog(context, discount: discount);
    if (result != true) return;
    await _fetchDiscounts();
  }

  Future<void> _handleDelete(Discount discount) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this discount?',
      message: 'This discount will be permanently removed and the product will return to its original price.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    final String? error = await _discountService.deleteDiscount(discountId: discount.discountId);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete discount: $error'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }
    await _fetchDiscounts();
  }

  Widget _buildStatusBadge(String status) {
    final bool isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFD1D5DB),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---- HEADER ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Discounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create limited-time discounts for specific shoes — or just specific colors.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleCreateDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Create Discount',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- COLUMN HEADERS ----
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: _HeaderCell('Product')),
                Expanded(flex: 2, child: _HeaderCell('Original Price')),
                Expanded(flex: 2, child: _HeaderCell('Discount')),
                Expanded(flex: 2, child: _HeaderCell('Final Price')),
                Expanded(flex: 2, child: _HeaderCell('Duration')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Actions')),
              ],
            ),
          ),

          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- ROWS ----
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_discounts.isEmpty)
            const _EmptyMessage('No discounts yet.')
          else
            for (int i = 0; i < _discounts.length; i++)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [

                        // Product Name — shows "— Red" suffix when this
                        // discount targets only one color/variant.
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _discounts[i].productName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (_discounts[i].isVariantSpecific)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _discounts[i].variantColor ?? 'Specific color',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Original Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i].originalPriceDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),

                        // Discount
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i].discountDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),

                        // Final Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i].finalPriceDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),

                        // Duration
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatDateRange(_discounts[i].startDate, _discounts[i].endDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),

                        // Status badge
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStatusBadge(_discounts[i].status),
                          ),
                        ),

                        // Actions — pill buttons
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TablePillButton.edit(
                                onPressed: () => _handleEditDiscount(_discounts[i]),
                              ),
                              const SizedBox(width: 8),
                              TablePillButton.delete(
                                onPressed: () => _handleDelete(_discounts[i]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _discounts.length - 1)
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---- Private helpers ----

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String message;
  const _EmptyMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}