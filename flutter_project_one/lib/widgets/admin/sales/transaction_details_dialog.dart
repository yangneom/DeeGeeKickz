import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/order.dart';
import '../../../services/admin/sales/sales_management_service.dart';
import '../../common/tables/common_table.dart';

class TransactionDetailsDialog extends StatefulWidget {
  final SaleRecord sale; // ← was Map<String,String>, now real data

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
    final double screenWidth  = MediaQuery.of(context).size.width;

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
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRANSACTION DETAILS',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text('Order #${widget.sale.orderId} · ${widget.sale.orderType == 'In-Store' ? 'In-Store' : 'Online'}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Text(widget.sale.dateTime, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E7EB), height: 1),
                    ],
                  ),
                ),

                // ── SCROLLABLE BODY ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildItemsSection(items),
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPaymentInfo(referenceNumber, paymentStatus, receiptUrl)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummary()),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── FOOTER ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
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

  // ── ITEMS TABLE — now real data from order_item ──
  Widget _buildItemsSection(List<OrderItem> items) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Items Purchased', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        CommonTable(
          headers: const ['Product Name', 'Brand', 'Size', 'Quantity', 'Unit Price', 'Total'],
          rows: tableRows,
        ),
      ],
    );
  }

  // ── PAYMENT INFO — now real data from payment table ──
  Widget _buildPaymentInfo(String referenceNumber, String paymentStatus, String? receiptUrl) {
    final bool isPaid = paymentStatus == 'Paid';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 20),
          _buildInfoRow(icon: Icons.credit_card_outlined, label: 'Payment Method', value: widget.sale.paymentMethod),
          const SizedBox(height: 16),
          _buildInfoRow(icon: Icons.tag, label: 'Reference Number', value: referenceNumber.isNotEmpty ? referenceNumber : '—'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Status', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
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
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF92400E), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(paymentStatus,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF92400E))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final Uri uri = Uri.parse(receiptUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: _buildInfoRow(icon: Icons.receipt_outlined, label: 'Receipt', value: 'View Receipt', isLink: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value, bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isLink ? const Color(0xFF2563EB) : const Color(0xFF111827))),
          ],
        ),
      ],
    );
  }

  // ── SUMMARY — now real subtotal/shipping/discount/total from the order ──
  //
  // UPDATE: added the Shipping row that was missing before. Without
  // it, Subtotal - Discount visibly didn't equal Total for any order
  // that had a real shipping fee baked into total_amount — the ₱10
  // difference just looked like a math error with no explanation.
  // Now: Subtotal + Shipping - Discount = Total, and every part of
  // that is shown.
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 20),
          _buildSummaryRow(label: 'Subtotal', value: '₱${widget.sale.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          _buildSummaryRow(
            label: 'Shipping',
            value: widget.sale.shipping > 0 ? '₱${widget.sale.shipping.toStringAsFixed(0)}' : 'FREE',
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          _buildSummaryRow(label: 'Discount', value: '₱${widget.sale.discountAmount.toStringAsFixed(0)}', isDiscount: true),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                Text('₱${widget.sale.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(isDiscount ? '-$value' : value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDiscount ? const Color(0xFF16A34A) : const Color(0xFF111827))),
      ],
    );
  }
}