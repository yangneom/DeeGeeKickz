import 'package:flutter/material.dart';
import '../../../models/order.dart';

// ================================================
// ORDER DETAILS DIALOG
// ================================================

void showOrderDetailsDialog(
  BuildContext context,
  Order order,
  Function(String newStatus) onStatusUpdated,
) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return OrderDetailsDialog(
        order: order,
        onStatusUpdated: onStatusUpdated,
      );
    },
  );
}

class OrderDetailsDialog extends StatefulWidget {

  // ✅ FIXED — Order model instead of Map
  final Order order;
  final Function(String newStatus) onStatusUpdated;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.onStatusUpdated,
  });

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {

  final TextEditingController _adminNoteController = TextEditingController();
  final TextEditingController _lalamoveLinkController = TextEditingController();

  late String _currentStatus;

  final List<String> _steps = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Shipped',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    // ✅ FIXED — use dot notation
    _currentStatus = widget.order.orderStatus;
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    _lalamoveLinkController.dispose();
    super.dispose();
  }

  int _getStepIndex(String status) {
    for (int i = 0; i < _steps.length; i = i + 1) {
      if (_steps[i] == status) {
        return i;
      }
    }
    return 0;
  }

  // ================================================
  // BUILD ORDER PROGRESS STEPPER
  // ================================================
  Widget _buildProgressStepper() {
    int currentIndex = _getStepIndex(_currentStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length, (int index) {
              bool isDone = index < currentIndex;
              bool isCurrent = index == currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone || isCurrent
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE5E7EB),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrent
                                          ? Colors.white
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _steps[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isDone || isCurrent
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF9CA3AF),
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 22),
                          color: isDone
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD CUSTOMER INFO
  // ================================================
  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // ✅ FIXED — dot notation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', widget.order.customerName),
                    const SizedBox(height: 8),
                    _buildInfoRow('Contact', widget.order.contact),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Landmark', widget.order.landmark),
                    const SizedBox(height: 8),
                    _buildInfoRow('Address', widget.order.address),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD ITEMS TABLE
  // ================================================
  Widget _buildItemsTable() {

    // ✅ FIXED — Order model uses List<OrderItem>
    List<OrderItem> items = widget.order.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Purchase',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [

              // header row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    Expanded(flex: 2, child: Text('Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    Expanded(flex: 1, child: Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    Expanded(flex: 2, child: Text('Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  ],
                ),
              ),

              // ✅ FIXED — use OrderItem dot notation
              for (int i = 0; i < items.length; i = i + 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          items[i].productName,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          items[i].brand,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          items[i].size.toString(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          items[i].quantity.toString(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₱${items[i].price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₱${items[i].total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD ACTION BUTTONS
  // ================================================
  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [

        if (_currentStatus == 'Confirmed')
          ElevatedButton(
            onPressed: () => setState(() => _currentStatus = 'Preparing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Preparing', style: TextStyle(fontSize: 13)),
          ),

        if (_currentStatus == 'Preparing')
          ElevatedButton(
            onPressed: () => setState(() => _currentStatus = 'Shipped'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Shipped', style: TextStyle(fontSize: 13)),
          ),

        if (_currentStatus == 'Shipped')
          ElevatedButton(
            onPressed: () => setState(() => _currentStatus = 'Completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7280),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Completed', style: TextStyle(fontSize: 13)),
          ),

        if (_currentStatus == 'Pending')
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Reject Order', style: TextStyle(fontSize: 13)),
          ),

        if (_currentStatus == 'Pending')
          ElevatedButton(
            onPressed: () => setState(() => _currentStatus = 'Confirmed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Accept Order', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  @override
Widget build(BuildContext context) {
  return Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 800,
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── FIXED HEADER — always visible ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review order information and manage order status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // ── SCROLLABLE BODY ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── ORDER PROGRESS ──
                  _buildProgressStepper(),

                  const SizedBox(height: 16),

                  // ── CUSTOMER INFO ──
                  _buildCustomerInfo(),

                  const SizedBox(height: 16),

                  // ── ITEMS TABLE ──
                  _buildItemsTable(),

                  const SizedBox(height: 16),

                  // ── ADMIN NOTE + LALAMOVE side by side ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // admin note
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Note',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _adminNoteController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'e.g., Your order will be shipped tomorrow',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // lalamove link
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lalamove link',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _lalamoveLinkController,
                              decoration: InputDecoration(
                                hintText: 'Please insert the lalamove delivery link',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── ACTION BUTTONS — bottom right ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildActionButtons(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}