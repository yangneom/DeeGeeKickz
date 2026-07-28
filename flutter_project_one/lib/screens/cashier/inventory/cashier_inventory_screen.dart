import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/common/tables/expandable_product_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
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

    final InventoryService _service = InventoryService();

    // products loaded from Supabase
    List<Product> _allProducts = [];

    // products currently shown in table
    List<Product> _filteredProducts = [];

    // loading state
    bool _isLoading = true;

    // filter panel state
    bool _showFilterPanel = false;

    // selected filters
    String? _selectedStatus;
    String? _selectedCategory;

    @override
    void initState() {
      super.initState();
      _loadProducts();
    }

    Future<void> _loadProducts() async {
    final List<Product> products = await _service.fetchProducts();

    if (!mounted) return;

    setState(() {
      _allProducts = products;
      _filteredProducts = products;
      _isLoading = false;
    });
  }

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
        allProducts: _allProducts,
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
      _filteredProducts = _allProducts;
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

                    // pass current selected values
                        selectedValues: {
                          'Status': _selectedStatus,
                          'Category': _selectedCategory,
                        },

                        // when user picks an option
                        onValueChanged: (String section, String? value) {
                          setState(() {
                            if (section == 'Status') _selectedStatus = value;
                            if (section == 'Category') _selectedCategory = value;
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
                            .getCategories(_allProducts)
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                      )
                    : SingleChildScrollView(
                        child: ExpandableProductTable(
                          products: _filteredProducts,
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