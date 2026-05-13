import 'package:flutter/material.dart';
import 'package:flutter_project_one/widgets/common/confirm_dialog.dart';
import 'package:flutter_project_one/widgets/common/expandable_product_table.dart';
import 'package:flutter_project_one/models/product.dart';

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

  // ================================================
  // CONVERT ArchivedProduct LIST → Product LIST
  // so we can pass it to ExpandableProductTable
  // ================================================
  List<Product> _convertToProducts() {

    List<Product> result = [];

    for (int i = 0; i < fakeArchivedProducts.length; i = i + 1) {

      ArchivedProduct archived = fakeArchivedProducts[i];

      // flatten ArchivedVariant + ArchivedSizeRow → ProductVariant
      List<ProductVariant> variants = [];

      for (int j = 0; j < archived.variants.length; j = j + 1) {

        ArchivedVariant archivedVariant = archived.variants[j];

        for (int k = 0; k < archivedVariant.sizeRows.length; k = k + 1) {

          ArchivedSizeRow sizeRow = archivedVariant.sizeRows[k];

          variants.add(
            ProductVariant(
              color: archivedVariant.colorName,
              size: sizeRow.size,
              stockQty: sizeRow.stockQty,
              costPrice: sizeRow.costPrice,
              retailPrice: sizeRow.retailPrice,
            ),
          );
        }
      }

      // create Product with archivedDate attached
      result.add(
        Product(
          productId: 'archived_$i',
          productName: archived.productName,
          brand: archived.brand,
          category: archived.category,
          variants: variants,
          archivedDate: archived.archivedDate,
        ),
      );
    }

    return result;
  }

  // ================================================
  // HANDLE RESTORE
  // shows confirm dialog then pops and shows snackbar
  // ================================================
  Future<void> _handleRestore(Product product) async {

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

            // ── TITLE ──
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

            // ── TABLE ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: ExpandableProductTable(
                  products: _convertToProducts(),

                  // extra column — archived date
                  extraHeaderLabel: 'Archived Date',
                  extraValueBuilder: (Product product) {
                    return product.archivedDate ?? '';
                  },

                  // restore button as the action
                  actionBuilder: (Product product) {
                    return SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () {
                          _handleRestore(product);
                        },
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
                    );
                  },
                ),
              ),
            ),

            // ── BACK BUTTON ──
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