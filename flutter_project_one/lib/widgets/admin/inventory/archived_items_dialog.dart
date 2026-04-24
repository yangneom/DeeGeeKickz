// Basic Flutter import
import 'package:flutter/material.dart';

// ================================================
// FAKE ARCHIVED PRODUCT DATA
//
// This is temporary fake data so we can see
// the archived items on screen.
// Later you will replace this with real Firestore data.
// ================================================

// This class holds data for ONE size row inside a variant
class ArchivedSizeRow {
  // The shoe size (example: "8", "9", "10")
  final String size;

  // How many pieces are in stock
  final int stockQty;

  // The status of this size (Available, Low Stock, Out of Stock)
  final String status;

  // The cost price (how much the store paid)
  final double costPrice;

  // The retail price (how much the customer pays)
  final double retailPrice;

  // Constructor — sets all the values above
  ArchivedSizeRow({
    required this.size,
    required this.stockQty,
    required this.status,
    required this.costPrice,
    required this.retailPrice,
  });
}

// This class holds data for ONE variant inside a product
// A variant = one color of the shoe
class ArchivedVariant {
  // The color name (example: "Pink", "White", "Black")
  final String colorName;

  // The list of size rows for this color
  final List<ArchivedSizeRow> sizeRows;

  // Constructor
  ArchivedVariant({
    required this.colorName,
    required this.sizeRows,
  });
}

// This class holds data for ONE archived product
class ArchivedProduct {
  // The product name (example: "Nike Panda")
  final String productName;

  // The brand name (example: "Nike")
  final String brand;

  // The category (example: "Running-Shoes")
  final String category;

  // How many total pieces are in stock across all variants
  final int totalStock;

  // The average price shown in the table
  final double averagePrice;

  // The date this product was archived
  final String archivedDate;

  // The list of variants (colors) for this product
  final List<ArchivedVariant> variants;

  // Constructor
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

// ================================================
// FAKE DATA LIST
//
// This is a list of fake archived products.
// We use this so we can see something on screen.
// ================================================
final List<ArchivedProduct> fakeArchivedProducts = [
  // First archived product
  ArchivedProduct(
    productName: 'Nike Panda',
    brand: 'Nike',
    category: 'Running-Shoes',
    totalStock: 8,
    averagePrice: 5500,
    archivedDate: '2025/03/02',
    variants: [
      // Pink color variant
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

  // Second archived product
  ArchivedProduct(
    productName: 'Nike Air Max 270 React Flyk b nit Men\'s Running Shoe',
    brand: 'Nike',
    category: 'Sneakers',
    totalStock: 8,
    averagePrice: 5500,
    archivedDate: '2025/03/10',
    variants: [
      // White color variant
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

// ================================================
// HOW TO USE THIS DIALOG
//
// Call this function from your inventory screen
// when the admin clicks the "Archived" button:
//
//   showArchivedItemsDialog(context);
//
// ================================================
void showArchivedItemsDialog(BuildContext context) {
  showDialog(
    context: context,
    // barrierDismissible = false means clicking outside
    // will NOT close the dialog
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const ArchivedItemsDialog();
    },
  );
}

// ================================================
// ARCHIVED ITEMS DIALOG WIDGET
//
// This is the main popup widget.
// It shows the list of archived products in a table.
// ================================================
class ArchivedItemsDialog extends StatefulWidget {
  const ArchivedItemsDialog({super.key});

  @override
  State<ArchivedItemsDialog> createState() => _ArchivedItemsDialogState();
}

class _ArchivedItemsDialogState extends State<ArchivedItemsDialog> {

  // ================================================
  // EXPANDED ROWS
  //
  // This list keeps track of which product rows
  // are currently expanded (showing their variants).
  //
  // Example:
  //   _expandedRows[0] = true  → first product is expanded
  //   _expandedRows[1] = false → second product is collapsed
  // ================================================
  List<bool> _expandedRows = [];

  // ================================================
  // INIT STATE
  //
  // This runs once when the dialog first opens.
  // We set all rows to collapsed (false) by default.
  // ================================================
  @override
  void initState() {
    super.initState();

    // Create a list of false values
    // One false for each archived product
    _expandedRows = List.generate(
      fakeArchivedProducts.length,
      (int index) => false,
    );
  }

  // ================================================
  // TOGGLE ROW
  //
  // This flips the expanded state of a row.
  // If it was open, it closes. If closed, it opens.
  // ================================================
  void _toggleRow(int index) {
    setState(() {
      // Flip the boolean value at this index
      _expandedRows[index] = !_expandedRows[index];
    });
  }

  // ================================================
  // HANDLE RESTORE
  //
  // Called when admin taps the "Restore" button
  // on a product row.
  //
  // For now it just shows a success message.
  // Later you will add Firestore logic here.
  // ================================================
  void _handleRestore(ArchivedProduct product) {
    // Close the dialog first
    Navigator.pop(context);

    // Show a green success snackbar at the bottom of the screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.productName} has been restored!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  // ================================================
  // BUILD STATUS BADGE
  //
  // Returns a small colored pill/badge widget
  // based on the status string.
  //
  // Green  = Available
  // Yellow = Low Stock
  // Red    = Out of Stock
  // ================================================
  Widget _buildStatusBadge(String status) {
    // Pick the background color based on status
    Color badgeColor;

    if (status == 'Available') {
      // Green for available
      badgeColor = const Color(0xFFDCFCE7);
    } else if (status == 'Low Stock') {
      // Yellow for low stock
      badgeColor = const Color(0xFFFEF9C3);
    } else {
      // Red/orange for out of stock
      badgeColor = const Color(0xFFFFEDD5);
    }

    // Pick the text color based on status
    Color textColor;

    if (status == 'Available') {
      textColor = const Color(0xFF16A34A);
    } else if (status == 'Low Stock') {
      textColor = const Color(0xFFCA8A04);
    } else {
      textColor = const Color(0xFFEA580C);
    }

    // Return the badge container
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ================================================
  // BUILD TABLE HEADER
  //
  // This is the top row of the table with
  // column labels like "Product Name", "Brand", etc.
  // ================================================
  Widget _buildTableHeader() {
    return Container(
      // Light grey background for the header row
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [

          // Empty space — same width as the expand arrow column
          const SizedBox(width: 32),

          // Product Name column — takes up the most space
          const Expanded(
            flex: 3,
            child: Text(
              'Product Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Brand column
          const Expanded(
            flex: 2,
            child: Text(
              'Brand',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Category column
          const Expanded(
            flex: 2,
            child: Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Total Stock column
          const Expanded(
            flex: 1,
            child: Text(
              'Total Stock',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Average Price column
          const Expanded(
            flex: 2,
            child: Text(
              'Average Price',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Archived Date column
          const Expanded(
            flex: 2,
            child: Text(
              'Archived Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),

          // Actions column
          const Expanded(
            flex: 2,
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SUB-HEADER
  //
  // This is the small grey header row that appears
  // under an expanded product row.
  // It shows: Color | Size | Stock Qty | Status |
  //           Cost Price | Retail Price
  // ================================================
  Widget _buildVariantSubHeader() {
    return Container(
      // Slightly darker grey for sub-header
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [

          // Indent to line up under product name
          const SizedBox(width: 32),

          // Color column
          const Expanded(
            flex: 2,
            child: Text(
              'Color',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Size column
          const Expanded(
            flex: 1,
            child: Text(
              'Size',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Stock Qty column
          const Expanded(
            flex: 2,
            child: Text(
              'Stock Qty',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Status column
          const Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Cost Price column
          const Expanded(
            flex: 2,
            child: Text(
              'Cost Price',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Retail Price column
          const Expanded(
            flex: 2,
            child: Text(
              'Retail Price',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SIZE ROW
  //
  // This builds ONE size row inside a variant.
  // Example: Pink | 8 | 6 | Low Stock | 5,500 | 2,500
  // ================================================
  Widget _buildVariantSizeRow(
    ArchivedVariant variant,
    ArchivedSizeRow sizeRow,
  ) {
    return Container(
      // White background
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      // Thin bottom border to separate rows
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: [

          // Indent (same as sub-header)
          const SizedBox(width: 32),

          // Color name
          Expanded(
            flex: 2,
            child: Text(
              variant.colorName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // Size number
          Expanded(
            flex: 1,
            child: Text(
              sizeRow.size,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // Stock quantity number
          Expanded(
            flex: 2,
            child: Text(
              sizeRow.stockQty.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // Status badge (colored pill)
          Expanded(
            flex: 2,
            child: _buildStatusBadge(sizeRow.status),
          ),

          // Cost price
          Expanded(
            flex: 2,
            child: Text(
              sizeRow.costPrice.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // Retail price
          Expanded(
            flex: 2,
            child: Text(
              sizeRow.retailPrice.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD PRODUCT ROW
  //
  // This builds ONE product row in the table.
  // It shows the product name, brand, category,
  // total stock, average price, archived date,
  // and a Restore button.
  //
  // If the row is expanded, it also shows the
  // variant sub-header and size rows below.
  // ================================================
  Widget _buildProductRow(ArchivedProduct product, int productIndex) {
    // Check if this product row is currently expanded
    bool isExpanded = _expandedRows[productIndex];

    return Column(
      children: [

        // ---- MAIN PRODUCT ROW ----
        Container(
          // White background + thin bottom border
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6)),
            ),
          ),
          child: Row(
            children: [

              // ---- EXPAND / COLLAPSE ARROW ----
              // Tapping this arrow shows or hides the variants
              GestureDetector(
                onTap: () {
                  _toggleRow(productIndex);
                },
                child: SizedBox(
                  width: 32,
                  child: Icon(
                    // If expanded show up arrow, if collapsed show down arrow
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),

              // ---- PRODUCT NAME ----
              Expanded(
                flex: 3,
                child: Text(
                  product.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
              ),

              // ---- BRAND ----
              Expanded(
                flex: 2,
                child: Text(
                  product.brand,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              // ---- CATEGORY ----
              Expanded(
                flex: 2,
                child: Text(
                  product.category,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              // ---- TOTAL STOCK ----
              Expanded(
                flex: 1,
                child: Text(
                  product.totalStock.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              // ---- AVERAGE PRICE ----
              Expanded(
                flex: 2,
                child: Text(
                  product.averagePrice.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              // ---- ARCHIVED DATE ----
              Expanded(
                flex: 2,
                child: Text(
                  product.archivedDate,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              // ---- RESTORE BUTTON ----
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    // Call the restore handler with this product
                    _handleRestore(product);
                  },
                  style: ElevatedButton.styleFrom(
                    // Green color for Restore
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // Shrink the button to fit its content
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Restore',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ---- EXPANDED CONTENT ----
        // This only shows if isExpanded is true
        if (isExpanded == true)
          Column(
            children: [

              // Show the sub-header row (Color, Size, Stock Qty, etc.)
              _buildVariantSubHeader(),

              // Loop through every variant in this product
              // A variant is one color (e.g., Pink, White)
              ...List.generate(product.variants.length, (int variantIndex) {
                // Get the current variant
                ArchivedVariant currentVariant = product.variants[variantIndex];

                // For each variant, loop through its size rows
                return Column(
                  children: List.generate(
                    currentVariant.sizeRows.length,
                    (int sizeRowIndex) {
                      // Get the current size row
                      ArchivedSizeRow currentSizeRow =
                          currentVariant.sizeRows[sizeRowIndex];

                      // Build and return the size row widget
                      return _buildVariantSizeRow(currentVariant, currentSizeRow);
                    },
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  // ================================================
  // BUILD
  //
  // The main build method.
  // Puts the header, table, and Back button together.
  // ================================================
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions so we can size the dialog
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      // Remove the default inset padding
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        // Width: 90% of screen width, max 900 pixels
        width: screenWidth < 1000 ? screenWidth * 0.90 : 900,

        // Height: 85% of screen height
        height: screenHeight * 0.85,

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),

        // Column layout: title at top, table in middle, button at bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================================================
            // TOP SECTION — Title and divider
            // This is NOT scrollable (always visible)
            // ================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Title
                  const Text(
                    'Archived Items',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider line under the title
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ================================================
            // TABLE AREA — scrollable
            // Expanded makes this fill all space between
            // the title and the Back button
            // ================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Container(
                  // Full width inside the padding
                  width: double.infinity,

                  // Border around the entire table
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),

                  // Clip so rounded corners are visible
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [

                        // Table header row
                        _buildTableHeader(),

                        // Loop through all archived products
                        // and build a row for each one
                        ...List.generate(
                          fakeArchivedProducts.length,
                          (int index) {
                            // Get the current product
                            ArchivedProduct currentProduct =
                                fakeArchivedProducts[index];

                            // Build the product row widget
                            return _buildProductRow(currentProduct, index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ================================================
            // BOTTOM SECTION — Back button
            // This is NOT scrollable (always visible)
            // ================================================
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              // Top border to separate from table area
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                // Align the Back button to the right
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  // Back button — closes the dialog
                  OutlinedButton(
                    onPressed: () {
                      // Pop (close) this dialog
                      Navigator.pop(context);
                    },
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