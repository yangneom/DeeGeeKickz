// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Color picker package import
// Make sure you have this in pubspec.yaml:
// flutter_colorpicker: ^1.1.0
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// ================================================
// HOW TO USE THIS POPUP
//
// Call this function from your inventory screen
// to show the Add Product popup:
//
//   showAddProductDialog(context);
//
// ================================================
void showAddProductDialog(BuildContext context) {
  showDialog(
    context: context,
    // barrierDismissible = false means clicking
    // outside will NOT close the dialog
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const AddProductDialog();
    },
  );
}

// ================================================
// SIZE ROW MODEL
//
// This holds the data for ONE size & stock row
// Each row has:
//   - a size text field controller
//   - a stock text field controller
// ================================================
class SizeStockRow {
  // Controller for the "Enter Size" field
  final TextEditingController sizeController;

  // Controller for the "Enter Stock" field
  final TextEditingController stockController;

  // Constructor — creates new controllers by default
  SizeStockRow({
    TextEditingController? sizeController,
    TextEditingController? stockController,
  })  : sizeController = sizeController ?? TextEditingController(),
        stockController = stockController ?? TextEditingController();

  // Dispose both controllers to free memory
  void dispose() {
    sizeController.dispose();
    stockController.dispose();
  }
}

// ================================================
// VARIANT MODEL
//
// This holds all the data for ONE variant block
// Each variant has a color, images, video,
// cost, retail price, and a list of size rows
// ================================================
class VariantData {
  // Controller for the "Color Name" field
  final TextEditingController colorNameController;

  // Controller for the "Cost" field
  final TextEditingController costController;

  // Controller for the "Retail" field
  final TextEditingController retailController;

  // The selected color from the color picker
  // Starts as black by default
  Color selectedColor;

  // List of size & stock rows for this variant
  // Starts with one empty row
  List<SizeStockRow> sizeRows;

  // Constructor
  VariantData()
      : colorNameController = TextEditingController(),
        costController = TextEditingController(),
        retailController = TextEditingController(),
        selectedColor = Colors.black,
        sizeRows = [SizeStockRow()];

  // Dispose all controllers to free memory
  void dispose() {
    colorNameController.dispose();
    costController.dispose();
    retailController.dispose();
    // Also dispose each size row
    for (SizeStockRow row in sizeRows) {
      row.dispose();
    }
  }
}

// ================================================
// ADD PRODUCT DIALOG
//
// This is the popup widget that appears
// when the admin clicks "Add Product"
// ================================================
class AddProductDialog extends ConsumerStatefulWidget {
  const AddProductDialog({super.key});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {

  // ================================================
  // TEXT CONTROLLERS — Product Information
  // ================================================

  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  // ================================================
  // DROPDOWN SELECTED VALUES
  // ================================================

  String? _selectedBrand;
  String? _selectedCategory;

  // ================================================
  // DROPDOWN OPTIONS
  // ================================================

  final List<String> _brands = [
    'Nike',
    'Adidas',
    'Puma',
    'New Balance',
    'Converse',
    'Vans',
    'Reebok',
    'Under Armour',
  ];

  final List<String> _categories = [
    'Running Shoes',
    'Sneakers',
    'Basketball Shoes',
    'Sandals',
    'Boots',
    'Casual Shoes',
    'Formal Shoes',
  ];

  // ================================================
  // VARIANT LIST
  //
  // Starts with one empty variant
  // Admin can add more with "+ Add Variant" button
  // ================================================
  final List<VariantData> _variants = [VariantData()];

  // ================================================
  // FORM KEY — used to validate all fields
  // ================================================
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ================================================
  // IS LOADING — shows spinner when saving
  // ================================================
  bool _isLoading = false;

  // ================================================
  // DISPOSE — clean up all controllers
  // ================================================
  @override
  void dispose() {
    _productNameController.dispose();
    _detailsController.dispose();
    // Dispose all variant data
    for (VariantData variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  // ================================================
  // OPEN COLOR PICKER DIALOG
  //
  // Shows a popup with a color wheel
  // Admin picks a color for the variant
  // ================================================
  void _openColorPicker(int variantIndex) {
    // Temp color holds the color while picking
    // We only apply it when admin taps "Select"
    Color tempColor = _variants[variantIndex].selectedColor;

    showDialog(
      context: context,
      builder: (BuildContext colorContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Pick a Color',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            // ColorPicker is from the flutter_colorpicker package
            child: ColorPicker(
              pickerColor: tempColor,
              // Every time user moves the wheel, update tempColor
              onColorChanged: (Color color) {
                tempColor = color;
              },
              // Show hex input field, hide alpha slider
              enableAlpha: false,
              labelTypes: const [ColorLabelType.hex],
            ),
          ),
          actions: [
            // Cancel — close without saving color
            TextButton(
              onPressed: () {
                Navigator.pop(colorContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF374151)),
              ),
            ),

            // Select — apply the chosen color
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Save the selected color to the variant
                  _variants[variantIndex].selectedColor = tempColor;
                });
                Navigator.pop(colorContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  // ================================================
  // ADD VARIANT
  //
  // Adds a new empty variant block to the list
  // ================================================
  void _addVariant() {
    setState(() {
      _variants.add(VariantData());
    });
  }

  // ================================================
  // REMOVE VARIANT
  //
  // Removes a variant block by index
  // We keep at least 1 variant at all times
  // ================================================
  void _removeVariant(int index) {
    // Don't remove if it's the only variant left
    if (_variants.length == 1) {
      return;
    }
    setState(() {
      // Dispose controllers before removing
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  // ================================================
  // ADD SIZE ROW
  //
  // Adds a new empty size row to a specific variant
  // ================================================
  void _addSizeRow(int variantIndex) {
    setState(() {
      _variants[variantIndex].sizeRows.add(SizeStockRow());
    });
  }

  // ================================================
  // REMOVE SIZE ROW
  //
  // Removes a size row from a specific variant
  // Keeps at least 1 row per variant
  // ================================================
  void _removeSizeRow(int variantIndex, int rowIndex) {
    // Don't remove if it's the only row left
    if (_variants[variantIndex].sizeRows.length == 1) {
      return;
    }
    setState(() {
      // Dispose controllers before removing
      _variants[variantIndex].sizeRows[rowIndex].dispose();
      _variants[variantIndex].sizeRows.removeAt(rowIndex);
    });
  }

  // ================================================
  // HANDLE PUBLISH
  //
  // Validates the form then shows confirm dialog
  // ================================================
  Future<void> _handlePublish() async {
    // Check if all required fields are filled
    bool formIsValid = _formKey.currentState!.validate();

    // Stop here if form has errors
    if (formIsValid == false) {
      return;
    }

    // Show confirm dialog
    showDialog(
      context: context,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Ready to publish this product?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          content: const Text(
            'This product will be added to your inventory '
            'and visible to customers. '
            'You can still edit this product later.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          actions: [
            // Cancel — close confirm dialog only
            TextButton(
              onPressed: () {
                Navigator.pop(confirmContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF374151)),
              ),
            ),

            // Publish Product — save to Firestore
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(confirmContext);
                await _saveProduct();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Publish Product',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================
  // SAVE PRODUCT
  //
  // Saves the product to Firestore
  // Uses try/catch so errors don't crash the app
  // ================================================
  Future<void> _saveProduct() async {
    // Show loading spinner
    setState(() {
      _isLoading = true;
    });

    // try = attempt to save
    // catch = handle error if something goes wrong
    try {

      // TODO: Connect to Firestore later
      // For now just print everything to the console
      print('---- SAVING PRODUCT ----');
      print('Product Name: ${_productNameController.text}');
      print('Brand: $_selectedBrand');
      print('Category: $_selectedCategory');
      print('Details: ${_detailsController.text}');

      // Print each variant
      for (int i = 0; i < _variants.length; i++) {
        VariantData variant = _variants[i];
        print('-- Variant ${i + 1} --');
        print('  Color Name: ${variant.colorNameController.text}');
        print('  Color: ${variant.selectedColor}');
        print('  Cost: ${variant.costController.text}');
        print('  Retail: ${variant.retailController.text}');

        // Print each size row
        for (int j = 0; j < variant.sizeRows.length; j++) {
          SizeStockRow row = variant.sizeRows[j];
          print('  Size Row ${j + 1}: '
              'Size=${row.sizeController.text} '
              'Stock=${row.stockController.text}');
        }
      }

      // If successful, close the popup
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product published successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }

    } catch (error) {
      // Something went wrong — print the error
      print('Error saving product: $error');

      // Show error message to the admin
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save product. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }

    } finally {
      // This always runs whether success or error
      // Hide the loading spinner
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ================================================
  // BUILD LABEL
  // Reusable label text above each field
  // ================================================
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  // ================================================
  // BUILD TEXT FIELD
  // Reusable styled text input
  // ================================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  // ================================================
  // BUILD DROPDOWN
  // Reusable styled dropdown
  // ================================================
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
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ================================================
  // BUILD SECTION HEADING
  // Bold title for each section
  // ================================================
  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  // ================================================
  // BUILD UPLOAD BOX
  //
  // The drag & drop looking box for image/video
  // It's just a visual placeholder for now
  // We will connect real file picking later
  // ================================================
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
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD PRODUCT INFORMATION SECTION
  // Product Name, Brand, Category, Details
  // ================================================
  Widget _buildProductInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _buildSectionHeading('Product Information'),

        // Product Name field
        _buildLabel('Product Name'),
        _buildTextField(
          controller: _productNameController,
          hint: 'Enter Product Name',
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a product name';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Brand dropdown
        _buildLabel('Brand'),
        _buildDropdown(
          hint: 'Select Brand',
          value: _selectedBrand,
          items: _brands,
          onChanged: (String? value) {
            setState(() {
              _selectedBrand = value;
            });
          },
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return 'Please select a brand';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Category dropdown
        _buildLabel('Category'),
        _buildDropdown(
          hint: 'Select Category',
          value: _selectedCategory,
          items: _categories,
          onChanged: (String? value) {
            setState(() {
              _selectedCategory = value;
            });
          },
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Details textarea
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
  // BUILD SINGLE VARIANT BLOCK
  //
  // This builds ONE variant card with:
  //   - Color Name
  //   - Color Picker button
  //   - Upload Image box
  //   - Upload Video box
  //   - Cost field
  //   - Retail field
  //   - Size & Stock rows
  //   - Remove button (if more than 1 variant)
  // ================================================
  Widget _buildVariantBlock(int variantIndex) {
    // Get the variant data for this index
    VariantData variant = _variants[variantIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Light border so each variant is visually separated
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFFAFAFA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---- VARIANT HEADER ----
          // Shows "Variant 1", "Variant 2", etc.
          // Also shows an X button to remove it
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variant ${variantIndex + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),

              // Only show remove button if there's more than 1 variant
              if (_variants.length > 1)
                GestureDetector(
                  onTap: () {
                    _removeVariant(variantIndex);
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ---- COLOR NAME ----
          _buildLabel('Color Name'),
          _buildTextField(
            controller: variant.colorNameController,
            hint: 'e.g. White, Black, Red',
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a color name';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // ---- COLOR PICKER ----
          _buildLabel('Color Picker'),
          Row(
            children: [

              // Colored circle shows the currently selected color
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

              // Button to open the color picker popup
              OutlinedButton(
                onPressed: () {
                  _openColorPicker(variantIndex);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Pick Color',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---- UPLOAD IMAGE ----
          _buildLabel('Upload Image'),

          // Small subtitle under the label
          const Text(
            'JPG or PNG format • Max 4 images per color',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),

          const SizedBox(height: 6),

          // Upload image placeholder — TODO: connect image picker later
          _buildUploadBox('Drag & Drop your images or Browse'),

          const SizedBox(height: 14),

          // ---- UPLOAD VIDEO ----
          _buildLabel('Upload Video'),

          const SizedBox(height: 6),

          // Upload video placeholder — TODO: connect video picker later
          _buildUploadBox('Drag & Drop your video or Browse'),

          const SizedBox(height: 14),

          // ---- COST ----
          _buildLabel('Cost'),
          _buildTextField(
            controller: variant.costController,
            hint: 'Enter Cost Price',
            keyboardType: TextInputType.number,
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a cost price';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // ---- RETAIL ----
          _buildLabel('Retail'),
          _buildTextField(
            controller: variant.retailController,
            hint: 'Enter Retail Price',
            keyboardType: TextInputType.number,
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a retail price';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // ---- SIZE & STOCK ----
          _buildLabel('Size & Stock'),

          // Loop through each size row and build it
          // We use Column here (not ListView) because
          // we already have a scroll view wrapping everything
          Column(
            children: List.generate(variant.sizeRows.length, (int rowIndex) {

              // Get the current size row
              SizeStockRow row = variant.sizeRows[rowIndex];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [

                    // Enter Size field
                    Expanded(
                      child: TextFormField(
                        controller: row.sizeController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Enter Size',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF2563EB)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Enter Stock field
                    Expanded(
                      child: TextFormField(
                        controller: row.stockController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Enter Stock',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF2563EB)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Delete button — removes this size row
                    ElevatedButton(
                      onPressed: () {
                        _removeSizeRow(variantIndex, rowIndex);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Add Option button — adds a new size row below
                    ElevatedButton(
                      onPressed: () {
                        _addSizeRow(variantIndex);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Add Option',
                        style: TextStyle(fontSize: 12),
                      ),
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
  // BUILD VARIANT LIST SECTION
  //
  // Shows all variants + the "+ Add Variant" button
  // ================================================
  Widget _buildVariantListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _buildSectionHeading('Variant List'),

        // Build each variant block one by one
        Column(
          children: List.generate(_variants.length, (int index) {
            return _buildVariantBlock(index);
          }),
        ),

        // + Add Variant button
        ElevatedButton.icon(
          onPressed: _addVariant,
          icon: const Icon(Icons.add, size: 16),
          label: const Text(
            'Add Variant',
            style: TextStyle(fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD
  // The main build method — puts everything together
  // ================================================
  @override
  Widget build(BuildContext context) {

    // Get the screen height so we can size the dialog properly
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      // Remove default dialog inset padding
      // We control the size manually below
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        // Fixed width — 600 or 90% of screen, whichever is smaller
        width: screenWidth < 700 ? screenWidth * 0.95 : 600,

        // Fixed height — always 90% of screen height
        // This forces the dialog to be tall enough
        // so the scrollable area has room to show everything
        height: screenHeight * 0.90,

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),

        child: Form(
          key: _formKey,

          // Column fills the full height of the Container above
          // Header at top, scrollable middle, buttons at bottom
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================================================
              // HEADER — always visible at top (NOT scrollable)
              // ================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Title
                    const Text(
                      'ADD PRODUCT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtitle
                    const Text(
                      'Fill in the product details below',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Thin divider line under subtitle
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                  ],
                ),
              ),

              // ================================================
              // SCROLLABLE CONTENT AREA
              // Expanded makes this take up ALL the remaining
              // space between the header and the bottom buttons
              // SingleChildScrollView lets the user scroll
              // through Product Info AND Variant List
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  // physics makes scrolling feel smooth
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Step 1 — Product Information section
                      _buildProductInformationSection(),

                      const SizedBox(height: 28),

                      // Step 2 — Variant List section
                      // Scroll down to see this!
                      _buildVariantListSection(),

                      // Extra space at the bottom so the last
                      // item is not hidden behind the buttons
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ================================================
              // BOTTOM BUTTONS — always visible (NOT scrollable)
              // Cancel + Publish — stuck to the bottom
              // ================================================
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                    // Cancel button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Publish button
                    ElevatedButton(
                      // Disabled while saving
                      onPressed: _isLoading ? null : _handlePublish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          // Show spinner when saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          // Show text when not saving
                          : const Text(
                              'Publish',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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