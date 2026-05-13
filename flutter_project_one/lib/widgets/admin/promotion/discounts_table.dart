import 'package:flutter/material.dart';
import '../../common/confirm_dialog.dart';
import 'create_discount_dialog.dart'; // 👈 import the dialog

class DiscountsTable extends StatefulWidget {
  const DiscountsTable({super.key});

  @override
  State<DiscountsTable> createState() => _DiscountsTableState();
}

class _DiscountsTableState extends State<DiscountsTable> {

  final List<Map<String, dynamic>> _discounts = [
    {
      'productName': 'Nike Air Max 270',
      'originalPrice': '₱5,500',
      'discount': '20%',
      'discountType': 'percent',
      'finalPrice': '₱4,400',
      'duration': 'Jun 1 – Jun 30',
      'status': 'Active',
    },
    {
      'productName': 'Jordan 1 Retro High',
      'originalPrice': '₱8,500',
      'discount': '15%',
      'discountType': 'percent',
      'finalPrice': '₱7,225',
      'duration': 'Mar 10 – Apr 10',
      'status': 'Active',
    },
    {
      'productName': 'Adidas Ultraboost 22',
      'originalPrice': '₱7,200',
      'discount': '₱1000',
      'discountType': 'fixed',
      'finalPrice': '₱6,200',
      'duration': 'Feb 15 – Mar 15',
      'status': 'Inactive',
    },
  ];

  // ================================================
  // OPEN CREATE DISCOUNT DIALOG
  // Waits for the result and adds it to the list
  // ================================================
  Future<void> _handleCreateDiscount() async {
    final Map<String, dynamic>? result = await showCreateDiscountDialog(context);

    // if user cancelled, result is null — do nothing
    if (result == null) return;

    // add the new discount to the list
    setState(() {
      _discounts.add(result);
    });
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

  Widget _buildActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onEdit,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onDelete,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
              SizedBox(width: 4),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleDelete(int index) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this discount?',
      message: 'This discount will be permanently removed and the product will return to its original price.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;
    setState(() => _discounts.removeAt(index));
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
                      'Create limited-time discounts for specific shoes.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleCreateDiscount, // 👈 connected
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
          if (_discounts.isEmpty)
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

                        // Product Name
                        Expanded(
                          flex: 3,
                          child: Text(
                            _discounts[i]['productName'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),

                        // Original Price
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i]['originalPrice'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),

                        // Discount — blue
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i]['discount'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),

                        // Final Price — bold
                        Expanded(
                          flex: 2,
                          child: Text(
                            _discounts[i]['finalPrice'],
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
                            _discounts[i]['duration'],
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
                            child: _buildStatusBadge(_discounts[i]['status']),
                          ),
                        ),

                        // Actions
                        Expanded(
                          flex: 2,
                          child: _buildActions(
                            onEdit: () {
                              // TODO: open edit discount dialog
                            },
                            onDelete: () => _handleDelete(i),
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