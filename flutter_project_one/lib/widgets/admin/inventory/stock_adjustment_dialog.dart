import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product.dart';

// ================================================
// SHOW DIALOG HELPER
// ================================================
void showStockAdjustmentDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) => const StockAdjustmentDialog(),
  );
}

// ================================================
// STOCK ADJUSTMENT DIALOG
// ================================================
class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key});

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  // ── Controllers ──────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // ── State ─────────────────────────────────────
  String? _selectedCategory;
  ProductVariant? _selectedVariant;
  Product? _selectedProduct;
  bool _isAddStock = true; // true = Add Stock, false = Remove Stock

  List<_FlatVariantRow> _filteredRows = [];

  @override
  void initState() {
    super.initState();
    _filteredRows = _buildAllRows();
    _quantityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sizeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────

  /// Flatten all products + variants into rows for the table
  List<_FlatVariantRow> _buildAllRows() {
    List<_FlatVariantRow> rows = [];
    for (final product in fakeProducts) {
      for (final variant in product.variants) {
        rows.add(_FlatVariantRow(product: product, variant: variant));
      }
    }
    return rows;
  }

  List<String> _getCategories() {
    final cats = <String>{};
    for (final p in fakeProducts) {
      cats.add(p.category);
    }
    return cats.toList();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final sizeQuery = _sizeController.text.toLowerCase();

    setState(() {
      _filteredRows = _buildAllRows().where((row) {
        final matchesSearch = query.isEmpty ||
            row.product.productName.toLowerCase().contains(query) ||
            row.product.brand.toLowerCase().contains(query);
        final matchesSize = sizeQuery.isEmpty ||
            row.variant.size.toString().contains(sizeQuery);
        final matchesCategory = _selectedCategory == null ||
            row.product.category == _selectedCategory;
        return matchesSearch && matchesSize && matchesCategory;
      }).toList();
    });
  }

  int get _currentStock => _selectedVariant?.stockQty ?? 0;

  int get _adjustmentQty {
    final parsed = int.tryParse(_quantityController.text);
    return (parsed != null && parsed > 0) ? parsed : 0;
  }

  int get _newStockPreview {
    if (_isAddStock) return _currentStock + _adjustmentQty;
    final result = _currentStock - _adjustmentQty;
    return result < 0 ? 0 : result;
  }

  void _saveAdjustment() {
    if (_selectedVariant == null) return;
    // TODO: wire up to your provider / service
    Navigator.of(context).pop();
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────
              const Text(
                'STOCK ADJUSTMENT',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 20),

              // ── Body Row ───────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LEFT: filters + table ─────────────
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilters(),
                          const SizedBox(height: 16),
                          Expanded(child: _buildTable()),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // ── RIGHT: selected variant + adjustment ──
                    SizedBox(
                      width: 260,
                      child: _buildRightPanel(),
                    ),
                  ],
                ),
              ),

              // ── Bottom buttons ─────────────────────────
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        _selectedVariant != null ? _saveAdjustment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Adjustment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // FILTERS ROW
  // ================================================
  Widget _buildFilters() {
    final categories = _getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Product
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text(
                'Search Product :',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 180,
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration(''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Size
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text(
                'Search Size :',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                controller: _sizeController,
                onChanged: (_) => _applyFilters(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration(''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text(
                'Category :',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 180,
              height: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    hint: const Text(
                      'Select Category',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All',
                            style: TextStyle(fontSize: 12)),
                      ),
                      ...categories.map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c,
                                style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCategory = v);
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================
  // PRODUCT TABLE
  // ================================================
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 32),
                Expanded(
                    flex: 3,
                    child: Text('Product Name',
                        style: _headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Color', style: _headerStyle)),
                Expanded(
                    flex: 1,
                    child: Text('Size', style: _headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Stock Qty', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Rows
          Expanded(
            child: _filteredRows.isEmpty
                ? const Center(
                    child: Text('No products found.',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                  )
                : ListView.separated(
                    itemCount: _filteredRows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    itemBuilder: (context, index) {
                      final row = _filteredRows[index];
                      final isSelected = _selectedVariant == row.variant &&
                          _selectedProduct == row.product;
                      return _buildTableRow(row, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(_FlatVariantRow row, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedVariant = row.variant;
          _selectedProduct = row.product;
          _quantityController.clear();
        });
      },
      child: Container(
        color: isSelected
            ? const Color(0xFFEFF6FF)
            : Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) {
                  setState(() {
                    _selectedVariant = row.variant;
                    _selectedProduct = row.product;
                    _quantityController.clear();
                  });
                },
                activeColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3)),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
            Expanded(
                flex: 3,
                child: Text(row.product.productName,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF111827)))),
            Expanded(
                flex: 2,
                child: Text(row.variant.color,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)))),
            Expanded(
                flex: 1,
                child: Text(row.variant.size.toString(),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)))),
            Expanded(
                flex: 2,
                child: Text(row.variant.stockQty.toString(),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)))),
          ],
        ),
      ),
    );
  }

  // ================================================
  // RIGHT PANEL
  // ================================================
  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selected Variant ───────────────────────
        const Text(
          'Selected Variant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),

        if (_selectedVariant == null)
          const Text(
            'Select a product row to see details.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          )
        else ...[
          _infoRow('Product Name :', _selectedProduct!.productName),
          _infoRow('Color :', _selectedVariant!.color),
          _infoRow('Size :', _selectedVariant!.size.toString()),
          _infoRow(
              'Current Stock Quantity :', _currentStock.toString()),
        ],

        const SizedBox(height: 24),

        // ── Adjustment Type ────────────────────────
        const Text(
          'Adjustment Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        _buildRadio('Add Stock', true),
        const SizedBox(height: 6),
        _buildRadio('Remove Stock', false),

        const SizedBox(height: 20),

        // ── Quantity ──────────────────────────────
        Row(
          children: [
            const Text(
              'Quantity:',
              style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration(''),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── New Stock Preview ──────────────────────
        if (_selectedVariant != null)
          Row(
            children: [
              const Text(
                'New Stock Quantity Preview :',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _newStockPreview.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Small helpers ──────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(String label, bool isAdd) {
    final isSelected = _isAddStock == isAdd;
    return GestureDetector(
      onTap: () => setState(() => _isAddStock = isAdd),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : Colors.white,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.circle,
                        size: 6, color: Colors.white))
                : null,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151))),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      );
}

// ================================================
// INTERNAL FLAT ROW MODEL
// ================================================
class _FlatVariantRow {
  final Product product;
  final ProductVariant variant;
  const _FlatVariantRow({required this.product, required this.variant});
}

// ── Shared text style ──────────────────────────
const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Color(0xFF6B7280),
);