import 'package:flutter/material.dart';
import '../../models/product.dart';

// ================================================
// EXPANDABLE PRODUCT TABLE
//
// This is a reusable table for showing products
// with expandable rows that show variants inside.
//
// Used by:
//   - Inventory screen   (with 3-dot menu)
//   - Archived dialog    (with restore button)
//   - Cashier screen     (no action, view only)
//
// The action column is OPTIONAL!
// If actionBuilder is null = no action column shown
//
// How to use:
//
// // With action button:
// ExpandableProductTable(
//   products: myProducts,
//   actionBuilder: (Product product) {
//     return MyActionButton(product);
//   },
// )
//
// // Without action button (view only):
// ExpandableProductTable(
//   products: myProducts,
//   actionBuilder: null,
// )
// ================================================
class ExpandableProductTable extends StatefulWidget {

  // the list of products to show in the table
  final List<Product> products;

  // the action widget to show on each row
  // if null = no action column shown at all
  // if provided = shows action column with this widget
  final Widget Function(Product product)? actionBuilder;

  // ── NEW OPTIONAL PARAMS ──

  // extra column title
  // example: 'Archived Date'
  // if null = no extra column shown
  final String? extraHeaderLabel;

  // extra column value per product
  // example: (product) => product.archivedDate
  // if null = no extra column shown
  final String Function(Product product)? extraValueBuilder;

  const ExpandableProductTable({
    super.key,
    required this.products,
    this.actionBuilder,
    this.extraHeaderLabel,    // ← new
    this.extraValueBuilder,   // ← new
  });

  @override
  State<ExpandableProductTable> createState() {
    return _ExpandableProductTableState();
  }
}

class _ExpandableProductTableState extends State<ExpandableProductTable> {

  // ================================================
  // TRACKS WHICH ROWS ARE EXPANDED
  // Key = productId, Value = true or false
  // example: {'product_001': true, 'product_002': false}
  // ================================================
  Map<String, bool> _expandedRows = {};

  // ================================================
  // IS EXPANDED
  // checks if a product row is currently expanded
  // ================================================
  bool _isExpanded(String productId) {

    // if not in the map yet = not expanded = false
    bool isExpanded = _expandedRows[productId] ?? false;

    return isExpanded;
  }

  // ================================================
  // TOGGLE EXPANDED
  // opens a row if closed, closes if open
  // ================================================
  void _toggleExpanded(String productId) {

    setState(() {

      // get current state
      bool currentState = _expandedRows[productId] ?? false;

      // flip it to the opposite
      _expandedRows[productId] = !currentState;
    });
  }

  // ================================================
  // FORMAT PRICE
  // converts 5500.0 to "5,500"
  // ================================================
  String _formatPrice(double price) {

    // convert to int first to remove decimals
    int priceAsInt = price.toInt();

    // convert to string
    String priceString = priceAsInt.toString();

    // add commas every 3 digits from the right
    String result = '';
    int count = 0;

    for (int i = priceString.length - 1; i >= 0; i = i - 1) {

      // add comma every 3 digits
      if (count > 0 && count % 3 == 0) {
        result = ',' + result;
      }

      result = priceString[i] + result;
      count = count + 1;
    }

    return result;
  }

  // ================================================
  // BUILD STATUS BADGE
  // shows a colored badge based on status
  // Available = green
  // Low Stock = yellow
  // Out of Stock = red
  // ================================================
  Widget _buildStatusBadge(String status) {

    // default colors
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    // pick colors based on status
    if (status == 'Available') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF86EFAC);
    }

    if (status == 'Low Stock') {
      backgroundColor = const Color(0xFFFEF9C3);
      textColor = const Color(0xFFCA8A04);
      borderColor = const Color(0xFFFDE047);
    }

    if (status == 'Out of Stock') {
      backgroundColor = const Color(0xFFFFE4E6);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFCA5A5);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
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
  // TEXT STYLES
  // ================================================

  // header text style — gray and bold
  TextStyle get _headerStyle {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280),
    );
  }

  // body text style — dark gray
  TextStyle get _bodyStyle {
    return const TextStyle(
      fontSize: 13,
      color: Color(0xFF374151),
    );
  }

  // variant header text style — lighter gray
  TextStyle get _variantHeaderStyle {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF),
    );
  }

  // ================================================
  // BUILD HEADER ROW
  // ================================================
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [

          // space for the chevron icon
          const SizedBox(width: 28),

          // product name — biggest column
          Expanded(
            flex: 4,
            child: Text('Product Name', style: _headerStyle),
          ),

          // brand
          Expanded(
            flex: 2,
            child: Text('Brand', style: _headerStyle),
          ),

          // category
          Expanded(
            flex: 2,
            child: Text('Category', style: _headerStyle),
          ),

          // total stock
          Expanded(
            flex: 2,
            child: Text('Total Stock', style: _headerStyle),
          ),

          // average price
          Expanded(
            flex: 2,
            child: Text('Average Price', style: _headerStyle),
          ),

          // ── NEW — extra column header ──
          // only show if extraHeaderLabel is provided
          if (widget.extraHeaderLabel != null)
            Expanded(
              flex: 2,
              child: Text(
                widget.extraHeaderLabel!,
                style: _headerStyle,
              ),
            ),

          // action column — only show if actionBuilder is provided
          if (widget.actionBuilder != null)
            SizedBox(
              width: 80,
              child: Text('Actions', style: _headerStyle),
            ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD PRODUCT ROW
  // one row per product in the table
  // ================================================
  Widget _buildProductRow(Product product) {

    // check if this row is expanded
    bool isExpanded = _isExpanded(product.productId);

    return Container(
      decoration: BoxDecoration(
        border: Border(

          // blue left border when expanded
          // transparent when not expanded
          left: BorderSide(
            color: isExpanded == true
                ? const Color(0xFF2563EB)
                : Colors.transparent,
            width: 3,
          ),

          // bottom border always
          bottom: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [

          // ── CLICKABLE MAIN ROW ──
          // clicking this expands or collapses the row
          InkWell(
            onTap: () {
              _toggleExpanded(product.productId);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // chevron icon shows direction
                  SizedBox(
                    width: 28,
                    child: Icon(
                      isExpanded == true
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: const Color(0xFF6B7280),
                    ),
                  ),

                  // product name
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

                  // brand
                  Expanded(
                    flex: 2,
                    child: Text(product.brand, style: _bodyStyle),
                  ),

                  // category
                  Expanded(
                    flex: 2,
                    child: Text(product.category, style: _bodyStyle),
                  ),

                  // total stock
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.totalStock.toString(),
                      style: _bodyStyle,
                    ),
                  ),

                  // average price
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.averagePrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // ── NEW — extra column value ──
                  // only show if extraValueBuilder is provided
                  if (widget.extraValueBuilder != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.extraValueBuilder!(product),
                        style: _bodyStyle,
                      ),
                    ),

                  // action column — only show if actionBuilder is provided
                  if (widget.actionBuilder != null)
                    SizedBox(
                      width: 80,

                      // call actionBuilder to get the widget
                      // this is where the 3-dot menu or
                      // restore button will appear
                      child: widget.actionBuilder!(product),
                    ),
                ],
              ),
            ),
          ),

          // ── VARIANT SECTION ──
          // only shows when row is expanded
          if (isExpanded == true)
            _buildVariantSection(product),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SECTION
  // shows all variants of a product when expanded
  // ================================================
  Widget _buildVariantSection(Product product) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [

          // ── VARIANT HEADER ROW ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              children: [

                // indent to align with product name
                const SizedBox(width: 28),

                // color header
                Expanded(
                  flex: 2,
                  child: Text('Color', style: _variantHeaderStyle),
                ),

                // size header
                Expanded(
                  flex: 1,
                  child: Text('Size', style: _variantHeaderStyle),
                ),

                // stock qty header
                Expanded(
                  flex: 2,
                  child: Text('Stock Qty', style: _variantHeaderStyle),
                ),

                // status header
                Expanded(
                  flex: 3,
                  child: Text('Status', style: _variantHeaderStyle),
                ),

                // cost price header
                Expanded(
                  flex: 2,
                  child: Text('Cost Price', style: _variantHeaderStyle),
                ),

                // retail price header
                Expanded(
                  flex: 2,
                  child: Text('Retail Price', style: _variantHeaderStyle),
                ),

                // ── NEW — extra space to align with extra column ──
                if (widget.extraHeaderLabel != null)
                  const Expanded(
                    flex: 2,
                    child: SizedBox(),
                  ),

                // space to align with action column
                if (widget.actionBuilder != null)
                  const SizedBox(width: 80),
              ],
            ),
          ),

          // ── VARIANT DATA ROWS ──
          // one row per variant
          for (int i = 0; i < product.variants.length; i = i + 1)
            Container(
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

                  // indent
                  const SizedBox(width: 28),

                  // color value
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.variants[i].color,
                      style: _bodyStyle,
                    ),
                  ),

                  // size value
                  Expanded(
                    flex: 1,
                    child: Text(
                      product.variants[i].size,
                      style: _bodyStyle,
                    ),
                  ),

                  // stock qty value
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.variants[i].stockQty.toString(),
                      style: _bodyStyle,
                    ),
                  ),

                  // status badge
                  Expanded(
                    flex: 3,
                    child: _buildStatusBadge(
                      product.variants[i].status,
                    ),
                  ),

                  // cost price value
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.variants[i].costPrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // retail price value
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.variants[i].retailPrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // ── NEW — extra space to align with extra column ──
                  if (widget.extraValueBuilder != null)
                    const Expanded(
                      flex: 2,
                      child: SizedBox(),
                    ),

                  // space to align with action column
                  if (widget.actionBuilder != null)
                    const SizedBox(width: 80),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [

          // header row at the top
          _buildHeaderRow(),

          // one product row per product
          for (int i = 0; i < widget.products.length; i = i + 1)
            _buildProductRow(widget.products[i]),

          // show empty message if no products
          if (widget.products.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text(
                'No products found.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}