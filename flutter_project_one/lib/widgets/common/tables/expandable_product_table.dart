import 'package:flutter/material.dart';
import '../../../models/product.dart';

// ── Fixed-width table cell helpers ──
// The table used to use Expanded/flex columns, which squeezed
// everything to fit the screen (masikip) and clipped long product
// names. Now every column has a real fixed pixel width, the whole
// table scrolls horizontally when it doesn't fit, and Product Name
// / Color get a flexible-but-floored width so they grow when there's
// room and never shrink below a readable minimum.
class _Cell {
  final double width;
  final Widget child;
  const _Cell(this.width, this.child);
}

const double _kGap = 16;

double _rowWidth(List<double> widths) =>
    widths.fold(0.0, (a, b) => a + b) + _kGap * (widths.length - 1);

Widget _rowOf(List<_Cell> cells,
    {CrossAxisAlignment align = CrossAxisAlignment.start}) {
  final List<Widget> children = [];
  for (int i = 0; i < cells.length; i++) {
    children.add(SizedBox(width: cells[i].width, child: cells[i].child));
    if (i != cells.length - 1) {
      children.add(const SizedBox(width: _kGap));
    }
  }
  return Row(crossAxisAlignment: align, children: children);
}

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
//
// ── NOTE ON COLUMN ALIGNMENT ──
// The outer (product) row and inner (variant) row intentionally
// use different column sets — the inner row has 3 extra columns
// (Status, Cost Price, Retail Price) that the outer row doesn't.
// Because of that, "Reserved"/"Available" won't land at the exact
// same x-position in both rows — that's structural, not a bug.
// Each row's own header IS aligned with its own body (verified:
// same flex values, same order).
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

  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  // Every header/product/variant row wraps its Row in
  // EdgeInsets.symmetric(horizontal: 16) — that's 32px of padding
  // eaten on every row before the Row itself ever gets drawn. Any
  // width math has to account for it or the Row overflows.
  static const double _kRowHPad = 16;

  // ── Fixed column widths ──
  // Outer (product) row.
  static const double _wExpand = 28;
  static const double _wNameMin = 240; // floor — never squished below this
  static const double _wBrand = 110;
  static const double _wCategory = 140;
  static const double _wStock = 100;
  static const double _wReserved = 100; // same width used in inner table too
  static const double _wAvailable = 100; // same width used in inner table too
  static const double _wAvgPrice = 130;
  static const double _wExtra = 140;
  static const double _wActions = 80;

  // Inner (variant/size) row.
  static const double _wColorMin = 160; // floor — never squished below this
  static const double _wSize = 80;
  static const double _wInnerStock = 90;
  static const double _wStatus = 130;
  static const double _wCostPrice = 110;
  static const double _wRetailPrice = 110;

  bool get _hasExtra => widget.extraHeaderLabel != null;
  bool get _hasActions => widget.actionBuilder != null;

  // ── Width templates ──
  // These lists are the SAME order the Row cells are built in
  // (see _buildHeaderRow / _buildProductRow / _buildVariantSection).
  // Using one template for both "how wide is everything" and "how
  // many gaps are there" guarantees the two can never drift apart —
  // that mismatch (one missing gap) was the original overflow bug.
  List<double> _outerWidths(double nameWidth) => [
        _wExpand,
        nameWidth,
        _wBrand,
        _wCategory,
        _wStock,
        _wReserved,
        _wAvailable,
        _wAvgPrice,
        if (_hasExtra) _wExtra,
        if (_hasActions) _wActions,
      ];

  List<double> _innerWidths(double colorWidth) => [
        _wExpand,
        colorWidth,
        _wSize,
        _wInnerStock,
        _wReserved,
        _wAvailable,
        _wStatus,
        _wCostPrice,
        _wRetailPrice,
        if (_hasExtra) _wExtra,
        if (_hasActions) _wActions,
      ];

  // Sum of every OUTER/INNER column except the flexible one (passing
  // 0 keeps the cell COUNT — and therefore the gap count — correct).
  double get _outerFixedWidth => _rowWidth(_outerWidths(0));
  double get _innerFixedWidth => _rowWidth(_innerWidths(0));

  // Small safety margin. The outer Container's border and platform-level
  // rounding eat a couple of pixels that aren't part of the column math
  // itself. This also covers the 3px "active" left-accent border on each
  // product row (Border.left, width: 3) — Container.decoration silently
  // shrinks the child's available width by the border's thickness even
  // when its color is transparent, which the shared width math has no
  // visibility into. Keeping this buffer here (rather than special-casing
  // _outerFixedWidth) means it stays correct for header/variant rows too.
  static const double _kSafetyBuffer = 9; // was 6 — +3 for the left accent border

  // The space actually available INSIDE a row, after the 32px of
  // horizontal padding every row wraps itself in.
  double _contentWidth(double viewportWidth) {
    final double available =
        viewportWidth - (_kRowHPad * 2) - _kSafetyBuffer;
    final double outerMin = _outerFixedWidth + _wNameMin;
    final double innerMin = _innerFixedWidth + _wColorMin;
    final double minNeeded = outerMin > innerMin ? outerMin : innerMin;
    return available > minNeeded ? available : minNeeded;
  }

  // The full width to give the outer SizedBox (content width + the
  // padding every row adds back on top of it).
  double _tableWidth(double viewportWidth) =>
      _contentWidth(viewportWidth) + (_kRowHPad * 2);

  double _nameWidth(double contentWidth) => contentWidth - _outerFixedWidth;
  double _colorWidth(double contentWidth) => contentWidth - _innerFixedWidth;

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  bool _isExpanded(String productId) =>
      _expandedRows[productId] ?? false;

  void _toggleExpanded(String productId) {
    setState(() {
      _expandedRows[productId] =
          !(_expandedRows[productId] ?? false);
    });
  }

  // ── Aggregate reserved/available across every variant+size ──
  int _totalReserved(Product product) {
    int total = 0;
    for (final ProductVariant variant in product.variants) {
      for (final SizeEntry size in variant.sizes) {
        total += size.reservedQty;
      }
    }
    return total;
  }

  int _totalAvailable(Product product) {
    int total = 0;
    for (final ProductVariant variant in product.variants) {
      for (final SizeEntry size in variant.sizes) {
        total += size.availableQty;
      }
    }
    return total;
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
  // ── Does this product have AR try-on set up? ──
  // True if ANY variant has an ar_effect_url.
  bool _hasArEffect(Product product) {
    return product.variants.any((v) => v.arEffectUrl != null);
  }

  // ── AR badge — small pill shown next to product name ──
  Widget _buildArBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar, size: 12, color: Color(0xFF7C3AED)),
          SizedBox(width: 3),
          Text(
            'AR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
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

  // Available is the "can I sell this" number — the one admins act
  // on — so it gets more visual weight than Reserved (context only).
  TextStyle get _availableStyle => const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF111827));

  TextStyle get _reservedActiveStyle => const TextStyle(
      fontSize: 13,
      color: Color(0xFF92400E),
      fontWeight: FontWeight.w500);

  TextStyle get _reservedZeroStyle =>
      _bodyStyle.copyWith(color: const Color(0xFFD1D5DB));

  TextStyle get _variantHeaderStyle => const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF));

  // ── Reserved header label with info tooltip ──
  // Shared by outer + inner header rows so the explanation is
  // identical wherever "Reserved" appears.
  Widget _reservedHeaderLabel(TextStyle style) {
    return Tooltip(
      message:
          'Held for pending or unpaid orders. Not available to sell until released.',
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Reserved', style: style),
          const SizedBox(width: 4),
          Icon(Icons.info_outline,
              size: 13, color: style.color?.withOpacity(0.7)),
        ],
      ),
    );
  }

  // ── Header row ──
  Widget _buildHeaderRow(double contentWidth) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border:
            Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: _rowOf([
        _Cell(_wExpand, const SizedBox()),
        _Cell(_nameWidth(contentWidth),
            Text('Product Name', style: _headerStyle)),
        _Cell(_wBrand, Text('Brand', style: _headerStyle)),
        _Cell(_wCategory, Text('Category', style: _headerStyle)),
        _Cell(_wStock, Text('Total Stock', style: _headerStyle)),
        _Cell(_wReserved, _reservedHeaderLabel(_headerStyle)),
        _Cell(_wAvailable, Text('Available', style: _headerStyle)),
        _Cell(_wAvgPrice,
            Text('Average Price', style: _headerStyle)),
        if (_hasExtra)
          _Cell(_wExtra,
              Text(widget.extraHeaderLabel!, style: _headerStyle)),
        if (_hasActions)
          _Cell(_wActions, Text('Actions', style: _headerStyle)),
      ], align: CrossAxisAlignment.center),
    );
  }

  // ── Product row ──
  Widget _buildProductRow(Product product, double contentWidth) {
    final bool isExpanded = _isExpanded(product.productId);

    return Container(
      // foregroundDecoration (not decoration) — a Container automatically
      // turns a border's width into invisible padding around its child
      // when using `decoration`, even for a transparent-colored side.
      // That silently shrank this row's available width by 3px vs every
      // other row (header/variant sub-header have no such border), which
      // was the actual source of the "overflowed by 3.0 pixels" error.
      // foregroundDecoration paints on top instead, so it draws the same
      // accent stripe without affecting layout at all.
      foregroundDecoration: BoxDecoration(
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
              child: _rowOf([
                _Cell(
                  _wExpand,
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              
                                // No maxLines/ellipsis — with real horizontal room
                // and a scrollable table, a long name just wraps to
                // as many lines as it needs instead of disappearing.
                _Cell(
                  _nameWidth(contentWidth),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(product.productName,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF111827))),
                      ),
                      if (_hasArEffect(product)) _buildArBadge(),
                    ],
                  ),
                ),
                _Cell(_wBrand, Text(product.brand, style: _bodyStyle)),
                _Cell(_wCategory,
                    Text(product.category, style: _bodyStyle)),
                _Cell(_wStock,
                    Text(product.totalStock.toString(),
                        style: _bodyStyle)),
                _Cell(
                  _wReserved,
                  Builder(builder: (_) {
                    final int reserved = _totalReserved(product);
                    return Text(
                      reserved > 0 ? reserved.toString() : '—',
                      style: reserved > 0
                          ? _reservedActiveStyle
                          : _reservedZeroStyle,
                    );
                  }),
                ),
                _Cell(
                    _wAvailable,
                    Text(_totalAvailable(product).toString(),
                        style: _availableStyle)),
                _Cell(
                    _wAvgPrice,
                    Text(_formatPrice(product.averagePrice),
                        style: _bodyStyle)),
                if (widget.extraValueBuilder != null)
                  _Cell(_wExtra,
                      Text(widget.extraValueBuilder!(product),
                          style: _bodyStyle)),
                if (_hasActions)
                  _Cell(_wActions, widget.actionBuilder!(product)),
              ], align: CrossAxisAlignment.start),
            ),
          ),
          if (isExpanded) _buildVariantSection(product, contentWidth),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SECTION
  //
  // Iterates ProductVariant → SizeEntry.
  // Each SizeEntry becomes one table row.
  // Color is shown on the first size row of each variant
  // and left blank for subsequent sizes (grouping effect).
  // ================================================
  Widget _buildVariantSection(Product product, double contentWidth) {
    final double colorWidth = _colorWidth(contentWidth);

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
            child: _rowOf([
              _Cell(_wExpand, const SizedBox()),
              _Cell(colorWidth,
                  Text('Color', style: _variantHeaderStyle)),
              _Cell(_wSize, Text('Size', style: _variantHeaderStyle)),
              // "Stock" not "Stock Qty" — matches "Total Stock" above
              // so admins read it as the same concept, just per-size
              // instead of aggregated.
              _Cell(_wInnerStock,
                  Text('Stock', style: _variantHeaderStyle)),
              _Cell(_wReserved,
                  _reservedHeaderLabel(_variantHeaderStyle)),
              _Cell(_wAvailable,
                  Text('Available', style: _variantHeaderStyle)),
              _Cell(
                  _wStatus, Text('Status', style: _variantHeaderStyle)),
              _Cell(_wCostPrice,
                  Text('Cost Price', style: _variantHeaderStyle)),
              _Cell(_wRetailPrice,
                  Text('Retail Price', style: _variantHeaderStyle)),
              if (_hasExtra) _Cell(_wExtra, const SizedBox()),
              if (_hasActions) _Cell(_wActions, const SizedBox()),
            ], align: CrossAxisAlignment.center),
          ),

          // ── One row per SizeEntry per ProductVariant ──
          for (final ProductVariant variant in product.variants)
            for (int si = 0; si < variant.sizes.length; si++)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: _rowOf([
                  _Cell(_wExpand, const SizedBox()),

                                   // Color — shown only on first size row
                  _Cell(
                    colorWidth,
                    si == 0
                        ? Row(
                            children: [
                              Flexible(
                                child: Text(variant.color,
                                    style: _bodyStyle,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (variant.arEffectUrl != null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.view_in_ar,
                                    size: 13, color: Color(0xFF7C3AED)),
                              ],
                            ],
                          )
                        : const Text('', style: TextStyle(fontSize: 13)),
                  ),

                  // Size
                  _Cell(_wSize,
                      Text(variant.sizes[si].size, style: _bodyStyle)),

                  // Stock — raw stockQty (physical stock)
                  _Cell(
                      _wInnerStock,
                      Text(variant.sizes[si].stockQty.toString(),
                          style: _bodyStyle)),

                  // Reserved — de-emphasized when zero so rows with
                  // no active reservation don't visually compete
                  // with the ones that actually have one.
                  _Cell(
                    _wReserved,
                    Builder(builder: (_) {
                      final int reserved = variant.sizes[si].reservedQty;
                      return Text(
                        reserved > 0 ? reserved.toString() : '—',
                        style: reserved > 0
                            ? _reservedActiveStyle
                            : _reservedZeroStyle,
                      );
                    }),
                  ),

                  // Available — stock minus reserved, the number that
                  // actually answers "can I sell this now"
                  _Cell(
                      _wAvailable,
                      Text(variant.sizes[si].availableQty.toString(),
                          style: _availableStyle)),

                  // Status badge
                  _Cell(
                      _wStatus,
                      _buildStatusBadge(
                          _resolveStatus(variant.sizes[si]))),

                  // Cost price (on variant, same for all sizes)
                  _Cell(
                      _wCostPrice,
                      Text(
                          si == 0
                              ? _formatPrice(variant.costPrice)
                              : '',
                          style: _bodyStyle)),

                  // Retail price
                  _Cell(
                      _wRetailPrice,
                      Text(
                          si == 0
                              ? _formatPrice(variant.retailPrice)
                              : '',
                          style: _bodyStyle)),

                  if (widget.extraValueBuilder != null)
                    _Cell(_wExtra, const SizedBox()),

                  if (_hasActions) _Cell(_wActions, const SizedBox()),
                ], align: CrossAxisAlignment.start),
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
      // LayoutBuilder gives us the real available width/height.
      // Width: columns use it fully when there's room, and the
      // content-width math now correctly subtracts row padding.
      // Height: if the parent bounds our height (e.g. wraps us in
      // Expanded, like the admin inventory screen does), we add our
      // OWN vertical scroll so rows never overflow that budget. If
      // the parent gives unbounded height (e.g. a page-level scroll,
      // like the cashier/archived screens may use), we skip the
      // internal vertical scroll entirely and behave exactly as
      // before — so this fix can't break those other screens.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(builder: (context, constraints) {
          final double contentWidth =
              _contentWidth(constraints.maxWidth);
          final double tableWidth = _tableWidth(constraints.maxWidth);

          final Widget tableBody = SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildHeaderRow(contentWidth),
                for (final product in widget.products)
                  _buildProductRow(product, contentWidth),
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

          final Widget horizontallyScrollable = Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (notif) => notif.depth == 0,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              child: tableBody,
            ),
          );

          if (!constraints.hasBoundedHeight) {
            return horizontallyScrollable;
          }

          return Scrollbar(
            controller: _vScroll,
            thumbVisibility: true,
            notificationPredicate: (notif) => notif.depth == 0,
            child: SingleChildScrollView(
              controller: _vScroll,
              scrollDirection: Axis.vertical,
              child: horizontallyScrollable,
            ),
          );
        }),
      ),
    );
  }
}