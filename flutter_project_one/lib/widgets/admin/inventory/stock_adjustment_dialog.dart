import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_project_one/widgets/common/dialog/confirm_dialog.dart';
import '../../../models/product.dart';
import '../../../services/admin/inventory/inventory_service.dart';
import '../../../services/admin/inventory/stock_service.dart';

void showStockAdjustmentDialog(BuildContext context) {
  showDialog(
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
  // SAVE ADJUSTMENT
  // ================================================
  Future<void> _saveAdjustment() async {
    if (_selectedVariant == null || _selectedSize == null) return;

    String action = _isAddStock ? 'Add' : 'Remove';
    int qty = _getAdjustmentQty();
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

    final String? error = await _stockService.adjustStock(
      sizeId: _selectedSize!.sizeId!,
      adjustment: qty,
      isAddStock: _isAddStock,
    );

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock adjustment saved successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
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
  // BUILD FILTERS
  // ================================================
  Widget _buildFilters() {
    List<String> categories = _getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Search product
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text('Search Product :',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 180,
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

        const SizedBox(height: 10),

        // Search size
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text('Search Size :',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF374151))),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
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

        const SizedBox(height: 10),

        // Category dropdown
        Row(
          children: [
            const SizedBox(
              width: 110,
              child: Text('Category :',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF374151))),
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
                    hint: const Text('All',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All',
                            style: TextStyle(fontSize: 12)),
                      ),
                      ...categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category,
                              style: const TextStyle(fontSize: 12)),
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
      ],
    );
  }

  // ================================================
  // BUILD TABLE
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Text('Product Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Color',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Size',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Stock Qty',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Rows
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2563EB),
                      strokeWidth: 2,
                    ),
                  )
                : _filteredRows.isEmpty
                    ? const Center(
                        child: Text('No products found.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF))),
                      )
                    : ListView.separated(
                        itemCount: _filteredRows.length,
                        separatorBuilder:
                            (BuildContext context, int index) =>
                                const Divider(
                                    height: 1,
                                    color: Color(0xFFE5E7EB)),
                        itemBuilder:
                            (BuildContext context, int index) {
                          _FlatVariantRow row = _filteredRows[index];
                          bool isSelected =
                              _selectedVariant == row.variant &&
                                  _selectedProduct == row.product;
                          return _buildTableRow(row, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD TABLE ROW
  // ================================================
  Widget _buildTableRow(_FlatVariantRow row, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedVariant = row.variant;
          _selectedProduct = row.product;
          _selectedSize = row.size;
          _quantityController.clear();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    _selectedVariant = row.variant;
                    _selectedProduct = row.product;
                    _selectedSize = row.size; // ADD THIS
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
                      fontSize: 13, color: Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            Expanded(
              flex: 2,
              child: Text(row.variant.color,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
            Expanded(
                flex: 1,
                child: Text(
                  row.size.size.toString(),
                ),
              ),
            Expanded(
              flex: 2,
              child: Text(row.size.stockQty.toString(),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151))),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD RADIO BUTTON
  // ================================================
  Widget _buildRadio(String label, bool isAddMode) {
    bool isSelected = _isAddStock == isAddMode;

    return GestureDetector(
      onTap: () => setState(() => _isAddStock = isAddMode),
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
              color:
                  isSelected ? const Color(0xFF2563EB) : Colors.white,
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

  // ================================================
  // BUILD INFO ROW
  // ================================================
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ],
      ),
    );
  }

  // ================================================
  // BUILD RIGHT PANEL
  // ================================================
  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text('Selected Variant',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827))),

        const SizedBox(height: 10),

        if (_selectedVariant == null)
          const Text('Select a product row to see details.',
              style:
                  TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Product Name :', _selectedProduct!.productName),
              _buildInfoRow('Color :', _selectedVariant!.color),
              _buildInfoRow(
                  'Size :', _selectedSize?.size.toString() ?? '-'),
              _buildInfoRow('Current Stock Qty :',
                  _getCurrentStock().toString()),
            ],
          ),

        const SizedBox(height: 24),

        const Text('Adjustment Type',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827))),

        const SizedBox(height: 10),

        _buildRadio('Add Stock', true),
        const SizedBox(height: 6),
        _buildRadio('Remove Stock', false),

        const SizedBox(height: 20),

        Row(
          children: [
            const Text('Quantity:',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              height: 36,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                decoration: _buildInputDecoration(''),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_selectedVariant != null && _selectedSize != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Stock Qty Preview :',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF374151))),
              const SizedBox(height: 4),
              Text(
                _getNewStockPreview().toString(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827)),
              ),
            ],
          ),
      ],
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 960, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              const Text('STOCK ADJUSTMENT',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: 0.5)),

              const SizedBox(height: 4),

              const Text(
                  'Select a product variant and adjust its stock quantity.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 20),

              // Main body
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Left — filters + table
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

                    // Right — details panel
                    SizedBox(
                        width: 280, child: _buildRightPanel()),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side:
                          const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_selectedVariant != null &&
                            _getAdjustmentQty() > 0)
                        ? _saveAdjustment
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor:
                          const Color(0xFF93C5FD),
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