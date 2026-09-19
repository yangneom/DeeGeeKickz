import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../models/sale.dart';
// ================================================
// RECEIPT DIALOG
//
// Shows a receipt preview after payment is confirmed.
// Cashier can Print or Save as PDF.
//
// IMPORTANT:
//   Sale is already saved BEFORE this dialog opens.
//   This dialog is purely for the physical receipt.
//   Closing without printing does NOT cancel the sale.
//
// DISCOUNT DISPLAY:
//   Each SaleItem carries both retailPrice (charged) and
//   originalPrice (undiscounted). If they differ, the item row
//   shows the original price with a strikethrough next to the
//   charged price, and a "You saved ₱X" summary line appears
//   near the total — computed from Sale.totalSavings, which
//   sums each item's own discount. This reflects whatever
//   discount the ADMIN configured; there is no separate
//   cashier-entered discount anymore.
//
// HOW TO USE:
//
//   showReceiptDialog(
//     context: context,
//     sale: completedSale,
//   );
//
// ================================================

void showReceiptDialog({
  required BuildContext context,
  required Sale sale,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return ReceiptDialog(sale: sale);
    },
  );
}


// ================================================
// RECEIPT DIALOG WIDGET
// ================================================
class ReceiptDialog extends StatefulWidget {

  final Sale sale;

  const ReceiptDialog({
    super.key,
    required this.sale,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {

  // tracks if PDF is being generated
  bool _isGenerating = false;

  // ================================================
  // FORMAT PRICE
  // 5500.0 → "₱5,500"
  // ================================================
  String _formatPrice(double price) {
    int priceAsInt = price.toInt();
    String priceString = priceAsInt.toString();
    String result = '';
    int count = 0;

    for (int i = priceString.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',' + result;
      }
      result = priceString[i] + result;
      count++;
    }

    return '₱$result';
  }

  // ================================================
  // FORMAT DATE
  // DateTime → "May 31, 2025 · 10:30 AM"
  // ================================================
  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String month = months[date.month - 1];
    String day = date.day.toString();
    String year = date.year.toString();

    int hour = date.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    String minute = date.minute.toString().padLeft(2, '0');

    return '$month $day, $year · $hour:$minute $period';
  }

  // ================================================
  // GENERATE PDF
  // builds the PDF document using the pdf package
  // ================================================
    static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  Future<pw.Document> _generatePdf() async {

    // Cached after the first load — re-loading and re-embedding two
    // full TTF files on EVERY print/save was unnecessary repeated
    // work, and a meaningful chunk of the CPU time causing the freeze.
    if (_cachedRegular == null || _cachedBold == null) {
      final ByteData regularData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final ByteData boldData =
          await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _cachedRegular = pw.Font.ttf(regularData);
      _cachedBold = pw.Font.ttf(boldData);
    }
    final pw.Font notoRegular = _cachedRegular!;
    final pw.Font notoBold    = _cachedBold!;

    final pw.Document pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: notoRegular,
        bold: notoBold,
        italic: notoRegular,
      ),
    );

    final Sale sale = widget.sale;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        theme: pw.ThemeData.withFont(
          base: notoRegular,
          bold: notoBold,
        ),
        build: (pw.Context context) {

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── STORE NAME ──
              pw.Center(
                child: pw.Text(
                  'DeeGee Kickz',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 2),

              pw.Center(
                child: pw.Text(
                  'Official Sales Receipt',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 12),

              // ── DIVIDER ──
              pw.Divider(),

              pw.SizedBox(height: 8),

              // ── ORDER INFO ──
              _pdfRow('Order No.', sale.orderNumber),
              pw.SizedBox(height: 4),
              _pdfRow('Date', _formatDate(sale.transactionDate)),
              pw.SizedBox(height: 4),
              _pdfRow('Cashier', sale.cashierName),
              pw.SizedBox(height: 4),
              _pdfRow('Payment', sale.paymentMethodLabel),

              pw.SizedBox(height: 10),

              // ── DIVIDER ──
              pw.Divider(),

              pw.SizedBox(height: 8),

              // ── ITEMS HEADER ──
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Price',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // ── ITEMS ──
              for (SaleItem item in sale.items) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.productName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${item.color} · Size ${item.size}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          if (item.hasDiscount)
                            pw.Text(
                              'Discount applied',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.green700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (item.hasDiscount)
                            pw.Text(
                              _formatPrice(item.originalPrice),
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey500,
                                decoration: pw.TextDecoration.lineThrough,
                              ),
                            ),
                          pw.Text(
                            _formatPrice(item.retailPrice),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        _formatPrice(item.subtotal),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],

              pw.Divider(),
              pw.SizedBox(height: 6),

              // ── SUMMARY ──
              // Subtotal shown here is the sum of already-discounted
              // line totals (item.subtotal uses retailPrice). "You
              // saved" reflects the admin discount baked into those
              // prices — it's informational, not subtracted again.
              _pdfRow('Subtotal', _formatPrice(sale.subtotal)),

              if (sale.hasSavings) ...[
                pw.SizedBox(height: 4),
                _pdfRow(
                  'You saved',
                  _formatPrice(sale.totalSavings),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // total — bigger font
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _formatPrice(sale.total),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // cash breakdown — only for cash payment
              if (sale.paymentMethod == 'cash') ...[
                pw.SizedBox(height: 6),
                _pdfRow('Cash Paid', _formatPrice(sale.cashPaid)),
                pw.SizedBox(height: 4),
                _pdfRow('Change', _formatPrice(sale.change)),
              ],

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // ── THANK YOU ──
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping at DeeGee Kickz!',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  'Please keep this receipt for your records.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // ================================================
  // PDF ROW HELPER
  // label on left, value on right
  // ================================================
  pw.Widget _pdfRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // ================================================
  // HANDLE PRINT
  // opens system print dialog
  // ================================================
  Future<void> _handlePrint() async {
       setState(() => _isGenerating = true);
    // Forces Flutter to actually paint the "Generating..." state
    // before the CPU-heavy PDF work begins — without this explicit
    // yield, the setState and the heavy synchronous work can get
    // batched into the same frame, meaning the loading text never
    // visibly renders before the freeze starts.
    await Future.delayed(Duration.zero);

    try {
      final pw.Document pdf = await _generatePdf();();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Receipt_${widget.sale.orderNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to print receipt. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // ================================================
  // HANDLE SAVE AS PDF
  // opens save dialog for the user to pick location
  // ================================================
  Future<void> _handleSavePdf() async {
    setState(() => _isGenerating = true);

    try {
      final pw.Document pdf = await _generatePdf();
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Receipt_${widget.sale.orderNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save receipt. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    final Sale sale = widget.sale;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── FIXED HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Receipt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order ${sale.orderNumber}  ·  ${_formatDate(sale.transactionDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ── SCROLLABLE RECEIPT CONTENT ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── STORE INFO ──
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'DeeGee Kickz',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Official Sales Receipt',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ORDER INFO ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _buildReceiptRow('Order No.', sale.orderNumber),
                          const SizedBox(height: 6),
                          _buildReceiptRow(
                            'Date',
                            _formatDate(sale.transactionDate),
                          ),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Cashier', sale.cashierName),
                          const SizedBox(height: 6),
                          _buildReceiptRow(
                            'Payment',
                            sale.paymentMethodLabel,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ITEMS HEADER ──
                    Row(
                      children: const [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Item',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Price',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    const SizedBox(height: 8),

                    // ── ITEMS LIST ──
                    for (SaleItem item in sale.items) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.color} · Size ${item.size}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                if (item.hasDiscount)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Discount applied',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (item.hasDiscount)
                                  Text(
                                    _formatPrice(item.originalPrice),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  _formatPrice(item.retailPrice),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatPrice(item.subtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    const SizedBox(height: 10),

                    // ── SUMMARY ──
                    _buildReceiptRow(
                      'Subtotal',
                      _formatPrice(sale.subtotal),
                    ),

                    if (sale.hasSavings) ...[
                      const SizedBox(height: 6),
                      _buildReceiptRow(
                        'You saved',
                        _formatPrice(sale.totalSavings),
                        valueColor: const Color(0xFF16A34A),
                      ),
                    ],

                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    const SizedBox(height: 8),

                    // total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          _formatPrice(sale.total),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),

                    // cash breakdown
                    if (sale.paymentMethod == 'cash') ...[
                      const SizedBox(height: 8),
                      _buildReceiptRow(
                        'Cash Paid',
                        _formatPrice(sale.cashPaid),
                      ),
                      const SizedBox(height: 6),
                      _buildReceiptRow(
                        'Change',
                        _formatPrice(sale.change),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── THANK YOU ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Thank you for shopping at DeeGee Kickz!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Please keep this receipt for your records.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [

                  // close — does NOT cancel the sale
                  OutlinedButton(
                    onPressed: _isGenerating
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // save as pdf
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _handleSavePdf,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text(
                      'Save PDF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // print
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _handlePrint,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_outlined, size: 16),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Print',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
  // RECEIPT ROW HELPER
  // label left, value right
  // ================================================
  Widget _buildReceiptRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? const Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}