import 'package:flutter/material.dart';
import '../../models/product.dart';

// ================================================
// EXPANDABLE PRODUCT TABLE
//
// Reusable table for showing products with
// expandable rows that reveal variants inside.
//
// Used by:
//   - Admin inventory screen   → actionBuilder with 3-dot menu
//   - Archived items dialog    → actionBuilder with Restore button
//   - Cashier inventory screen → actionBuilder: null (view only)
//
// ── ROLE-AWARE STATUS ──
//
// showReserved controls what status the table shows:
//
//   showReserved: false (DEFAULT — admin + archived)
//     → uses stockQty only
//     → statuses: Available / Low Stock / Out of Stock
//     → Reserved badge NEVER shown
//
//   showReserved: true (CASHIER ONLY)
//     → uses availableQty (stock minus reserved)
//     → statuses: Available / Low Stock / Out of Stock / Reserved
//     → Reserved badge shown when variant is fully locked
//
// ── USAGE ──
//
// Admin inventory (default — no showReserved needed):
//   ExpandableProductTable(
//     products: products,
//     actionBuilder: (p) => MyActionWidget(p),
//   )
//
// Archived dialog (default — no showReserved needed):
//   ExpandableProductTable(
//     products: products,
//     extraHeaderLabel: 'Archived Date',
//     extraValueBuilder: (p) => p.archivedDate ?? '',
//     actionBuilder: (p) => RestoreButton(p),
//   )
//
// Cashier inventory (must pass showReserved: true):
//   ExpandableProductTable(
//     products: products,
//     actionBuilder: null,
//     showReserved: true,
//   )
// ================================================
class ExpandableProductTable extends StatefulWidget {

  // the list of products to show in the table
  final List<Product> products;

  // the action widget to show on each product row
  // if null → no action column shown at all
  final Widget Function(Product product)? actionBuilder;

  // extra column header label
  // example: 'Archived Date'
  // if null → no extra column shown
  final String? extraHeaderLabel;

  // extra column value per product
  // example: (product) => product.archivedDate ?? ''
  // if null → no extra column shown
  final String Function(Product product)? extraValueBuilder;

  // controls whether Reserved status is shown
  //
  // false (DEFAULT) → admin + archived view
  //   uses stockQty only — Reserved never shown
  //
  // true → cashier view only
  //   uses availableQty — Reserved shown when fully locked
  final bool showReserved;

  const ExpandableProductTable({
    super.key,
    required this.products,
    this.actionBuilder,
    this.extraHeaderLabel,
    this.extraValueBuilder,
    this.showReserved = false,
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
  // ================================================
  Map<String, bool> _expandedRows = {};

  // ================================================
  // IS EXPANDED
  // ================================================
  bool _isExpanded(String productId) {
    return _expandedRows[productId] ?? false;
  }

  // ================================================
  // TOGGLE EXPANDED
  // ================================================
  void _toggleExpanded(String productId) {
    setState(() {
      bool current = _expandedRows[productId] ?? false;
      _expandedRows[productId] = !current;
    });
  }

  // ================================================
  // FORMAT PRICE
  // converts 5500.0 → "5,500"
  // ================================================
  String _formatPrice(double price) {
    int priceAsInt = price.toInt();
    String priceString = priceAsInt.toString();
    String result = '';
    int count = 0;

    for (int i = priceString.length - 1; i >= 0; i = i - 1) {
      if (count > 0 && count % 3 == 0) {
        result = ',' + result;
      }
      result = priceString[i] + result;
      count = count + 1;
    }

    return result;
  }

  // ================================================
  // RESOLVE STATUS
  //
  // showReserved: false → admin / archived view
  //   ignores reservedQty entirely
  //   uses raw stockQty for status
  //   Reserved is NEVER returned
  //
  // showReserved: true → cashier view
  //   uses variant.status which is based on availableQty
  //   can return Reserved when fully locked
  // ================================================
  String _resolveStatus(ProductVariant variant) {

    // cashier view — use availableQty-based status from model
    // this can return Reserved, Low Stock, Out of Stock, Available
    if (widget.showReserved == true) {
      return variant.status;
    }

    // admin / archived view — use raw stockQty only
    // Reserved is completely ignored here
    if (variant.stockQty == 0) {
      return 'Out of Stock';
    }

    if (variant.stockQty <= 5) {
      return 'Low Stock';
    }

    return 'Available';
  }

  // ================================================
  // BUILD STATUS BADGE
  //
  // Available    → green
  // Low Stock    → yellow
  // Out of Stock → red
  // Reserved     → gray (cashier only — never shown to admin)
  // ================================================
  Widget _buildStatusBadge(String status) {

    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

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

    // Reserved — gray badge
    // only reachable when showReserved: true (cashier view)
    if (status == 'Reserved') {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      borderColor = const Color(0xFFD1D5DB);
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

  TextStyle get _headerStyle {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280),
    );
  }

  TextStyle get _bodyStyle {
    return const TextStyle(
      fontSize: 13,
      color: Color(0xFF374151),
    );
  }

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

          // space for chevron
          const SizedBox(width: 28),

          // product name
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

          // extra column — only if provided
          if (widget.extraHeaderLabel != null)
            Expanded(
              flex: 2,
              child: Text(
                widget.extraHeaderLabel!,
                style: _headerStyle,
              ),
            ),

          // action column — only if actionBuilder provided
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
  // ================================================
  Widget _buildProductRow(Product product) {

    bool isExpanded = _isExpanded(product.productId);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isExpanded == true
                ? const Color(0xFF2563EB)
                : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [

          // clickable main row
          InkWell(
            onTap: () => _toggleExpanded(product.productId),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // chevron
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

                  // total stock — always uses stockQty (physical stock)
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

                  // extra column value — only if provided
                  if (widget.extraValueBuilder != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.extraValueBuilder!(product),
                        style: _bodyStyle,
                      ),
                    ),

                  // action column — only if actionBuilder provided
                  if (widget.actionBuilder != null)
                    SizedBox(
                      width: 80,
                      child: widget.actionBuilder!(product),
                    ),
                ],
              ),
            ),
          ),

          // variant section — only when expanded
          if (isExpanded == true)
            _buildVariantSection(product),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SECTION
  // shows all variants when a product row is expanded
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

                // indent
                const SizedBox(width: 28),

                Expanded(
                  flex: 2,
                  child: Text('Color', style: _variantHeaderStyle),
                ),

                Expanded(
                  flex: 1,
                  child: Text('Size', style: _variantHeaderStyle),
                ),

                Expanded(
                  flex: 2,
                  child: Text('Stock Qty', style: _variantHeaderStyle),
                ),

                Expanded(
                  flex: 3,
                  child: Text('Status', style: _variantHeaderStyle),
                ),

                Expanded(
                  flex: 2,
                  child: Text('Cost Price', style: _variantHeaderStyle),
                ),

                Expanded(
                  flex: 2,
                  child: Text('Retail Price', style: _variantHeaderStyle),
                ),

                // spacer for extra column alignment
                if (widget.extraHeaderLabel != null)
                  const Expanded(
                    flex: 2,
                    child: SizedBox(),
                  ),

                // spacer for action column alignment
                if (widget.actionBuilder != null)
                  const SizedBox(width: 80),
              ],
            ),
          ),

          // ── VARIANT DATA ROWS ──
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

                  // color
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.variants[i].color,
                      style: _bodyStyle,
                    ),
                  ),

                  // size
                  Expanded(
                    flex: 1,
                    child: Text(
                      product.variants[i].size,
                      style: _bodyStyle,
                    ),
                  ),

                  // stock qty — always shows raw stockQty
                  // never availableQty — that's cashier-only logic
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.variants[i].stockQty.toString(),
                      style: _bodyStyle,
                    ),
                  ),

                  // status badge
                  // _resolveStatus decides what to show
                  // based on showReserved flag
                  Expanded(
                    flex: 3,
                    child: _buildStatusBadge(
                      _resolveStatus(product.variants[i]),
                    ),
                  ),

                  // cost price
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.variants[i].costPrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // retail price
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.variants[i].retailPrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // spacer for extra column alignment
                  if (widget.extraValueBuilder != null)
                    const Expanded(
                      flex: 2,
                      child: SizedBox(),
                    ),

                  // spacer for action column alignment
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

          _buildHeaderRow(),

          for (int i = 0; i < widget.products.length; i = i + 1)
            _buildProductRow(widget.products[i]),

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