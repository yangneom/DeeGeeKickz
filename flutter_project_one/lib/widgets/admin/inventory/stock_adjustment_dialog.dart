import 'package:flutter/material.dart';
import 'package:flutter/services.dart';    // Needed for FilteringTextInputFormatter (numbers-only keyboard)
import '../../../models/product.dart';     // Brings in the Product and ProductVariant classes


// ============================================================
// HELPER FUNCTION
// A plain function (not inside a class) that shows the dialog.
// We call this from somewhere else in the app like:
//   showStockAdjustmentDialog(context);
// ============================================================
void showStockAdjustmentDialog(BuildContext context) {
  showDialog(
    context: context,                                   // Flutter needs context to know WHERE to show the dialog
    barrierColor: Colors.black.withOpacity(0.4),        // The semi-transparent dark overlay BEHIND the dialog
    builder: (BuildContext context) => const StockAdjustmentDialog(),  // The widget to SHOW inside the dialog
  );
}


// ============================================================
// THE DIALOG WIDGET
//
// StatefulWidget means this widget can change over time.
// When the user types in a search box or selects a row,
// we call setState() and Flutter redraws the screen.
// ============================================================
class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key});

  // Every StatefulWidget must create its State object like this.
  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}


// ============================================================
// THE STATE CLASS
//
// This is where ALL the data and logic lives.
// The underscore (_) at the start means it is PRIVATE —
// nothing outside this file can touch it directly.
// ============================================================
class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {

  // ----------------------------------------------------------
  // TEXT CONTROLLERS
  //
  // A TextEditingController is attached to a TextField.
  // It lets us READ what the user typed: _searchController.text
  // It also lets us CLEAR the field:      _searchController.clear()
  // ----------------------------------------------------------
  final TextEditingController _searchController   = TextEditingController();
  final TextEditingController _sizeController     = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();


  // ----------------------------------------------------------
  // STATE VARIABLES
  //
  // These hold the current "memory" of the dialog.
  // When any of these change (inside setState()), Flutter
  // redraws only the parts of the screen that need updating.
  // ----------------------------------------------------------
  String?         _selectedCategory; // null means "no category filter chosen yet"
  ProductVariant? _selectedVariant;  // null means "no row selected yet"
  Product?        _selectedProduct;  // null means "no row selected yet"
  bool            _isAddStock = true; // true = Add Stock mode, false = Remove Stock mode

  List<_FlatVariantRow> _filteredRows = []; // The list of rows currently visible in the table


  // ----------------------------------------------------------
  // initState
  //
  // Flutter calls this ONCE, right after the widget is created.
  // We use it to set up initial data and attach listeners.
  // ----------------------------------------------------------
  @override
  void initState() {
    super.initState(); // Always call this first — Flutter requires it

    // Show ALL rows when the dialog first opens (no filters applied yet)
    _filteredRows = _buildAllRows();

    // Listen to the quantity field.
    // Every time the user types or deletes a character, this runs.
    // setState() makes Flutter redraw so the "New Stock Preview" updates live.
    _quantityController.addListener(() => setState(() {}));
  }


  // ----------------------------------------------------------
  // dispose
  //
  // Flutter calls this when the dialog is closed.
  // We MUST manually clean up controllers to free memory.
  // Forgetting to dispose controllers causes memory leaks.
  // ----------------------------------------------------------
  @override
  void dispose() {
    _searchController.dispose();
    _sizeController.dispose();
    _quantityController.dispose();
    super.dispose(); // Always call this last
  }


  // ----------------------------------------------------------
  // _buildAllRows
  //
  // Goes through every Product in fakeProducts, and for each
  // product goes through every variant (size + color combo).
  // Returns a flat list of _FlatVariantRow objects —
  // one row per variant — which the table will display.
  //
  // "Flat" means we combine product+variant into one object
  // so each table row has everything it needs in one place.
  // ----------------------------------------------------------
  List<_FlatVariantRow> _buildAllRows() {
    List<_FlatVariantRow> rows = [];                    // Start with an empty list

    for (final product in fakeProducts) {               // Loop through each product
      for (final variant in product.variants) {         // Loop through each size/color variant
        rows.add(_FlatVariantRow(                       // Add one row per variant
          product: product,
          variant: variant,
        ));
      }
    }

    return rows;
  }


  // ----------------------------------------------------------
  // _getCategories
  //
  // Collects every unique category name from fakeProducts.
  // We use a Set (not a List) because Sets automatically
  // remove duplicates — so "Sneakers" only appears once
  // even if 10 products are in the Sneakers category.
  // ----------------------------------------------------------
  List<String> _getCategories() {
    final cats = <String>{};                            // A Set of Strings (no duplicates)
    for (final p in fakeProducts) {
      cats.add(p.category);
    }
    return cats.toList();                               // Convert Set → List so we can use it in a dropdown
  }


  // ----------------------------------------------------------
  // _applyFilters
  //
  // Rebuilds _filteredRows based on all three active filters:
  //   1. Search text  (product name or brand)
  //   2. Size text    (number)
  //   3. Category     (dropdown selection)
  //
  // We call this every time the user types or changes the dropdown.
  // setState() triggers a redraw so the table updates instantly.
  // ----------------------------------------------------------
  void _applyFilters() {
    final query     = _searchController.text.toLowerCase(); // Convert to lowercase so search is case-insensitive
    final sizeQuery = _sizeController.text.toLowerCase();

    setState(() {
      _filteredRows = _buildAllRows().where((row) {
        // Does the search text match the product name OR the brand?
        final matchesSearch = query.isEmpty ||             // If nothing typed, everything matches
            row.product.productName.toLowerCase().contains(query) ||
            row.product.brand.toLowerCase().contains(query);

        // Does the size match?
        final matchesSize = sizeQuery.isEmpty ||
            row.variant.size.toString().contains(sizeQuery);

        // Does the category match?
        final matchesCategory = _selectedCategory == null ||  // null = "All" selected
            row.product.category == _selectedCategory;

        // Only keep this row if ALL THREE filters pass
        return matchesSearch && matchesSize && matchesCategory;
      }).toList();
    });
  }


  // ----------------------------------------------------------
  // COMPUTED PROPERTIES (getters)
  //
  // These are like smart variables — they calculate a value
  // on the fly every time you read them.
  // The "get" keyword makes them work like a property:
  //   print(_currentStock)   ← no parentheses needed
  // ----------------------------------------------------------

  // The stock of the currently selected variant, or 0 if nothing is selected
  int get _currentStock => _selectedVariant?.stockQty ?? 0;
  //                                        ↑              ↑
  //                           ?. = safe access          ?? = "if null, use this"
  //   (won't crash if _selectedVariant is null)

  // Parse what the user typed in the quantity box as an integer.
  // Returns 0 if the box is empty or contains invalid text.
  int get _adjustmentQty {
    final parsed = int.tryParse(_quantityController.text); // tryParse returns null if it can't convert
    return (parsed != null && parsed > 0) ? parsed : 0;
  }

  // Calculate what the new stock would be AFTER the adjustment.
  // Used for the live preview shown on the right panel.
  int get _newStockPreview {
    if (_isAddStock) {
      return _currentStock + _adjustmentQty;             // Adding stock
    }
    final result = _currentStock - _adjustmentQty;       // Removing stock
    return result < 0 ? 0 : result;                      // Never go below 0
  }


  // ----------------------------------------------------------
  // _saveAdjustment
  //
  // Called when the user taps "Save Adjustment".
  // Right now it just closes the dialog (Navigator.pop).
  // In a real app you would call a provider or API here
  // to actually update the stock in your database.
  // ----------------------------------------------------------
  void _saveAdjustment() {
    if (_selectedVariant == null) return;                // Safety check: do nothing if nothing selected
    // TODO: Call your inventory service / state provider here
    Navigator.of(context).pop();                         // Close the dialog
  }


  // ============================================================
  // BUILD METHOD
  //
  // Flutter calls build() every time setState() is called.
  // It returns the complete widget tree to display on screen.
  // Think of it as: "given the current state, draw THIS."
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      // insetPadding = how much space between the dialog and the screen edges
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),

      child: ConstrainedBox(
        // Limit the dialog size so it doesn't get too big on large screens
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 680),

        child: Padding(
          padding: const EdgeInsets.all(32),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to the left
            children: [

              // ── Title at the top ──────────────────────────
              const Text(
                'STOCK ADJUSTMENT',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),   // Dark gray (hex color code)
                  letterSpacing: 0.5,         // Slight spacing between letters
                ),
              ),
              const SizedBox(height: 4),      // A small vertical gap
              const Divider(color: Color(0xFFE5E7EB)), // A horizontal line
              const SizedBox(height: 20),

              // ── Main body area (takes all remaining vertical space) ──
              Expanded(                        // Expanded = "take up all the space you can"
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── LEFT SIDE: filters + table ──────────
                    Expanded(
                      flex: 5,               // "Take 5 parts of the available width"
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilters(),   // The search boxes and dropdown
                          const SizedBox(height: 16),
                          Expanded(child: _buildTable()), // The scrollable list of rows
                        ],
                      ),
                    ),

                    const SizedBox(width: 32), // Gap between left and right sides

                    // ── RIGHT SIDE: selected product details + adjustment controls ──
                    SizedBox(
                      width: 280,            // Fixed width — does not grow or shrink
                      child: _buildRightPanel(),
                    ),
                  ],
                ),
              ),

              // ── Cancel and Save buttons at the bottom ──
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end, // Push buttons to the RIGHT
                children: [

                  // Cancel button (outlined, no fill)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(), // Close dialog on tap
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),

                  const SizedBox(width: 12),

                  // Save button (filled blue, disabled if nothing is selected)
                  ElevatedButton(
                    // onPressed = null means the button is DISABLED (grayed out)
                    onPressed: _selectedVariant != null ? _saveAdjustment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),          // Blue when enabled
                      disabledBackgroundColor: const Color(0xFF93C5FD),  // Light blue when disabled
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,           // No shadow
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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


  // ============================================================
  // FILTER SECTION
  //
  // Three rows of inputs:
  //   1. Text field to search by product name / brand
  //   2. Text field to search by size (numbers only)
  //   3. Dropdown to filter by category
  // ============================================================
  Widget _buildFilters() {
    final categories = _getCategories(); // Get the list of unique categories

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Row 1: Search by product name ────────────
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
                controller: _searchController,               // Linked to our controller
                onChanged: (_) => _applyFilters(),           // Refilter on every keystroke
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration('e.g. Nike Air Max'),            // Reusable input style (defined below)
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Row 2: Search by size (numbers only) ─────
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
                keyboardType: TextInputType.number,                          // Show number keyboard on mobile
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],   // Block non-number characters
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration('e.g. 5'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Row 3: Category dropdown ──────────────────
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
                child: DropdownButtonHideUnderline(   // Hides the default bottom border of DropdownButton
                  child: DropdownButton<String>(
                    value: _selectedCategory,          // Currently selected value (null = "All")
                    hint: const Text(
                      'Select Category',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    isExpanded: true,                  // Fill the container width

                    items: [
                      // First item is always "All" (value = null)
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All', style: TextStyle(fontSize: 12)),
                      ),
                      // Then one item per real category
                      ...categories.map((c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      )),
                    ],

                    onChanged: (v) {
                      setState(() => _selectedCategory = v); // Save the new selection
                      _applyFilters();                        // Refilter immediately
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


  // ============================================================
  // PRODUCT TABLE
  //
  // A scrollable list of rows. Each row = one variant.
  // Tapping a row selects it and shows it in the right panel.
  // ============================================================
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [

          // ── Header row (non-scrollable, always visible) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),                          // Light gray background
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)), // Only top corners rounded
            ),
            child: Row(
              children: const [
                SizedBox(width: 32),                             // Space for the checkbox column
                Expanded(flex: 3, child: Text('Product Name', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Color',        style: _headerStyle)),
                Expanded(flex: 1, child: Text('Size',         style: _headerStyle)),
                Expanded(flex: 2, child: Text('Stock Qty',    style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Scrollable data rows ──────────────────────
          Expanded(
            child: _filteredRows.isEmpty

              // Show a message when no results match the filters
              ? const Center(
                  child: Text(
                    'No products found.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                )

              // Otherwise show the list
              : ListView.separated(
                  itemCount: _filteredRows.length,

                  // separatorBuilder draws a thin line BETWEEN each row (not after the last one)
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  itemBuilder: (context, index) {
                    final row = _filteredRows[index];

                    // Is this the currently selected row?
                    final isSelected =
                        _selectedVariant == row.variant &&
                        _selectedProduct  == row.product;

                    return _buildTableRow(row, isSelected);
                  },
                ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // ONE TABLE ROW
  //
  // Builds a single row in the product list.
  // isSelected = true means this row is currently highlighted.
  // ============================================================
  Widget _buildTableRow(_FlatVariantRow row, bool isSelected) {

    // A helper that selects this row (used in both the checkbox and the row tap)
    void selectRow() {
      setState(() {
        _selectedVariant = row.variant;
        _selectedProduct = row.product;
        _quantityController.clear();    // Reset the quantity input when a new row is picked
      });
    }

    return InkWell(
      onTap: selectRow,               // Tapping anywhere on the row selects it

      child: Container(
        // Blue background when selected, transparent when not
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),

        child: Row(
          children: [

            // Checkbox on the left
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => selectRow(), // Tapping the checkbox also selects the row
                activeColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),

            // Product name (truncated with "..." if too long)
            Expanded(
              flex: 3,
              child: Text(
                row.product.productName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                overflow: TextOverflow.ellipsis, // Show "..." instead of overflowing
                maxLines: 1,
              ),
            ),

            // Color name
            Expanded(
              flex: 2,
              child: Text(
                row.variant.color,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // Size number
            Expanded(
              flex: 1,
              child: Text(
                row.variant.size.toString(), // Convert int to String for display
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),

            // Current stock quantity
            Expanded(
              flex: 2,
              child: Text(
                row.variant.stockQty.toString(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ============================================================
  // RIGHT PANEL
  //
  // Shows info about the selected variant, the add/remove toggle,
  // the quantity input, and a live preview of the new stock total.
  // ============================================================
  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Section title ─────────────────────────────
        const Text(
          'Selected Variant',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),

        // ── Show details or a hint, depending on selection ──
        if (_selectedVariant == null)
          // Nothing selected yet
          const Text(
            'Select a product row to see details.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          )
        else ...[
          // The ... spread operator adds multiple widgets into the list
          _infoRow('Product Name :',   _selectedProduct!.productName),
          _infoRow('Color :',           _selectedVariant!.color),
          _infoRow('Size :',            _selectedVariant!.size.toString()),
          _infoRow('Current Stock Qty:', _currentStock.toString()),
          // The ! after the variable tells Dart "I promise this isn't null"
          // (we already checked with if (_selectedVariant == null) above)
        ],

        const SizedBox(height: 24),

        // ── Adjustment type radio buttons ─────────────
        const Text(
          'Adjustment Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),
        _buildRadio('Add Stock',    true),   // true  = Add mode
        const SizedBox(height: 6),
        _buildRadio('Remove Stock', false),  // false = Remove mode

        const SizedBox(height: 20),

        // ── Quantity input ────────────────────────────
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Numbers only
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                decoration: _inputDecoration(''),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── New stock preview (only shown when a variant is selected) ──
        if (_selectedVariant != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Stock Qty Preview :',
                style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 4),
              Text(
                _newStockPreview.toString(), // This recalculates every time setState() is called
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
      ],
    );
  }


  // ============================================================
  // SMALL HELPER WIDGETS
  // ============================================================

  // _infoRow: Stacks a gray label above a black value.
  // Used in the right panel to show product details.
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))), // Gray label
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // _buildRadio: A custom radio button (circle + label).
  // Flutter's built-in Radio widget has limited styling,
  // so this one is drawn manually using a Container.
  Widget _buildRadio(String label, bool isAdd) {
    final isSelected = _isAddStock == isAdd; // Is this the currently active option?

    return GestureDetector(
      onTap: () => setState(() => _isAddStock = isAdd), // Switch mode on tap

      child: Row(
        children: [
          // The circle shape
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                width: 2,
              ),
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
            ),
            // The small white dot inside when selected
            child: isSelected
              ? const Center(child: Icon(Icons.circle, size: 6, color: Colors.white))
              : null,
          ),

          const SizedBox(width: 8),

          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
        ],
      ),
    );
  }

  // _inputDecoration: A reusable style for all text fields in this dialog.
  // Instead of writing the same border/padding settings over and over,
  // we define it once here and call _inputDecoration('') wherever needed.
  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

    // Default border (when the field is not focused)
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    // When not focused (same as border above, required separately by Flutter)
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    // Blue border when the user taps into the field
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF2563EB)),
    ),
  );
}


// ============================================================
// FLAT VARIANT ROW MODEL
//
// A simple data holder. Each row in the table is one of these.
// It bundles a Product and one of its ProductVariants together
// so a table row has everything it needs in one object.
//
// We need this because one Product can have many variants
// (e.g. Nike Air Max in Red/Size 9, Red/Size 10, Blue/Size 9).
// Each combination becomes its own _FlatVariantRow.
// ============================================================
class _FlatVariantRow {
  final Product        product; // The parent product (name, brand, category)
  final ProductVariant variant; // The specific size + color + stock

  const _FlatVariantRow({required this.product, required this.variant});
}


// ============================================================
// SHARED TEXT STYLE
//
// Defined once outside the class so it can be used as a
// compile-time constant (const) anywhere in this file.
// The "table header" style — small, medium weight, gray.
// ============================================================
const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Color(0xFF6B7280),
);