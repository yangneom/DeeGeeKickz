import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/common/expandable_product_table.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../services/admin/inventory/inventory_service.dart';

class CashierInventoryScreen extends ConsumerStatefulWidget {
  const CashierInventoryScreen({super.key});

  @override
  ConsumerState<CashierInventoryScreen> createState() {
    return _CashierInventoryScreenState();
  }
}

class _CashierInventoryScreenState
    extends ConsumerState<CashierInventoryScreen> {

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
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS
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
  // CLEAR FILTERS
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
              // TOP ROW — TITLE ONLY
              // ================================================
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // main title
                  Text(
                    'Inventory Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  SizedBox(height: 4),

                  // subtitle
                  Text(
                    'View available products and stock status.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER
              // no add/archive/export buttons
              // cashier can only VIEW!
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar — using common widget!
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    onChanged: (String value) {
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button — using common widget!
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
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // INVENTORY TABLE
              // using common expandable table!
              // actionBuilder is null = no action column
              // cashier can only VIEW products!
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  child: ExpandableProductTable(
                    products: _filteredProducts,

                    // null means no action column shown!
                    actionBuilder: null,
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