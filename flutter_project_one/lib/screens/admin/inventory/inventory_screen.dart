import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../services/admin/inventory/inventory_service.dart';
import '../../../providers/product/product_provider.dart';
import '../../../widgets/common/tables/expandable_product_table.dart';
import '../../../widgets/admin/inventory/add_product_dialog.dart';
import '../../../widgets/admin/inventory/stock_adjustment_dialog.dart';
import '../../../widgets/admin/inventory/archived_items_dialog.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';
import '../../../widgets/admin/inventory/edit_product_dialog.dart'; 
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // our inventory service for all Supabase calls
  final InventoryService _service = InventoryService();

  // realtime stock subscription
  RealtimeChannel? _stockChannel;
  Timer? _stockDebounce;

  // ALL products fetched from Supabase (source of truth)
  List<Product> _allProducts = [];

  // products currently shown in the table (filtered)
  List<Product> _filteredProducts = [];

  // true while fetching from Supabase
  bool _isLoading = true;

  // non-null if the fetch failed
  String? _errorMessage;

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter values
  String? _selectedStatus;
  String? _selectedCategory;

  // ================================================
  // INIT STATE — load products on startup
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _subscribeToStockChanges();
  }

  // ================================================
  // REALTIME — live stock updates
  // Debounced: a single sale/approval can touch several
  // product_variant_size rows in quick succession, so this waits
  // for changes to settle before refetching once, instead of
  // reloading the whole table per row.
  // ================================================
  void _subscribeToStockChanges() {
    _stockChannel = Supabase.instance.client
        .channel('inventory_screen_stock_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_variant_size',
          callback: (payload) {
            _stockDebounce?.cancel();
            _stockDebounce = Timer(const Duration(milliseconds: 400), () {
              if (mounted) _loadProducts();
            });
          },
        )
        .subscribe();
  }

  // ================================================
  // DISPOSE — clean up controller when screen closes
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    _stockDebounce?.cancel();
    if (_stockChannel != null) {
      Supabase.instance.client.removeChannel(_stockChannel!);
    }
    super.dispose();
  }

  // ================================================
  // LOAD PRODUCTS FROM SUPABASE
  // called on startup and after add/archive/restore
  // ================================================
  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Product> products = await _service.fetchProducts();

      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });

      // re-apply any active filters on the fresh data
      _applyFilters();

    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load products. Please try again.';
      });
    }
  }

  // ================================================
  // APPLY FILTERS — calls service to filter products
  // always filters from _allProducts (not _filteredProducts)
  // so filters stack correctly
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
  // CLEAR FILTERS — resets everything back to default
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
  // EXPORT — one row per size/variant, not aggregated per
  // product, since a stock snapshot for suppliers or a physical
  // count is more useful broken down to the actual sellable unit.
  // ================================================
  static const List<String> _exportHeaders = [
    'Product Name',
    'Brand',
    'Category',
    'Color',
    'Size',
    'Stock Qty',
    'Reserved',
    'Available',
    'Cost Price',
    'Retail Price',
  ];

  List<List<dynamic>> _buildExportRows() {
    final List<List<dynamic>> rows = [];
    for (final Product product in _filteredProducts) {
      for (final ProductVariant variant in product.variants) {
        for (final SizeEntry size in variant.sizes) {
          rows.add([
            product.productName,
            product.brand,
            product.category,
            variant.color,
            size.size,
            size.stockQty,
            size.reservedQty,
            size.availableQty,
            variant.costPrice,
            variant.retailPrice,
          ]);
        }
      }
    }
    return rows;
  }

  void _exportToCsv() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    CsvExportHelper.exportToCsv(
      filename: 'inventory_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
    );
  }

  void _exportToExcel() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    ExcelExportHelper.exportToExcel(
      filename: 'inventory_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
      sheetName: 'Inventory',
    );
  }

  // ================================================
  // HANDLE ARCHIVE — called from 3-dot menu
  // shows confirm dialog → calls service → refreshes
  // ================================================
  Future<void> _handleArchive(Product product) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Archive "${product.productName}"?',
      message: 'This product will be hidden from inventory and the cashier. '
          'You can restore it anytime from the Archived section.',
      confirmLabel: 'Archive',
      confirmColor: const Color(0xFF9CA3AF),
    );

    if (confirmed != true) return;

    final String? error = await _service.archiveProduct(
      productId: product.productId,
    );

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Same reasoning as restore — archiving hides this product from
    // cashier/shop, but productsProvider doesn't know yet.
    if (!mounted) return;
    ref.invalidate(productsProvider);

    // refresh the list
    await _loadProducts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${product.productName}" archived.'),
          backgroundColor: const Color(0xFF9CA3AF),
        ),
      );
    }
  }

  // ================================================
  // BUILD 3-DOT MENU
  // shows Archive option for each product row
  // ================================================
  void _showProductMenu(BuildContext buttonContext, Product product) {
    final RenderBox button =
        buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: buttonContext,
      position: position,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
            items: [

        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: const [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              SizedBox(width: 8),
              Text(
                'Edit Product',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'archive',
        child: Row(
          children: const [
            Icon(
              Icons.archive_outlined,
              size: 16,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 8),
            Text(
              'Archive',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    ],
    ).then((String? value) async {
      if (value == 'edit') {
        await showEditProductDialog(
          context,
          product: product,
          onProductUpdated: () {
            _loadProducts();
          },
        );
        return;
      }
      if (value == 'archive') {
        _handleArchive(product);
      }
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
                    onPressed: () async {
                      await showArchivedItemsDialog(context);
                      if (!mounted) return;
                      // refresh in case something was restored
                      _loadProducts();
                    },                    style: ElevatedButton.styleFrom(
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

                 // export button
                  ExportButton(
                    onExport: _exportToCsv,
                    onFormatSelected: (format) {
                      if (format == 'excel') {
                        _exportToExcel();
                      } else {
                        _exportToCsv();
                      }
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

                  // search bar
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    onChanged: (String value) {
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button + panel
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },
                    selectedValues: {
                      'Status': _selectedStatus,
                      'Category': _selectedCategory,
                    },
                    onValueChanged: (String section, String? value) {
                      setState(() {
                        if (section == 'Status') _selectedStatus = value;
                        if (section == 'Category') _selectedCategory = value;
                      });
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      _applyFilters();
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },
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

                  const Spacer(),

                  // add product button
                  ElevatedButton(
                    onPressed: () {
                      showAddProductDialog(
                        context,
                        onProductAdded: () {
                          // refresh the list after a product is added
                          _loadProducts();
                        },
                      );    
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
                    onPressed: () async {
                      await showStockAdjustmentDialog(context);
                      if (!mounted) return;
                      // refresh in case stock was changed
                      _loadProducts();
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
              // INVENTORY TABLE — loading / error / data states
              // ================================================
              Expanded(
                child: _buildTableArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD TABLE AREA
  // handles the 3 states: loading, error, data
  // wrapped in Expanded so it fills remaining space
  // ================================================
  Widget _buildTableArea() {

    // ── LOADING STATE ──
    if (_isLoading == true) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 2,
            ),
            SizedBox(height: 16),
            Text(
              'Loading inventory...',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    // ── ERROR STATE ──
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // ── EMPTY STATE ──
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              _allProducts.isEmpty
                  ? 'No products yet. Click "Add Product" to get started.'
                  : 'No products match your search or filters.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            if (_allProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── DATA STATE ──
    return ExpandableProductTable(
      products: _filteredProducts,

      // 3-dot menu as action
      actionBuilder: (Product product) {
        return Builder(
          builder: (BuildContext buttonContext) {
            return GestureDetector(
              onTap: () {
                _showProductMenu(buttonContext, product);
              },
              child: const Icon(
                Icons.more_vert,
                size: 20,
                color: Color(0xFF6B7280),
              ),
            );
          },
        );
      },
    );
  }
}