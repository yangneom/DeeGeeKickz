import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart';
import 'dart:typed_data';
import '../payment/payment_service.dart';

// ================================================
// RECEIPT PDF SERVICE
//
// Generates a customer order receipt as a PDF
// and uploads it to Supabase Storage (receipts/).
//
// Usage:
//   final String url =
//     await ReceiptPdfService().generateAndUpload(order);
//
// FONT NOTE: Helvetica (the pdf package's built-in base font) has no
// Unicode support, so the ₱ (U+20B1) glyph was silently dropped. We now
// load Noto Sans (Regular + Bold) from assets and use it as the base
// theme font, with the same fonts set as fontFallback so any other
// non-Latin-1 characters (e.g. accented names) also render instead of
// failing silently.
//
// Make sure these two lines exist in pubspec.yaml:
//   assets:
//     - assets/fonts/NotoSans-Regular.ttf
//     - assets/fonts/NotoSans-Bold.ttf
// ================================================

class ReceiptPdfService {
  final SupabaseClient _supabase      = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();

  // ================================================
  // GENERATE AND UPLOAD
  // Returns the public URL of the stored PDF.
  // Also persists receipt_url to the payment row.
  // ================================================
  Future<String> generateAndUpload(Order order) async {
    try {
      final pw.Document pdf   = await _buildPdf(order);
      final Uint8List bytes = Uint8List.fromList(await pdf.save());
      final String      path  = 'receipts/${order.orderId}.pdf';

      await _supabase.storage
          .from('receipts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert:      true,
            ),
          );

      final String receiptUrl = _supabase.storage
          .from('receipts')
          .getPublicUrl(path);

      await _paymentService.saveReceiptUrl(
        orderId:    int.parse(order.orderId),
        receiptUrl: receiptUrl,
      );

      return receiptUrl;
    } catch (e) {
      print('ReceiptPdfService.generateAndUpload error: $e');
      rethrow;
    }
  }

  // ================================================
  // BUILD PDF DOCUMENT
  // ================================================
  Future<pw.Document> _buildPdf(Order order) async {
    // Load the Unicode-capable fonts once per build.
    final ByteData regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ByteData boldData =
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final pw.Font notoRegular = pw.Font.ttf(regularData);
    final pw.Font notoBold    = pw.Font.ttf(boldData);

    final pw.Document pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base:   notoRegular,
        bold:   notoBold,
        italic: notoRegular,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 16,
          vertical:   20,
        ),
        theme: pw.ThemeData.withFont(
          base: notoRegular,
          bold: notoBold,
        ),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Center(
                child: pw.Text(
                  'DeeGee Kickz',
                  style: pw.TextStyle(
                    font:       notoBold,
                    fontSize:   18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Official Order Receipt',
                  style: pw.TextStyle(font: notoRegular, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),

              _row('Order No.', '#${order.orderId}', notoRegular),
              pw.SizedBox(height: 4),
              _row('Date',      order.dateTime, notoRegular),
              pw.SizedBox(height: 4),
              _row('Customer',  order.customerName, notoRegular),
              pw.SizedBox(height: 4),
              _row('Payment',   order.paymentMethod, notoRegular),
              pw.SizedBox(height: 4),
              _row('Status',    order.orderStatus, notoRegular),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Items header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        font:       notoBold,
                        fontSize:   10,
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
                        font:       notoBold,
                        fontSize:   10,
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
                        font:       notoBold,
                        fontSize:   10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // Items
              for (final OrderItem item in order.items) ...[
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
                              font:       notoBold,
                              fontSize:   10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${item.brand} · Size ${item.size}',
                            style: pw.TextStyle(font: notoRegular, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: notoRegular, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '₱${item.total.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: notoRegular, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],

              pw.Divider(),
              pw.SizedBox(height: 6),

              _row('Subtotal', '₱${order.totalAmount.toStringAsFixed(0)}', notoRegular),
              pw.SizedBox(height: 4),
              _row('Shipping', '₱80', notoRegular),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      font:       notoBold,
                      fontSize:   13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₱${(order.totalAmount + 80).toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      font:       notoBold,
                      fontSize:   13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Text(
                  'Thank you for shopping at DeeGee Kickz!',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: notoRegular, fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _row(String label, String value, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }
}