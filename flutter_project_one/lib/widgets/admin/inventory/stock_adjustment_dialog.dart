import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_project_one/widgets/common/dialog/confirm_dialog.dart';
import '../../../models/product.dart';
import '../../../services/admin/inventory/inventory_service.dart';
import '../../../services/admin/inventory/stock_service.dart';

// ================================================
// SHOW STOCK ADJUSTMENT DIALOG
//
// Returns `true` if a stock adjustment was saved successfully, so the
// caller (Inventory screen) can re-fetch and show updated stock
// counts — same pattern as showAddBannerDialog / showCreateDiscountDialog.
// Returns null/false if the admin cancelled without saving.
// ================================================
Future<bool?> showStockAdjustmentDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (BuildContext context) {
      return const StockAdjustmentDialog();
    },
  );
}

class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key});

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {

  // ================================================
  // SERVICES
  // ================================================
  final InventoryService _inventoryService = InventoryService();
  final StockService _stockService = StockService();

  // ================================================
  // WIZARD STEP
  // 1 = search/select a variant (full-width table)
  // 2 = focused adjustment view for the selected variant
  // ================================================
  int _step = 1;

  // ================================================
  // CONTROLLERS
  // ================================================
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // ================================================
  // STATE
  // ================================================
  List<Product> _allProducts = [];
  List<_FlatVariantRow> _filteredRows = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedCategory;
  Product? _selectedProduct;
  ProductVariant? _selectedVariant;
  SizeEntry? _selectedSize;
  bool _isAddStock = true;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _quantityController.addListener(() => setState(() {}));
  }

  // ================================================
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    _sizeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // ================================================
  // LOAD PRODUCTS FROM SUPABASE
  // ================================================
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    final List<Product> products = await _inventoryService.fetchProducts();

    setState(() {
      _allProducts = products;
      _isLoading = false;
      _filteredRows = _buildAllRows();
    });
  }

  // ================================================
  // BUILD ALL ROWS
  // ================================================
  List<_FlatVariantRow> _buildAllRows() {
    List<_FlatVariantRow> rows = [];

    for (int i = 0; i < _allProducts.length; i++) {
      Product product = _allProducts[i];

      for (int j = 0; j < product.variants.length; j++) {
        ProductVariant variant = product.variants[j];

        for (int k = 0; k < variant.sizes.length; k++) {
          SizeEntry size = variant.sizes[k];

          rows.add(
            _FlatVariantRow(
              product: product,
              variant: variant,
              size: size,
            ),
          );
        }
      }
    }

    return rows;
  }

  // ================================================
  // GET CATEGORIES
  // ================================================
  List<String> _getCategories() {
    Set<String> categorySet = {};
    for (int i = 0; i < _allProducts.length; i++) {
      categorySet.add(_allProducts[i].category);
    }
    return categorySet.toList();
  }

  // ================================================
  // APPLY FILTERS
  // ================================================
  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    String sizeQuery = _sizeController.text.toLowerCase();
    List<_FlatVariantRow> allRows = _buildAllRows();
    List<_FlatVariantRow> results = [];

    for (int i = 0; i < allRows.length; i++) {
      _FlatVariantRow row = allRows[i];

      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch = row.product.productName
            .toLowerCase()
            .contains(searchQuery);
        bool brandMatch =
            row.product.brand.toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || brandMatch;
      }

      bool matchesSize = true;
      if (sizeQuery.isNotEmpty) {
        matchesSize =
            row.size.size.toString().toLowerCase().contains(sizeQuery);
      }

      bool matchesCategory = true;
      if (_selectedCategory != null) {
        matchesCategory = row.product.category == _selectedCategory;
      }

      if (matchesSearch && matchesSize && matchesCategory) {
        results.add(row);
      }
    }

    setState(() {
      _filteredRows = results;
    });
  }

  // ================================================
  // HELPERS
  // ================================================
  int _getCurrentStock() {
    if (_selectedSize == null) return 0;
    return _selectedSize!.stockQty;
  }

  int _getAdjustmentQty() {
    int? parsed = int.tryParse(_quantityController.text);
    if (parsed != null && parsed > 0) return parsed;
    return 0;
  }

  int _getNewStockPreview() {
    int current = _getCurrentStock();
    int adjustment = _getAdjustmentQty();
    if (_isAddStock) {
      return current + adjustment;
    } else {
      int result = current - adjustment;
      return result < 0 ? 0 : result;
    }
  }

  // ================================================
  // STEP NAVIGATION
  // ================================================
  void _selectRow(_FlatVariantRow row) {
    setState(() {
      _selectedVariant = row.variant;
      _selectedProduct = row.product;
      _selectedSize = row.size;
    });
  }

  void _advanceToAdjust() {
    if (_selectedVariant == null || _selectedSize == null) return;
    setState(() {
      _quantityController.clear();
      _isAddStock = true;
      _step = 2;
    });
  }

  void _backToSelect() {
    setState(() {
      _step = 1;
      _quantityController.clear();
    });
  }

  // ================================================
  // SAVE ADJUSTMENT
  // ================================================
    Future<void> _saveAdjustment() async {
    if (_selectedVariant == null || _selectedSize == null) return;

    int qty = _getAdjustmentQty();
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a quantity greater than 0.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String action = _isAddStock ? 'Add' : 'Remove';
    int newStock = _getNewStockPreview();

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Save this stock adjustment?',
      message:
          '$action $qty unit(s) for '
          '${_selectedProduct!.productName} '
          '(${_selectedVariant!.color} / Size ${_selectedSize!.size}). '
          'New stock will be $newStock.',
      confirmLabel: 'Save Adjustment',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    final String? error = await _stockService.adjustStock(
      sizeId: _selectedSize!.sizeId!,
      adjustment: qty,
      isAddStock: _isAddStock,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stock adjustment saved successfully!'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  // ================================================
  // BUILD INPUT DECORATION
  // ================================================
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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
  // STEP 1 — FILTERS (single row now, was 3 stacked rows)
  // ================================================
  Widget _buildFilters() {
    List<String> categories = _getCategories();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search Product',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) => _applyFilters(),
                  style: const TextStyle(fontSize: 13),
                  decoration: _buildInputDecoration('e.g. Nike Air Max'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Size',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _sizeController,
                  onChanged: (String value) => _applyFilters(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 13),
                  decoration: _buildInputDecoration('e.g. 5'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              SizedBox(
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
                      hint: const Text('All',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All', style: TextStyle(fontSize: 12)),
                        ),
                        ...categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? value) {
                        setState(() => _selectedCategory = value);
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // STEP 1 — TABLE
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('Product Name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Color',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Size',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Stock Qty',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2),
                  )
                : _filteredRows.isEmpty
                    ? const Center(
                        child: Text('No products found.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      )
                    : ListView.separated(
                        itemCount: _filteredRows.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        itemBuilder: (BuildContext context, int index) {
                          _FlatVariantRow row = _filteredRows[index];
                          // FIX: previously only compared variant + product,
                          // which highlighted every size row sharing that
                          // color (e.g. sizes 9/10/11 all lit up together).
                          // Now compares the specific size row too.
                          bool isSelected = _selectedVariant == row.variant &&
                              _selectedProduct == row.product &&
                              _selectedSize == row.size;
                          return _buildTableRow(row, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // STEP 1 — TABLE ROW
  // Click-to-select — no checkbox (that implied multi-select, which
  // isn't actually possible here; only one variant can be adjusted
  // at a time).
  // ================================================
  Widget _buildTableRow(_FlatVariantRow row, bool isSelected) {
    return InkWell(
      onTap: () => _selectRow(row),
      onDoubleTap: () {
        _selectRow(row);
        _advanceToAdjust();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3))
              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(row.product.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            Expanded(
              flex: 2,
              child: Text(row.variant.color,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            Expanded(
              flex: 1,
              child: Text(row.size.size.toString(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            Expanded(
              flex: 2,
              child: Text(row.size.stockQty.toString(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // STEP 1 — BUILD
  // ================================================
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STOCK ADJUSTMENT',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('Search for a product variant to adjust its stock.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 20),

          _buildFilters(),
          const SizedBox(height: 16),

          Expanded(child: _buildTable()),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedVariant != null
                    ? 'Selected: ${_selectedProduct!.productName} · ${_selectedVariant!.color} · Size ${_selectedSize!.size}'
                    : 'Select a row to continue.',
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedVariant != null ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
                  fontWeight: _selectedVariant != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedVariant != null ? _advanceToAdjust : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Adjust Stock'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================
  // STEP 2 — BUILD
  // Focused single-variant view, matching the shell pattern used by
  // Edit Banner / Edit Discount dialogs (520px width, 12px radius,
  // 28px padding).
  // ================================================
  Widget _buildStep2() {
    final int currentStock = _getCurrentStock();
    final int newStock = _getNewStockPreview();
    final String? imageUrl = _selectedVariant?.primaryImageUrl;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _isSaving ? null : _backToSelect,
                    child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Adjust Stock',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                ],
              ),
              GestureDetector(
                onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Product image + identity ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 96,
                  height: 96,
                  color: const Color(0xFFF3F4F6),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: Color(0xFF9CA3AF),
                          ),
                        )
                      : const Icon(Icons.image_outlined, size: 32, color: Color(0xFF9CA3AF)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProduct?.productName ?? '',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedVariant?.color ?? ''} · Size ${_selectedSize?.size ?? ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Current Stock:',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          const SizedBox(width: 6),
                          Text('$currentStock',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text('Adjustment Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTypeCard(label: 'Add Stock', isAdd: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeCard(label: 'Remove Stock', isAdd: false)),
            ],
          ),

          const SizedBox(height: 20),

          const Text('Quantity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14),
              decoration: _buildInputDecoration('0'),
            ),
          ),

          const SizedBox(height: 20),

          // ── Live preview ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$currentStock',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, size: 18, color: Color(0xFF9CA3AF)),
                ),
                Text('$newStock',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isAddStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _backToSelect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isSaving || _getAdjustmentQty() == 0) ? null : _saveAdjustment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFF93C5FD),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Adjustment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({required String label, required bool isAdd}) {
    final bool isSelected = _isAddStock == isAdd;
    return GestureDetector(
      onTap: () => setState(() => _isAddStock = isAdd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAdd ? Icons.add : Icons.remove,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: ConstrainedBox(
          constraints: _step == 1
              ? const BoxConstraints(maxWidth: 900, maxHeight: 640, minHeight: 640)
              : const BoxConstraints(maxWidth: 520),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }
}

// ================================================
// FLAT VARIANT ROW MODEL
// ================================================
class _FlatVariantRow {
  final Product product;
  final ProductVariant variant;
  final SizeEntry size;

  const _FlatVariantRow({
    required this.product,
    required this.variant,
    required this.size,
  });
}