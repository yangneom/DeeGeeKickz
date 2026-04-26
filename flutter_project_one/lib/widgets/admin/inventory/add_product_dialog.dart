import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_project_one/widgets/common/confirm_dialog.dart';

void showAddProductDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const AddProductDialog();
    },
  );
}

// ================================================
// SIZE ROW MODEL
// ================================================
class SizeStockRow {
  final TextEditingController sizeController;
  final TextEditingController stockController;

  SizeStockRow({
    TextEditingController? sizeController,
    TextEditingController? stockController,
  })  : sizeController = sizeController ?? TextEditingController(),
        stockController = stockController ?? TextEditingController();

  void dispose() {
    sizeController.dispose();
    stockController.dispose();
  }
}

// ================================================
// VARIANT MODEL
// ================================================
class VariantData {
  final TextEditingController colorNameController;
  final TextEditingController costController;
  final TextEditingController retailController;
  Color selectedColor;
  List<SizeStockRow> sizeRows;

  VariantData()
      : colorNameController = TextEditingController(),
        costController = TextEditingController(),
        retailController = TextEditingController(),
        selectedColor = Colors.black,
        sizeRows = [SizeStockRow()];

  void dispose() {
    colorNameController.dispose();
    costController.dispose();
    retailController.dispose();
    for (SizeStockRow row in sizeRows) {
      row.dispose();
    }
  }
}

// ================================================
// ADD PRODUCT DIALOG
// ================================================
class AddProductDialog extends ConsumerStatefulWidget {
  const AddProductDialog({super.key});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {

  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  String? _selectedBrand;
  String? _selectedCategory;

  final List<String> _brands = [
    'Nike', 'Adidas', 'Puma', 'New Balance',
    'Converse', 'Vans', 'Reebok', 'Under Armour',
  ];

  final List<String> _categories = [
    'Running Shoes', 'Sneakers', 'Basketball Shoes',
    'Sandals', 'Boots', 'Casual Shoes', 'Formal Shoes',
  ];

  final List<VariantData> _variants = [VariantData()];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _productNameController.dispose();
    _detailsController.dispose();
    for (VariantData variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  // ================================================
  // COLOR PICKER
  // ================================================
  void _openColorPicker(int variantIndex) {
    Color tempColor = _variants[variantIndex].selectedColor;
    showDialog(
      context: context,
      builder: (BuildContext colorContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Pick a Color',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (Color color) => tempColor = color,
              enableAlpha: false,
              labelTypes: const [ColorLabelType.hex],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(colorContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF374151))),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _variants[variantIndex].selectedColor = tempColor);
                Navigator.pop(colorContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  void _addVariant() => setState(() => _variants.add(VariantData()));

  void _removeVariant(int index) {
    if (_variants.length == 1) return;
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  void _addSizeRow(int variantIndex) =>
      setState(() => _variants[variantIndex].sizeRows.add(SizeStockRow()));

  void _removeSizeRow(int variantIndex, int rowIndex) {
    if (_variants[variantIndex].sizeRows.length == 1) return;
    setState(() {
      _variants[variantIndex].sizeRows[rowIndex].dispose();
      _variants[variantIndex].sizeRows.removeAt(rowIndex);
    });
  }

  // ================================================
  // HANDLE PUBLISH
  // Now uses the reusable showConfirmDialog
  // ================================================
  Future<void> _handlePublish() async {
    if (_formKey.currentState!.validate() == false) return;

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Ready to publish this product?',
      message: 'This product will be added to your inventory '
          'and visible to customers. '
          'You can still edit this product later.',
      confirmLabel: 'Publish Product',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed == true) {
      await _saveProduct();
    }
  }

  // ================================================
  // SAVE PRODUCT
  // ================================================
  Future<void> _saveProduct() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with real Firestore logic
      print('---- SAVING PRODUCT ----');
      print('Product Name: ${_productNameController.text}');
      print('Brand: $_selectedBrand');
      print('Category: $_selectedCategory');
      print('Details: ${_detailsController.text}');
      for (int i = 0; i < _variants.length; i++) {
        VariantData v = _variants[i];
        print('-- Variant ${i + 1}: ${v.colorNameController.text}');
        print('   Cost: ${v.costController.text}');
        print('   Retail: ${v.retailController.text}');
        for (int j = 0; j < v.sizeRows.length; j++) {
          print('   Size ${j + 1}: '
              '${v.sizeRows[j].sizeController.text} / '
              '${v.sizeRows[j].stockController.text}');
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product published successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (error) {
      print('Error saving product: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save product. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================================================
  // REUSABLE WIDGETS
  // ================================================
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151))),
    );
  }

  // Base input decoration shared by all fields
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB))),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626))),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(hint),
    );
  }

  // ================================================
  // NUMERIC-ONLY FIELD
  // Uses FilteringTextInputFormatter to block
  // letters — only digits allowed (no decimals)
  // ================================================
  Widget _buildNumericField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    bool allowDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // This formatter blocks any non-numeric character as the user types
      inputFormatters: [
        allowDecimal
            ? FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
      decoration: _inputDecoration(hint).copyWith(hintText: null),
      hint: Text(hint,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      items: items
          .map((item) =>
              DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827))),
    );
  }

  Widget _buildUploadBox(String label) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ),
    );
  }

  // ================================================
  // PRODUCT INFORMATION SECTION
  // ================================================
  Widget _buildProductInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading('Product Information'),

        _buildLabel('Product Name'),
        _buildTextField(
          controller: _productNameController,
          hint: 'Enter Product Name',
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please enter a product name' : null,
        ),

        const SizedBox(height: 14),

        _buildLabel('Brand'),
        _buildDropdown(
          hint: 'Select Brand',
          value: _selectedBrand,
          items: _brands,
          onChanged: (v) => setState(() => _selectedBrand = v),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select a brand' : null,
        ),

        const SizedBox(height: 14),

        _buildLabel('Category'),
        _buildDropdown(
          hint: 'Select Category',
          value: _selectedCategory,
          items: _categories,
          onChanged: (v) => setState(() => _selectedCategory = v),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select a category' : null,
        ),

        const SizedBox(height: 14),

        _buildLabel('Details'),
        _buildTextField(
          controller: _detailsController,
          hint: 'Enter Product Description',
          maxLines: 5,
        ),
      ],
    );
  }

  // ================================================
  // VARIANT BLOCK
  // ================================================
  Widget _buildVariantBlock(int variantIndex) {
    VariantData variant = _variants[variantIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFFAFAFA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Variant header + remove button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Variant ${variantIndex + 1}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              if (_variants.length > 1)
                GestureDetector(
                  onTap: () => _removeVariant(variantIndex),
                  child: const Icon(Icons.close,
                      size: 18, color: Color(0xFF9CA3AF)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          _buildLabel('Color Name'),
          _buildTextField(
            controller: variant.colorNameController,
            hint: 'e.g. White, Black, Red',
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter a color name' : null,
          ),

          const SizedBox(height: 14),

          _buildLabel('Color Picker'),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: variant.selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _openColorPicker(variantIndex),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Pick Color',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _buildLabel('Upload Image'),
          const Text('JPG or PNG format • Max 4 images per color',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 6),
          _buildUploadBox('Drag & Drop your images or Browse'),

          const SizedBox(height: 14),

          _buildLabel('Upload Video'),
          const SizedBox(height: 6),
          _buildUploadBox('Drag & Drop your video or Browse'),

          const SizedBox(height: 14),

          // Cost — numeric only, decimals allowed
          _buildLabel('Cost'),
          _buildNumericField(
            controller: variant.costController,
            hint: 'Enter Cost Price',
            allowDecimal: true,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter a cost price' : null,
          ),

          const SizedBox(height: 14),

          // Retail — numeric only, decimals allowed
          _buildLabel('Retail'),
          _buildNumericField(
            controller: variant.retailController,
            hint: 'Enter Retail Price',
            allowDecimal: true,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter a retail price'
                : null,
          ),

          const SizedBox(height: 14),

          _buildLabel('Size & Stock'),

          Column(
            children: List.generate(variant.sizeRows.length, (int rowIndex) {
              SizeStockRow row = variant.sizeRows[rowIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [

                    // Size field — text (sizes can be like "8", "8.5", "XL")
                    Expanded(
                      child: TextFormField(
                        controller: row.sizeController,
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration('Enter Size').copyWith(
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Stock field — digits only, no letters
                    Expanded(
                      child: TextFormField(
                        controller: row.stockController,
                        keyboardType: TextInputType.number,
                        // Blocks anything that isn't a digit
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration('Enter Stock').copyWith(
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Delete row button
                    ElevatedButton(
                      onPressed: () => _removeSizeRow(variantIndex, rowIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontSize: 12)),
                    ),

                    const SizedBox(width: 8),

                    // Add row button
                    ElevatedButton(
                      onPressed: () => _addSizeRow(variantIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Add Option',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ================================================
  // VARIANT LIST SECTION
  // ================================================
  Widget _buildVariantListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading('Variant List'),
        Column(
          children: List.generate(
              _variants.length, (index) => _buildVariantBlock(index)),
        ),
        ElevatedButton.icon(
          onPressed: _addVariant,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Variant', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenWidth < 700 ? screenWidth * 0.95 : 600,
        height: screenHeight * 0.90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('ADD PRODUCT',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                            letterSpacing: 1.0)),
                    SizedBox(height: 4),
                    Text('Fill in the product details below',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                    SizedBox(height: 20),
                    Divider(color: Color(0xFFE5E7EB), height: 1),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductInformationSection(),
                      const SizedBox(height: 28),
                      _buildVariantListSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handlePublish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Publish',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}