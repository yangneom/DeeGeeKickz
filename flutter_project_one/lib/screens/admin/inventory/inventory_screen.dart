import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../services/admin/inventory/inventory_service.dart';
import '../../../widgets/admin/inventory/inventory_table.dart';
import '../../../widgets/admin/inventory/add_product_dialog.dart';
import '../../../widgets/admin/inventory/stock_adjustment_dialog.dart';
import '../../../widgets/admin/inventory/archived_items_dialog.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/export_button.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // our inventory service for logic
  final InventoryService _service = InventoryService();

  // list of products shown in table
  List<Product> _filteredProducts = fakeProducts;

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter values
  String? _selectedStatus;
  String? _selectedCategory;

  // ================================================
  // DISPOSE — clean up controller when screen closes
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS — calls service to filter products
  // ================================================
  void _applyFilters() {
    setState(() {
      _filteredProducts = _service.applyFilters(
        allProducts: fakeProducts,
        searchQuery: _searchController.text.toLowerCase(),
        selectedCategory: _selectedCategory,
        selectedStatus: _selectedStatus,
      );
    });
  }

  // ================================================
  // CLEAR FILTERS — resets everything back to default
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
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(

        // close filter panel when tapping outside
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

                  // title and subtitle
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

                  // archived button
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

                  // export button — using common widget!
                  ExportButton(
                    onExport: () {
                      // export logic here later
                    },
                    onDropdown: () {
                      // dropdown logic here later
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER + ADD + STOCK ADJ
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar — using common widget!
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    onChanged: (String value) {
                      // filter every time user types
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button + panel — using common widget!
                  FilterButton(
                    isOpen: _showFilterPanel,

                    // toggle open and close
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },

                    // pass current selected value
                    selectedValue: _selectedStatus,

                    // when user picks an option
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },

                    // when user clicks clear
                    onClear: _clearFilters,

                    // when user clicks apply
                    onApply: () {
                      _applyFilters();
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },

                    // inventory filter sections
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(
                            label: 'Available',
                            value: 'Available',
                          ),
                          FilterOption(
                            label: 'Low Stock',
                            value: 'Low Stock',
                          ),
                          FilterOption(
                            label: 'Out of Stock',
                            value: 'Out of Stock',
                          ),
                        ],
                      ),
                      FilterSection(
                        title: 'Category',
                        options: _service
                            .getCategories(fakeProducts)
                            .map((String category) {
                          return FilterOption(
                            label: category,
                            value: category,
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // add product button
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

                  // stock adjustment button
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