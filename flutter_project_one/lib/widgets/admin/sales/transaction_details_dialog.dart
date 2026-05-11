import 'package:flutter/material.dart';
import '../../../widgets/common/common_table.dart';

// ================================================
// TRANSACTION DETAILS DIALOG
// shows full details of a sale when View is clicked
// structured like AddProductDialog:
//   - fixed header at top
//   - scrollable content in middle
//   - fixed Back button at bottom
// ================================================
class TransactionDetailsDialog extends StatelessWidget {

  // the sale data passed in from the table row
  final Map<String, String> sale;

  const TransactionDetailsDialog({
    super.key,
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {

    // get screen size so we can size the dialog properly
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(

      // removes default padding around the dialog
      insetPadding: EdgeInsets.zero,

      // white background, no pink
      backgroundColor: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Container(

        // same sizing style as AddProductDialog
        width: screenWidth < 700 ? screenWidth * 0.95 : 700,
        height: screenHeight * 0.90,

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),

        // Column has 3 parts:
        // 1. fixed header
        // 2. scrollable content (Expanded)
        // 3. fixed footer with Back button
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================================================
            // PART 1 — FIXED HEADER
            // stays at top even when scrolling
            // ================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // title
                  const Text(
                    'TRANSACTION DETAILS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: 1.0,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // subtitle
                  const Text(
                    'Summary of the customer purchase and payment information.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // date row with calendar icon
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sale['date'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // divider line under header
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ================================================
            // PART 2 — SCROLLABLE CONTENT
            // Expanded makes it fill the space between
            // the header and footer
            // ================================================
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // items purchased table
                    _buildItemsSection(),

                    const SizedBox(height: 32),

                    // payment info + summary side by side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // left — payment information
                        Expanded(
                          child: _buildPaymentInfo(),
                        ),

                        const SizedBox(width: 16),

                        // right — order summary
                        Expanded(
                          child: _buildSummary(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ================================================
            // PART 3 — FIXED FOOTER
            // stays at bottom even when scrolling
            // same style as AddProductDialog bottom buttons
            // ================================================
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  // Back button closes the dialog
                  OutlinedButton(
                    onPressed: () {

                      // Navigator.pop closes this dialog
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // ITEMS PURCHASED SECTION
  // full-width table showing all items in this order
  // fake data for now — replace with Firebase later
  // ================================================
  // ================================================
// ITEMS PURCHASED SECTION
// now uses CommonTable — the reusable table widget
// just like how SalesScreen uses it
// ================================================
Widget _buildItemsSection() {

  // fake items for now — replace with Firebase later
  final List<Map<String, String>> items = [
    {
      'name': 'Nike Air Max',
      'brand': 'Nike',
      'size': '42',
      'qty': '1',
      'price': '5,500',
      'total': '5,500',
    },
  ];

  // ------------------------------------------------
  // BUILD ROWS
  // convert each item map into a list of widgets
  // same pattern as _buildRows() in sales_screen.dart
  // ------------------------------------------------
  List<List<Widget>> tableRows = [];

  for (int i = 0; i < items.length; i = i + 1) {

    // get current item
    Map<String, String> item = items[i];

    // build one row — each entry is one cell
    List<Widget> oneRow = [

      // column 1 — product name
      Text(
        item['name']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),

      // column 2 — brand
      Text(
        item['brand']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),

      // column 3 — size
      Text(
        item['size']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),

      // column 4 — quantity
      Text(
        item['qty']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),

      // column 5 — unit price
      Text(
        item['price']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),

      // column 6 — total
      Text(
        item['total']!,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),
    ];

    // add this row to our list
    tableRows.add(oneRow);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // section title
      const Text(
        'Items Purchased',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),

      const SizedBox(height: 12),

      // CommonTable handles all the styling!
      // just pass headers and the rows we built above
      CommonTable(
        headers: const [
          'Product Name',
          'Brand',
          'Size',
          'Quantity',
          'Unit Price',
          'Total',
        ],
        rows: tableRows,
      ),
    ],
  );
}

  // ================================================
  // TABLE HEADER CELL — gray label text
  // ================================================
  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  // ================================================
  // TABLE DATA CELL — dark normal text
  // ================================================
  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  // ================================================
  // PAYMENT INFORMATION SECTION
  // ================================================
  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // section title
          const Text(
            'Payment Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 20),

          // payment method
          _buildInfoRow(
            icon: Icons.credit_card_outlined,
            label: 'Payment Method',
            value: sale['payment'] ?? '',
          ),

          const SizedBox(height: 16),

          // reference number
          _buildInfoRow(
            icon: Icons.tag,
            label: 'Reference Number',
            value: sale['reference'] ?? '',
          ),

          const SizedBox(height: 16),

          // payment status — special green badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    'Payment Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // green Paid badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // green dot
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 6),

                        const Text(
                          'Paid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // receipt link
          _buildInfoRow(
            icon: Icons.receipt_outlined,
            label: 'Receipt',
            value: 'View Receipt',
            isLink: true,
          ),
        ],
      ),
    );
  }

  // ================================================
  // REUSABLE INFO ROW
  // icon on left, label above value below
  // ================================================
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Icon(icon, size: 16, color: const Color(0xFF6B7280)),

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // gray label
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 2),

            // value — blue if link, dark if normal
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isLink
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================
  // ORDER SUMMARY SECTION
  // ================================================
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // section title
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 20),

          // subtotal row
          _buildSummaryRow(
            label: 'Subtotal',
            value: sale['total'] ?? '0',
          ),

          const SizedBox(height: 12),

          const Divider(color: Color(0xFFE5E7EB)),

          const SizedBox(height: 12),

          // discount row — green color, fake 0 for now
          _buildSummaryRow(
            label: 'Discount',
            value: '0',
            isDiscount: true,
          ),

          const SizedBox(height: 16),

          // total amount box in blue
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),

                Text(
                  sale['total'] ?? '0',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // SUMMARY ROW — label + value in one line
  // ================================================
  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),

        Text(
          isDiscount ? '-$value' : value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDiscount
                ? const Color(0xFF16A34A)
                : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}