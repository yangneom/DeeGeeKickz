import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/admin/inventory/inventory_table.dart';
import '../../../widgets/admin/inventory/add_product_dialog.dart';
import '../../../widgets/admin/inventory/stock_adjustment_dialog.dart';
import '../../../widgets/admin/inventory/archived_items_dialog.dart';


class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================
  final TextEditingController _searchController = TextEditingController();

  List<Product> _filteredProducts = fakeProducts;
  bool _showFilterPanel = false;
  String? _selectedStatus;
  String? _selectedCategory;

  // ================================================
  // GET ALL UNIQUE CATEGORIES
  // ================================================
  List<String> _getCategories() {
    List<String> categories = [];
    for (Product product in fakeProducts) {
      if (!categories.contains(product.category)) {
        categories.add(product.category);
      }
    }
    return categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS
  // ================================================
  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    List<Product> results = [];

    for (Product product in fakeProducts) {

      // Search filter
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch = product.productName.toLowerCase().contains(searchQuery);
        bool brandMatch = product.brand.toLowerCase().contains(searchQuery);
        bool categoryMatch = product.category.toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || brandMatch || categoryMatch;
      }
      if (matchesSearch == false) continue;

      // Category filter
      bool matchesCategory = true;
      if (_selectedCategory != null) {
        matchesCategory = product.category == _selectedCategory;
      }
      if (matchesCategory == false) continue;

      // Status filter
      bool matchesStatus = true;
      if (_selectedStatus != null) {
        matchesStatus = false;
        for (var variant in product.variants) {
          if (variant.status == _selectedStatus) {
            matchesStatus = true;
            break;
          }
        }
      }
      if (matchesStatus == false) continue;

      results.add(product);
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  // ================================================
  // CLEAR ALL FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _searchController.clear();
      _filteredProducts = fakeProducts;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD RADIO OPTION
  // ================================================
  Widget _buildRadioOption(String status) {
    bool isSelected = _selectedStatus == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedStatus == status) {
            _selectedStatus = null;
          } else {
            _selectedStatus = status;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
  // BUILD FILTER PANEL
  // ================================================
  Widget _buildFilterPanel() {
    List<String> categories = _getCategories();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
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

          // Status
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 6),

          _buildRadioOption('Available'),
          _buildRadioOption('Low Stock'),
          _buildRadioOption('Out of Stock'),

          const SizedBox(height: 12),

          // Category
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
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All', style: TextStyle(fontSize: 12)),
                  ),
                  ...categories.map((String cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Clear + Filter buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _clearFilters();
                  },
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
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    setState(() {
                      _showFilterPanel = false;
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
                    style: TextStyle(fontSize: 12),
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
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(

        // Close filter panel when tapping outside
        onTap: () {
          if (_showFilterPanel == true) {
            setState(() {
              _showFilterPanel = false;
            });
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // Title and subtitle
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

                  // Archived button
                  ElevatedButton(
                    onPressed: () {
                      showArchivedItemsDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Archived',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Export button with dropdown arrow
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Export',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: const Color(0xFFD1D5DB),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW
              // [Search] [Filter] ---spacer--- [Add Product] [Stock Adj]
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // Search bar
                  SizedBox(
                    width: 280,
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        _applyFilters();
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Filter button + panel
                  Stack(
                    clipBehavior: Clip.none,
                    children: [

                      // Filter icon button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilterPanel = !_showFilterPanel;
                          });
                        },
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: _showFilterPanel
                                ? const Color(0xFFEFF6FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showFilterPanel
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            size: 18,
                            color: _showFilterPanel
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),

                      // Filter panel appears below the button
                      if (_showFilterPanel == true)
                        Positioned(
                          top: 48,
                          left: 0,
                          child: GestureDetector(
                            onTap: () {},
                            child: _buildFilterPanel(),
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Add Product button
                  ElevatedButton(
                    onPressed: () {
                        showAddProductDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Add Product',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Stock Adj button
                  ElevatedButton(
                    onPressed: () {
                      showStockAdjustmentDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Stock Adj',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                  child: InventoryTable(
                    products: _filteredProducts,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}