import 'package:flutter/material.dart';
import '../../../models/product.dart';

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
// ── MODEL SHAPE ──
//
// Product
//   └─ List<ProductVariant>       (one per color)
//         └─ List<SizeEntry>      (one per size row)
//
// The expanded variant section now shows one row per
// SizeEntry, grouped under its color variant.
//
// ── ROLE-AWARE STATUS ──
//
// showReserved: false (DEFAULT — admin + archived)
//   → uses SizeEntry.stockQty only
//   → statuses: Available / Low Stock / Out of Stock
//   → Reserved badge NEVER shown
//
// showReserved: true (CASHIER ONLY)
//   → uses SizeEntry.availableQty (stock minus reserved)
//   → statuses: Available / Low Stock / Out of Stock / Reserved
// ================================================
class ExpandableProductTable extends StatefulWidget {
  final List<Product> products;
  final Widget Function(Product product)? actionBuilder;
  final String? extraHeaderLabel;
  final String Function(Product product)? extraValueBuilder;
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
  State<ExpandableProductTable> createState() =>
      _ExpandableProductTableState();
}

class _ExpandableProductTableState
    extends State<ExpandableProductTable> {

  Map<String, bool> _expandedRows = {};

  bool _isExpanded(String productId) =>
      _expandedRows[productId] ?? false;

  void _toggleExpanded(String productId) {
    setState(() {
      _expandedRows[productId] =
          !(_expandedRows[productId] ?? false);
    });
  }

  // ── Format price ──
  String _formatPrice(double price) {
    String s = price.toInt().toString();
    String result = '';
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = ',$result';
      result = s[i] + result;
      count++;
    }
    return result;
  }

  // ================================================
  // RESOLVE STATUS FOR A SIZE ENTRY
  //
  // showReserved: false → admin / archived
  //   uses raw stockQty, never shows Reserved
  //
  // showReserved: true → cashier
  //   uses SizeEntry.status (based on availableQty)
  // ================================================
  String _resolveStatus(SizeEntry size) {
    if (widget.showReserved) return size.status;

    // Admin view — raw stock only
    if (size.stockQty == 0) return 'Out of Stock';
    if (size.stockQty <= 5) return 'Low Stock';
    return 'Available';
  }

  // ── Status badge ──
  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey;
    Color border = Colors.grey.shade300;

    if (status == 'Available') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFF86EFAC);
    } else if (status == 'Low Stock') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFCA8A04);
      border = const Color(0xFFFDE047);
    } else if (status == 'Out of Stock') {
      bg = const Color(0xFFFFE4E6);
      fg = const Color(0xFFDC2626);
      border = const Color(0xFFFCA5A5);
    } else if (status == 'Reserved') {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF6B7280);
      border = const Color(0xFFD1D5DB);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(status,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg)),
      ),
    );
  }

  // ── Text styles ──
  TextStyle get _headerStyle => const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280));

  TextStyle get _bodyStyle =>
      const TextStyle(fontSize: 13, color: Color(0xFF374151));

  TextStyle get _variantHeaderStyle => const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF));

  // ── Header row ──
  Widget _buildHeaderRow() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
              flex: 4,
              child: Text('Product Name', style: _headerStyle)),
          Expanded(
              flex: 2, child: Text('Brand', style: _headerStyle)),
          Expanded(
              flex: 2,
              child: Text('Category', style: _headerStyle)),
          Expanded(
              flex: 2,
              child: Text('Total Stock', style: _headerStyle)),
          Expanded(
              flex: 2,
              child: Text('Average Price', style: _headerStyle)),
          if (widget.extraHeaderLabel != null)
            Expanded(
                flex: 2,
                child: Text(widget.extraHeaderLabel!,
                    style: _headerStyle)),
          if (widget.actionBuilder != null)
            SizedBox(
                width: 80,
                child: Text('Actions', style: _headerStyle)),
        ],
      ),
    );
  }

  // ── Product row ──
  Widget _buildProductRow(Product product) {
    final bool isExpanded = _isExpanded(product.productId);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isExpanded
                ? const Color(0xFF2563EB)
                : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(product.productId),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
                    child: Text(product.productName,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF111827)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                      flex: 2,
                      child:
                          Text(product.brand, style: _bodyStyle)),
                  Expanded(
                      flex: 2,
                      child: Text(product.category,
                          style: _bodyStyle)),
                  Expanded(
                    flex: 2,
                    child: Text(product.totalStock.toString(),
                        style: _bodyStyle),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                        _formatPrice(product.averagePrice),
                        style: _bodyStyle),
                  ),
                  if (widget.extraValueBuilder != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                          widget.extraValueBuilder!(product),
                          style: _bodyStyle),
                    ),
                  if (widget.actionBuilder != null)
                    SizedBox(
                        width: 80,
                        child: widget.actionBuilder!(product)),
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
  // BUILD VARIANT SECTION
  //
  // Now iterates ProductVariant → SizeEntry.
  // Each SizeEntry becomes one table row.
  // Color is shown on the first size row of each variant
  // and left blank for subsequent sizes (grouping effect).
  // ================================================
  Widget _buildVariantSection(Product product) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border:
            Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [

          // ── Variant sub-header ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                    flex: 2,
                    child:
                        Text('Color', style: _variantHeaderStyle)),
                Expanded(
                    flex: 1,
                    child:
                        Text('Size', style: _variantHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Stock Qty',
                        style: _variantHeaderStyle)),
                Expanded(
                    flex: 3,
                    child: Text('Status',
                        style: _variantHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Cost Price',
                        style: _variantHeaderStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Retail Price',
                        style: _variantHeaderStyle)),
                if (widget.extraHeaderLabel != null)
                  const Expanded(flex: 2, child: SizedBox()),
                if (widget.actionBuilder != null)
                  const SizedBox(width: 80),
              ],
            ),
          ),

          // ── One row per SizeEntry per ProductVariant ──
          for (final ProductVariant variant in product.variants)
            for (int si = 0;
                si < variant.sizes.length;
                si++)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 28),

                    // Color — shown only on first size row
                    Expanded(
                      flex: 2,
                      child: Text(
                        si == 0 ? variant.color : '',
                        style: _bodyStyle,
                      ),
                    ),

                    // Size
                    Expanded(
                      flex: 1,
                      child: Text(
                          variant.sizes[si].size,
                          style: _bodyStyle),
                    ),

                    // Stock qty — raw stockQty (physical stock)
                    Expanded(
                      flex: 2,
                      child: Text(
                          variant.sizes[si].stockQty.toString(),
                          style: _bodyStyle),
                    ),

                    // Status badge
                    Expanded(
                      flex: 3,
                      child: _buildStatusBadge(
                          _resolveStatus(variant.sizes[si])),
                    ),

                    // Cost price (on variant, same for all sizes)
                    Expanded(
                      flex: 2,
                      child: Text(
                          si == 0
                              ? _formatPrice(variant.costPrice)
                              : '',
                          style: _bodyStyle),
                    ),

                    // Retail price
                    Expanded(
                      flex: 2,
                      child: Text(
                          si == 0
                              ? _formatPrice(variant.retailPrice)
                              : '',
                          style: _bodyStyle),
                    ),

                    if (widget.extraValueBuilder != null)
                      const Expanded(flex: 2, child: SizedBox()),

                    if (widget.actionBuilder != null)
                      const SizedBox(width: 80),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ── Build ──
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
          for (final product in widget.products)
            _buildProductRow(product),
          if (widget.products.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('No products found.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF))),
            ),
        ],
      ),
    );
  }
}