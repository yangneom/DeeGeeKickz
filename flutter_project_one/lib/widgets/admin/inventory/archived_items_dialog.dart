import 'package:flutter/material.dart';
import 'package:flutter_project_one/widgets/common/confirm_dialog.dart';

// ================================================
// FAKE ARCHIVED PRODUCT DATA
// ================================================

class ArchivedSizeRow {
  final String size;
  final int stockQty;
  final String status;
  final double costPrice;
  final double retailPrice;

  ArchivedSizeRow({
    required this.size,
    required this.stockQty,
    required this.status,
    required this.costPrice,
    required this.retailPrice,
  });
}

class ArchivedVariant {
  final String colorName;
  final List<ArchivedSizeRow> sizeRows;

  ArchivedVariant({
    required this.colorName,
    required this.sizeRows,
  });
}

class ArchivedProduct {
  final String productName;
  final String brand;
  final String category;
  final int totalStock;
  final double averagePrice;
  final String archivedDate;
  final List<ArchivedVariant> variants;

  ArchivedProduct({
    required this.productName,
    required this.brand,
    required this.category,
    required this.totalStock,
    required this.averagePrice,
    required this.archivedDate,
    required this.variants,
  });
}

final List<ArchivedProduct> fakeArchivedProducts = [
  ArchivedProduct(
    productName: 'Nike Panda',
    brand: 'Nike',
    category: 'Running-Shoes',
    totalStock: 8,
    averagePrice: 5500,
    archivedDate: '2025/03/02',
    variants: [
      ArchivedVariant(
        colorName: 'Pink',
        sizeRows: [
          ArchivedSizeRow(
            size: '8',
            stockQty: 6,
            status: 'Low Stock',
            costPrice: 5500,
            retailPrice: 2500,
          ),
        ],
      ),
    ],
  ),
  ArchivedProduct(
    productName: 'Nike Air Max 270 React Flyk b nit Men\'s Running Shoe',
    brand: 'Nike',
    category: 'Sneakers',
    totalStock: 8,
    averagePrice: 5500,
    archivedDate: '2025/03/10',
    variants: [
      ArchivedVariant(
        colorName: 'White',
        sizeRows: [
          ArchivedSizeRow(
            size: '9',
            stockQty: 4,
            status: 'Available',
            costPrice: 5500,
            retailPrice: 4500,
          ),
          ArchivedSizeRow(
            size: '10',
            stockQty: 0,
            status: 'Out of Stock',
            costPrice: 5500,
            retailPrice: 4500,
          ),
        ],
      ),
    ],
  ),
];

void showArchivedItemsDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const ArchivedItemsDialog();
    },
  );
}

class ArchivedItemsDialog extends StatefulWidget {
  const ArchivedItemsDialog({super.key});

  @override
  State<ArchivedItemsDialog> createState() => _ArchivedItemsDialogState();
}

class _ArchivedItemsDialogState extends State<ArchivedItemsDialog> {

  Map<int, bool> _expandedRows = {};

  bool _isExpanded(int index) => _expandedRows[index] ?? false;

  void _toggleExpanded(int index) {
    setState(() {
      _expandedRows[index] = !(_expandedRows[index] ?? false);
    });
  }

  Future<void> _handleRestore(ArchivedProduct product) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Restore this product in the inventory?',
      message:
          'This product will be moved back to active inventory '
          'and will be available for transactions.',
      confirmLabel: 'Restore Product',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} has been restored!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  // ================================================
  // FORMAT PRICE — copied from InventoryTable
  // ================================================
  String _formatPrice(double price) {
    int priceAsInt = price.toInt();
    String priceString = priceAsInt.toString();
    String result = '';
    int count = 0;
    for (int i = priceString.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = ',$result';
      result = priceString[i] + result;
      count++;
    }
    return result;
  }

  // ================================================
  // TEXT STYLES — copied from InventoryTable
  // ================================================
  TextStyle get _headerStyle => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
      );

  TextStyle get _bodyStyle => const TextStyle(
        fontSize: 13,
        color: Color(0xFF374151),
      );

  TextStyle get _variantHeaderStyle => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF9CA3AF),
      );

  // ================================================
  // STATUS BADGE — copied from InventoryTable
  // ================================================
  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (status == 'Available') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF86EFAC);
    } else if (status == 'Low Stock') {
      backgroundColor = const Color(0xFFFEF9C3);
      textColor = const Color(0xFFCA8A04);
      borderColor = const Color(0xFFFDE047);
    } else {
      backgroundColor = const Color(0xFFFFE4E6);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFCA5A5);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ================================================
  // HEADER ROW — same flex as InventoryTable
  // Added "Archived Date", replaced Actions with Restore
  // ================================================
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(flex: 4, child: Text('Product Name', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Brand', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Category', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Total Stock', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Average Price', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Archived Date', style: _headerStyle)),
          SizedBox(
            width: 90,
            child: Text('Actions', style: _headerStyle),
          ),
        ],
      ),
    );
  }

  // ================================================
  // PRODUCT ROW — same as InventoryTable
  // Added archivedDate, Restore button instead of 3-dot
  // ================================================
  Widget _buildProductRow(ArchivedProduct product, int productIndex) {
    bool isExpanded = _isExpanded(productIndex);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isExpanded ? const Color(0xFF2563EB) : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(productIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(flex: 2, child: Text(product.brand, style: _bodyStyle)),
                  Expanded(flex: 2, child: Text(product.category, style: _bodyStyle)),
                  Expanded(flex: 2, child: Text(product.totalStock.toString(), style: _bodyStyle)),
                  Expanded(flex: 2, child: Text(_formatPrice(product.averagePrice), style: _bodyStyle)),
                  Expanded(flex: 2, child: Text(product.archivedDate, style: _bodyStyle)),
                  SizedBox(
                    width: 90,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => _handleRestore(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Restore',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) _buildVariantSection(product),
        ],
      ),
    );
  }

  // ================================================
  // VARIANT SECTION — copied from InventoryTable
  // SizedBox(width: 90) aligns with Restore button
  // NOTE: No color + decoration on the same Container
  // ================================================
  Widget _buildVariantSection(ArchivedProduct product) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          // Variant header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(flex: 2, child: Text('Color', style: _variantHeaderStyle)),
                Expanded(flex: 1, child: Text('Size', style: _variantHeaderStyle)),
                Expanded(flex: 2, child: Text('Stock Qty', style: _variantHeaderStyle)),
                Expanded(flex: 3, child: Text('Status', style: _variantHeaderStyle)),
                Expanded(flex: 2, child: Text('Cost Price', style: _variantHeaderStyle)),
                Expanded(flex: 2, child: Text('Retail Price', style: _variantHeaderStyle)),
                const SizedBox(width: 90),
              ],
            ),
          ),

          // Size rows — no color + decoration together (fixes the crash)
          ...product.variants.expand((variant) {
            return variant.sizeRows.map((sizeRow) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 28),
                    Expanded(flex: 2, child: Text(variant.colorName, style: _bodyStyle)),
                    Expanded(flex: 1, child: Text(sizeRow.size, style: _bodyStyle)),
                    Expanded(flex: 2, child: Text(sizeRow.stockQty.toString(), style: _bodyStyle)),
                    Expanded(flex: 3, child: _buildStatusBadge(sizeRow.status)),
                    Expanded(flex: 2, child: Text(_formatPrice(sizeRow.costPrice), style: _bodyStyle)),
                    Expanded(flex: 2, child: Text(_formatPrice(sizeRow.retailPrice), style: _bodyStyle)),
                    const SizedBox(width: 90),
                  ],
                ),
              );
            });
          }).toList(),
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenWidth < 1000 ? screenWidth * 0.90 : 900,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Archived Items',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View and restore previously archived products.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 16),
                  Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // Table — scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        _buildHeaderRow(),
                        ...List.generate(fakeArchivedProducts.length, (index) {
                          return _buildProductRow(
                            fakeArchivedProducts[index],
                            index,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Back button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
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
}