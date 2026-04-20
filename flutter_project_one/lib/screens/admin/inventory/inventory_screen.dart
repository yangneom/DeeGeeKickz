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
  bool _showFilterPanel = false;
  String? _selectedStatus;
  String? _selectedCategory;

  OverlayEntry? _filterOverlay;

  // ================= FILTER LOGIC =================
  List<String> _getCategories() {
    final categories = <String>{};
    for (var p in fakeProducts) {
      categories.add(p.category);
    }
    return categories.toList();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    final results = fakeProducts.where((product) {
      final matchesSearch = query.isEmpty ||
          product.productName.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == null ||
          product.category == _selectedCategory;

      final matchesStatus = _selectedStatus == null ||
          product.variants.any((v) => v.status == _selectedStatus);

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    setState(() => _filteredProducts = results);
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _searchController.clear();
      _filteredProducts = fakeProducts;
    });
    _removeFilterOverlay();
  }

  // ================= OVERLAY =================
  void _showFilterOverlay(BuildContext buttonContext) {
    _removeFilterOverlay();

    final box = buttonContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    _filterOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // click outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeFilterOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // panel
          Positioned(
            top: position.dy + box.size.height,
            left: position.dx,
            child: Material(
              color: Colors.transparent,
              child: _buildFilterPanel(),
            ),
          ),
        ],
      ),
    );

    Overlay.of(buttonContext, rootOverlay: true)
        .insert(_filterOverlay!);

    setState(() => _showFilterPanel = true);
  }

  void _removeFilterOverlay() {
    _filterOverlay?.remove();
    _filterOverlay = null;
    if (mounted) {
      setState(() => _showFilterPanel = false);
    }
  }

  // ================= UI PARTS =================
  Widget _buildRadio(String label) {
    final selected = _selectedStatus == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = selected ? null : label;
        });
      },
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF2563EB) : Colors.grey,
              ),
              color: selected ? const Color(0xFF2563EB) : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    final categories = _getCategories();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.1),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),
          const Text('Status', style: TextStyle(fontSize: 12)),
          _buildRadio('Available'),
          _buildRadio('Low Stock'),
          _buildRadio('Out of Stock'),

          const SizedBox(height: 10),
          const Text('Category', style: TextStyle(fontSize: 12)),

          DropdownButton<String>(
            value: _selectedCategory,
            hint: const Text('All'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ...categories.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (val) {
              setState(() => _selectedCategory = val);
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    _removeFilterOverlay();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ✅ FIXED BUTTON
                Builder(
                  builder: (btnCtx) => GestureDetector(
                    onTap: () {
                      if (_filterOverlay != null) {
                        _removeFilterOverlay();
                      } else {
                        _showFilterOverlay(btnCtx);
                      }
                    },
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        border: Border.all(),
                        color: _showFilterPanel
                            ? Colors.blue.shade50
                            : Colors.white,
                      ),
                      child: const Icon(Icons.filter_list),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: InventoryTable(
                products: _filteredProducts,
              ),
            ),
          ],
        ),
      ),
    );
  }
}