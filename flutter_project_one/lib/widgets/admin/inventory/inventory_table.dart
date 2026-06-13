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

  // ================================================
  // TRACKS WHICH ROWS ARE EXPANDED
  // Key = productId, Value = true or false
  // ================================================
  Map<String, bool> _expandedRows = {};

  // ================================================
  // TRACKS WHICH PRODUCT'S MENU IS OPEN
  // null = no menu open
  // ================================================
  String? _activeMenuProductId;

  // ================================================
  // THE FLOATING DROPDOWN MENU
  // ================================================
  OverlayEntry? _overlayEntry;

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
    _closeMenu();
    setState(() {
      bool currentState = _expandedRows[productId] ?? false;
      _expandedRows[productId] = !currentState;
    });
  }

  // ================================================
  // SHOW MENU
  // ================================================
  void _showMenu(BuildContext context, Product product) {
    _closeMenu();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            _closeMenu();
          },
          child: Stack(
            children: [
              Positioned(
                top: position.dy + 28,
                left: position.dx - 120,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
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

                        _buildMenuItem(
                          icon: Icons.edit_outlined,
                          label: 'Edit & View',
                          onTap: () {
                            _closeMenu();
                            print('Edit: ${product.productName}');
                          },
                        ),

                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        _buildMenuItem(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          onTap: () {
                            _closeMenu();
                            print('Archive: ${product.productName}');
                          },
                        ),

                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        _buildMenuItem(
                          icon: Icons.add_circle_outline,
                          label: 'Add Variant',
                          onTap: () {
                            _closeMenu();
                            print('Add Variant: ${product.productName}');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _activeMenuProductId = product.productId;
    });
  }

  // ================================================
  // CLOSE MENU
  // ================================================
  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _activeMenuProductId = null;
      });
    }
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  // ================================================
  // BUILD MENU ITEM
  // ================================================
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD STATUS BADGE
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
  // FORMAT PRICE — 5500.0 becomes "5,500"
  // ================================================
  String _formatPrice(double price) {
    int priceAsInt = price.toInt();
    String priceString = priceAsInt.toString();
    String result = '';
    int count = 0;
    for (int i = priceString.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = priceString[i] + result;
      count++;
    }
    return result;
  }

  // ================================================
  // HEADER TEXT STYLE
  // ================================================
  TextStyle get _headerStyle {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280),
    );
  }

  // ================================================
  // BODY TEXT STYLE
  // ================================================
  TextStyle get _bodyStyle {
    return const TextStyle(
      fontSize: 13,
      color: Color(0xFF374151),
    );
  }

  // ================================================
  // VARIANT HEADER STYLE
  // ================================================
  TextStyle get _variantHeaderStyle {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF),
    );
  }

  // ================================================
  // BUILD HEADER ROW
  // Uses Expanded so columns fill available width
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

          // Space for the chevron icon
          const SizedBox(width: 28),

          // Product Name — biggest column
          Expanded(
            flex: 4,
            child: Text('Product Name', style: _headerStyle),
          ),

          // Brand
          Expanded(
            flex: 2,
            child: Text('Brand', style: _headerStyle),
          ),

          // Category
          Expanded(
            flex: 2,
            child: Text('Category', style: _headerStyle),
          ),

          // Total Stock
          Expanded(
            flex: 2,
            child: Text('Total Stock', style: _headerStyle),
          ),

          // Average Price
          Expanded(
            flex: 2,
            child: Text('Average Price', style: _headerStyle),
          ),

          // Actions — fixed small width
          SizedBox(
            width: 60,
            child: Text('Actions', style: _headerStyle),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD PRODUCT ROW
  // Uses same Expanded flex as header so they align
  // ================================================
  Widget _buildProductRow(Product product) {
    bool isExpanded = _isExpanded(product.productId);
    bool isMenuOpen = _activeMenuProductId == product.productId;

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

          // Clickable main row
          InkWell(
            onTap: () {
              _toggleExpanded(product.productId);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // Chevron icon
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

                  // Product Name
                  // maxLines: 2 means the row height grows
                  // naturally for long product names
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

                  // Brand
                  Expanded(
                    flex: 2,
                    child: Text(product.brand, style: _bodyStyle),
                  ),

                  // Category
                  Expanded(
                    flex: 2,
                    child: Text(product.category, style: _bodyStyle),
                  ),

                  // Total Stock
                  Expanded(
                    flex: 2,
                    child: Text(
                      product.totalStock.toString(),
                      style: _bodyStyle,
                    ),
                  ),

                  // Average Price
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatPrice(product.averagePrice),
                      style: _bodyStyle,
                    ),
                  ),

                  // 3-dot menu button
                  SizedBox(
                    width: 60,
                    child: Builder(
                      builder: (BuildContext buttonContext) {
                        return GestureDetector(
                          onTap: () {
                            if (isMenuOpen) {
                              _closeMenu();
                            } else {
                              _showMenu(buttonContext, product);
                            }
                          },
                          child: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: isMenuOpen
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6B7280),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Variant section — only shows when expanded
          if (isExpanded == true)
            _buildVariantSection(product),
        ],
      ),
    );
  }

  // ================================================
  // BUILD VARIANT SECTION
  // Uses same total width as product row
  // Variant columns share the same space
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

          // Variant header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [

                // Indent to align with product name
                const SizedBox(width: 28),

                // Color
                Expanded(
                  flex: 2,
                  child: Text('Color', style: _variantHeaderStyle),
                ),

                // Size
                Expanded(
                  flex: 1,
                  child: Text('Size', style: _variantHeaderStyle),
                ),

                // Stock Qty
                Expanded(
                  flex: 2,
                  child: Text('Stock Qty', style: _variantHeaderStyle),
                ),

                // Status
                Expanded(
                  flex: 3,
                  child: Text('Status', style: _variantHeaderStyle),
                ),

                // Cost Price
                Expanded(
                  flex: 2,
                  child: Text('Cost Price', style: _variantHeaderStyle),
                ),

                // Retail Price
                Expanded(
                  flex: 2,
                  child: Text('Retail Price', style: _variantHeaderStyle),
                ),

                // Space to align with actions column
                const SizedBox(width: 60),
              ],
            ),
          ),

          ...product.variants.expand((variant) {
                return variant.sizes.map((size) {
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
                      children: [

                        const SizedBox(width: 28),

                        Expanded(
                          flex: 2,
                          child: Text(
                            variant.color,
                            style: _bodyStyle,
                          ),
                        ),

                        Expanded(
                          flex: 1,
                          child: Text(
                            size.size,
                            style: _bodyStyle,
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text(
                            size.stockQty.toString(),
                            style: _bodyStyle,
                          ),
                        ),

                        Expanded(
                          flex: 3,
                          child: _buildStatusBadge(size.status),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatPrice(variant.costPrice),
                            style: _bodyStyle,
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatPrice(variant.retailPrice),
                            style: _bodyStyle,
                          ),
                        ),

                        const SizedBox(width: 60),
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
    return GestureDetector(
      onTap: () {
        _closeMenu();
      },
      child: Container(
        // Fill the full width of the parent
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

            // Header row
            _buildHeaderRow(),

            // Product rows
            ...widget.products.map((Product product) {
              return _buildProductRow(product);
            }).toList(),

            // No legend — status badges only appear in variant rows
          ],
        ),
      ),
    );
  }
}