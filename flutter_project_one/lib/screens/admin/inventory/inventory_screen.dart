import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/admin/inventory/inventory_table.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {

  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = fakeProducts;

  // ================================================
  // FILTER STATE
  // ================================================
  bool _showFilter = false;

  // Status filter — null means no filter
  String? _selectedStatus; // 'Available', 'Low Stock', 'Out of Stock'

  // Category filter
  String? _selectedCategory;

  // Size range
  final TextEditingController _sizeMinController = TextEditingController();
  final TextEditingController _sizeMaxController = TextEditingController();

  // Retail price range
  final TextEditingController _retailMinController = TextEditingController();
  final TextEditingController _retailMaxController = TextEditingController();

  // Cost price range
  final TextEditingController _costMinController = TextEditingController();
  final TextEditingController _costMaxController = TextEditingController();

  // Available categories from fake data
  List<String> get _categories {
    return fakeProducts
        .map((p) => p.category)
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sizeMinController.dispose();
    _sizeMaxController.dispose();
    _retailMinController.dispose();
    _retailMaxController.dispose();
    _costMinController.dispose();
    _costMaxController.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE SEARCH
  // ================================================
  void _handleSearch(String query) {
    setState(() {
      _applyFilters(searchQuery: query);
    });
  }

  // ================================================
  // APPLY FILTERS
  // Combines search + all filter fields
  // ================================================
  void _applyFilters({String? searchQuery}) {
    final query = searchQuery ?? _searchController.text;

    _filteredProducts = fakeProducts.where((product) {

      // Search filter
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchesSearch =
            product.productName.toLowerCase().contains(q) ||
            product.brand.toLowerCase().contains(q) ||
            product.category.toLowerCase().contains(q);
        if (!matchesSearch) return false;
      }

      // Category filter
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        if (product.category != _selectedCategory) return false;
      }

      // Status filter — checks if any variant matches
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        final hasMatchingVariant = product.variants
            .any((v) => v.status == _selectedStatus);
        if (!hasMatchingVariant) return false;
      }

      return true;

    }).toList();
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _sizeMinController.clear();
      _sizeMaxController.clear();
      _retailMinController.clear();
      _retailMaxController.clear();
      _costMinController.clear();
      _costMaxController.clear();
      _applyFilters();
    });
  }

  // ================================================
  // BUILD FILTER PANEL
  // Dropdown that appears below the filter button
  // ================================================
  Widget _buildFilterPanel() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // Title
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------
          // STATUS
          // ------------------------------------------------
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          // Available
          _buildRadioOption('Available'),
          _buildRadioOption('Low Stock'),
          _buildRadioOption('Out of Stock'),

          const SizedBox(height: 12),

          // ------------------------------------------------
          // CATEGORY
          // ------------------------------------------------
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All', style: TextStyle(fontSize: 12)),
                  ),
                  ..._categories.map((cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat,
                            style: const TextStyle(fontSize: 12)),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------
          // SIZE
          // ------------------------------------------------
          const Text(
            'Size',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildRangeField(
                  controller: _sizeMinController,
                  hint: 'Min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRangeField(
                  controller: _sizeMaxController,
                  hint: 'Max',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------
          // RETAIL PRICE RANGE
          // ------------------------------------------------
          const Text(
            'Retail Price Range',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildRangeField(
                  controller: _retailMinController,
                  hint: 'Min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRangeField(
                  controller: _retailMaxController,
                  hint: 'Max',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------
          // COST PRICE RANGE
          // ------------------------------------------------
          const Text(
            'Cost Price Range',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildRangeField(
                  controller: _costMinController,
                  hint: 'Min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRangeField(
                  controller: _costMaxController,
                  hint: 'Max',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------
          // CLEAR + FILTER BUTTONS
          // ------------------------------------------------
          Row(
            children: [

              // Clear button
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Filter button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _applyFilters();
                      _showFilter = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Filter',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================
  // RADIO OPTION for Status filter
  // ================================================
  Widget _buildRadioOption(String status) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = _selectedStatus == status ? null : status;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedStatus == status
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: _selectedStatus == status
                    ? const Color(0xFF2563EB)
                    : Colors.white,
              ),
              child: _selectedStatus == status
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // RANGE FIELD — Min/Max input
  // ================================================
  Widget _buildRangeField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      height: 32,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        // Close filter panel when tapping outside
        onTap: () {
          if (_showFilter) {
            setState(() => _showFilter = false);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================================================
              // TOP ROW — TITLE + ARCHIVED + EXPORT
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manages items and their stock status.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Archived',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Export',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Container(
                            width: 1,
                            height: 20,
                            color: const Color(0xFFD1D5DB)),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.keyboard_arrow_down,
                              size: 18, color: Color(0xFF6B7280)),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER + BUTTONS
              // Search is fixed width, not full Expanded
              // ================================================
              Row(
                children: [

                  // Search bar — fixed width ~350
                  SizedBox(
                    width: 350,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _handleSearch,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Filter button with dropdown
                  Stack(
                    clipBehavior: Clip.none,
                    children: [

                      // Filter icon button
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: _showFilter
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showFilter
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() => _showFilter = !_showFilter);
                          },
                          icon: Icon(
                            Icons.filter_list,
                            size: 18,
                            color: _showFilter
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6B7280),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),

                      // Filter dropdown panel
                      if (_showFilter)
                        Positioned(
                          top: 48,
                          left: 0,
                          child: _buildFilterPanel(),
                        ),
                    ],
                  ),

                  // Spacer pushes buttons to the right
                  const Spacer(),

                  // Add Product
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Add Product',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),

                  const SizedBox(width: 8),

                  // Stock Adj
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Stock Adj',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // INVENTORY TABLE
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: InventoryTable(products: _filteredProducts),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}