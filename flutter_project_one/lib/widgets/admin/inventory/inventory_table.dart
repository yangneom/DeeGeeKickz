import 'package:flutter/material.dart';
import '../../../models/product.dart';

class InventoryTable extends StatefulWidget {
  final List<Product> products;

  const InventoryTable({
    super.key,
    required this.products,
  });

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {

  Map<String, bool> _expandedRows = {};
  String? _activeMenuProductId;
  OverlayEntry? _overlayEntry;

  bool _isExpanded(String productId) => _expandedRows[productId] ?? false;

  void _toggleExpanded(String productId) {
    _closeMenuOverlay();
    setState(() {
      _expandedRows[productId] = !(_expandedRows[productId] ?? false);
    });
  }

  void _showMenuOverlay(BuildContext context, Product product) {
    _closeMenuOverlay();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeMenuOverlay,
        child: Stack(
          children: [
            Positioned(
              top: position.dy + 28,
              left: position.dx - 110,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                shadowColor: Colors.black.withOpacity(0.15),
                child: Container(
                  width: 148,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuItem(Icons.edit_outlined, 'Edit & View', () {
                        _closeMenuOverlay();
                        print('Edit: ${product.productName}');
                      }),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      _menuItem(Icons.archive_outlined, 'Archive', () {
                        _closeMenuOverlay();
                        print('Archive: ${product.productName}');
                      }),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      _menuItem(Icons.add_circle_outline, 'Add Variant', () {
                        _closeMenuOverlay();
                        print('Add Variant: ${product.productName}');
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _activeMenuProductId = product.productId);
  }

  void _closeMenuOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _activeMenuProductId = null);
  }

  @override
  void dispose() {
    _closeMenuOverlay();
    super.dispose();
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg, text, border;
    if (status == 'Available') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
      border = const Color(0xFF86EFAC);
    } else if (status == 'Low Stock') {
      bg = const Color(0xFFFEF9C3);
      text = const Color(0xFFCA8A04);
      border = const Color(0xFFFDE047);
    } else {
      bg = const Color(0xFFFFE4E6);
      text = const Color(0xFFDC2626);
      border = const Color(0xFFFCA5A5);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: text)),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(flex: 4, child: _headerCell('Product Name')),
          Expanded(flex: 2, child: _headerCell('Brand')),
          Expanded(flex: 2, child: _headerCell('Category')),
          Expanded(flex: 2, child: _headerCell('Total Stock')),
          Expanded(flex: 2, child: _headerCell('Average Price')),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _headerCell(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280)));
  }

  Widget _buildProductRow(Product product) {
    final bool expanded = _isExpanded(product.productId);
    final bool menuOpen = _activeMenuProductId == product.productId;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: expanded ? const Color(0xFF2563EB) : Colors.transparent,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Icon(
                      expanded
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
                          fontSize: 13, color: Color(0xFF111827)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(product.brand,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(product.category,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(product.totalStock.toString(),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_formatPrice(product.averagePrice),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  SizedBox(
                    width: 48,
                    child: Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          if (menuOpen) {
                            _closeMenuOverlay();
                          } else {
                            _showMenuOverlay(ctx, product);
                          }
                        },
                        child: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: menuOpen
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _buildVariantSection(product),
        ],
      ),
    );
  }

  Widget _buildVariantSection(Product product) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(flex: 3, child: _variantHeaderCell('Color')),
                Expanded(flex: 2, child: _variantHeaderCell('Size')),
                Expanded(flex: 2, child: _variantHeaderCell('Stock Qty')),
                Expanded(flex: 3, child: _variantHeaderCell('Status')),
                Expanded(flex: 3, child: _variantHeaderCell('Cost Price')),
                Expanded(flex: 3, child: _variantHeaderCell('Retail Price')),
                const SizedBox(width: 48),
              ],
            ),
          ),
          ...product.variants.map(
            (variant) => Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    flex: 3,
                    child: Text(variant.color,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(variant.size,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(variant.stockQty.toString(),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 3,
                    child: _statusBadge(variant.status),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_formatPrice(variant.costPrice),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_formatPrice(variant.retailPrice),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantHeaderCell(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF)));
  }

  String _formatPrice(double price) {
    int p = price.toInt();
    String s = p.toString();
    String result = '';
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = ',$result';
      result = s[i] + result;
      count++;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeMenuOverlay,
      child: Container(
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
            _buildHeader(),
            ...widget.products.map(_buildProductRow),
          ],
        ),
      ),
    );
  }
}