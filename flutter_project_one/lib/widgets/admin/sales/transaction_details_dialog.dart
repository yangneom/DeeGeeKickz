import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/order.dart';
import '../../../services/admin/sales/sales_management_service.dart';
import '../../common/tables/common_table.dart';

class TransactionDetailsDialog extends StatefulWidget {
  final SaleRecord sale;

  const TransactionDetailsDialog({super.key, required this.sale});

  @override
  State<TransactionDetailsDialog> createState() => _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState extends State<TransactionDetailsDialog> {
  final SalesManagementService _service = SalesManagementService();
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _service.loadSaleDetails(widget.sale.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isInStore = widget.sale.orderType == 'In-Store';

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenWidth < 700 ? screenWidth * 0.95 : 700,
        height: screenHeight * 0.90,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Failed to load: ${snapshot.error}'));
            }

            final Map<String, dynamic> details = snapshot.data!;
            final List<OrderItem> items = details['items'] as List<OrderItem>;
            final String referenceNumber = details['referenceNumber'] as String;
            final String paymentStatus = details['paymentStatus'] as String;
            final String? receiptUrl = details['receiptUrl'] as String?;

            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER — title + subtitle + divider, matches
                // Edit Product / Order Details convention ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transaction Details',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, size: 22, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${widget.sale.orderId} · ${isInStore ? 'In-Store' : 'Online'} · ${widget.sale.dateTime}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                    ],
                  ),
                ),

                // ── SCROLLABLE BODY — one flat box per section,
                // stacked full-width, matching Order Details ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildItemsAndSummarySection(items, isInStore),
                        const SizedBox(height: 16),
                        _buildPaymentInfoSection(referenceNumber, paymentStatus, receiptUrl),
                      ],
                    ),
                  ),
                ),

                // ── FOOTER ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================================================
  // ONE combined box: item table + subtotal/shipping/
  // discount/total together, same as how Order Details
  // keeps its item list and totals in a single box.
  // ================================================
  Widget _buildItemsAndSummarySection(List<OrderItem> items, bool isInStore) {
    List<List<Widget>> tableRows = items.map((item) {
      return [
        Text(item.productName, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(item.brand, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(item.size.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(item.quantity.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text('₱${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text('₱${item.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
      ];
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 16),
          CommonTable(
            headers: const ['Product Name', 'Brand', 'Size', 'Quantity', 'Unit Price', 'Total'],
            rows: tableRows,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', '₱${widget.sale.subtotal.toStringAsFixed(0)}'),
          if (!isInStore) ...[
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Shipping',
              widget.sale.shipping > 0 ? '₱${widget.sale.shipping.toStringAsFixed(0)}' : 'FREE',
            ),
          ],
          if (widget.sale.discountAmount > 0) ...[
            const SizedBox(height: 10),
            _buildSummaryRow('Discount', '-₱${widget.sale.discountAmount.toStringAsFixed(0)}', valueColor: const Color(0xFF16A34A)),
          ],
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              Text(
                '₱${widget.sale.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? const Color(0xFF111827))),
      ],
    );
  }

  // ================================================
  // ONE box: Payment Information — plain label/value
  // pairs in a 2-column grid, same pattern as Customer
  // Information in Order Details.
  // ================================================
  Widget _buildPaymentInfoSection(String referenceNumber, String paymentStatus, String? receiptUrl) {
    final bool isPaid = paymentStatus == 'Paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLabelValue('Payment Method', widget.sale.paymentMethod)),
              Expanded(child: _buildLabelValue('Reference Number', referenceNumber.isNotEmpty ? referenceNumber : '—')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Status', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF92400E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            paymentStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (receiptUrl != null && receiptUrl.isNotEmpty)
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final Uri uri = Uri.parse(receiptUrl);
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: _buildLabelValue('Receipt', 'View Receipt', isLink: true),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value, {bool isLink = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isLink ? const Color(0xFF2563EB) : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}