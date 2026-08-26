import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_project_one/widgets/common/dialog/confirm_dialog.dart';
import 'package:flutter_project_one/services/admin/inventory/inventory_service.dart';

// ================================================
// SHOW ADD PRODUCT DIALOG
// onProductAdded → called after product is saved
// so inventory_screen.dart can refresh its list
// ================================================
Future<void> showAddProductDialog(
  BuildContext context, {
  required VoidCallback onProductAdded,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AddProductDialog(
        onProductAdded: onProductAdded,
      );
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
// holds all data for one color variant
// pickedImageFiles → files selected by file_picker
// uploadedImageUrls → urls after upload to Supabase
// ================================================
class VariantData {
  final TextEditingController colorNameController;
  final TextEditingController costController;
  final TextEditingController retailController;
  Color selectedColor;
  List<SizeStockRow> sizeRows;

  // image files picked by the user (not yet uploaded)
  List<PlatformFile> pickedImageFiles;


  VariantData()
      : colorNameController = TextEditingController(),
        costController = TextEditingController(),
        retailController = TextEditingController(),
        selectedColor = Colors.black,
        sizeRows = [SizeStockRow()],
        pickedImageFiles = [];

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
  final VoidCallback onProductAdded;

  const AddProductDialog({
    super.key,
    required this.onProductAdded,
  });

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {

  // ── SUPABASE ──
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryService _service = InventoryService();

  // ── FORM ──
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedBrand;
  String? _selectedCategory;

  // loaded from Supabase
  List<String> _brands = [];
  List<String> _categories = [];
  bool _isLoadingDropdowns = true;

  final List<VariantData> _variants = [VariantData()];
  bool _isLoading = false;

  // ================================================
  // INIT STATE — load brands and categories
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  // ================================================
  // LOAD BRANDS AND CATEGORIES FROM SUPABASE
  // ================================================
  Future<void> _loadDropdowns() async {
    try {
      List<String> brands = await _service.fetchBrands();
      List<String> categories = await _service.fetchCategories();

      setState(() {
        _brands = brands;
        _categories = categories;
        _isLoadingDropdowns = false;
      });

    } catch (error) {
      print('_loadDropdowns error: $error');
      setState(() {
        _isLoadingDropdowns = false;
      });
    }
  }

  // ================================================
  // DISPOSE
  // ================================================
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Pick a Color',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF374151)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
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
  // PICK IMAGES
  // uses file_picker to let admin select images
  // max 4 images per variant
  // ================================================
  Future<void> _pickImages(int variantIndex) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null) return;

      // max 4 images per variant
      List<PlatformFile> currentFiles =
          _variants[variantIndex].pickedImageFiles;

      int remaining = 4 - currentFiles.length;

      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 4 images per variant.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // only take up to the remaining slots
      List<PlatformFile> newFiles = result.files.take(remaining).toList();

      setState(() {
        _variants[variantIndex].pickedImageFiles.addAll(newFiles);
      });

    } catch (error) {
      print('_pickImages error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick images. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================================================
  // REMOVE PICKED IMAGE
  // removes a selected image before upload
  // ================================================
  void _removeImage(int variantIndex, int imageIndex) {
    setState(() {
      _variants[variantIndex].pickedImageFiles.removeAt(imageIndex);
    });
  }

  // ================================================
  // UPLOAD IMAGES TO SUPABASE STORAGE
  // uploads all picked images for one variant
  // returns list of public URLs
  // ================================================
  Future<List<String>> _uploadImages(
    int variantId,
    List<PlatformFile> files,
  ) async {
    List<String> urls = [];

    for (int i = 0; i < files.length; i = i + 1) {
      PlatformFile file = files[i];

      try {
        // build a unique file path inside the bucket
        // format: variant_{id}/{timestamp}_{filename}
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = file.name;
        String filePath = 'variant_$variantId/${timestamp}_$fileName';

        // get the file bytes
        Uint8List? fileBytes = file.bytes;

        // on mobile, bytes may be null — read from path instead
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes == null) {
          print('_uploadImages: skipping ${file.name} — no bytes');
          continue;
        }

        // upload to Supabase Storage
        await _supabase.storage
            .from('product-images')
            .uploadBinary(filePath, fileBytes);

        // get public URL
        String publicUrl = _supabase.storage
            .from('product-images')
            .getPublicUrl(filePath);

        urls.add(publicUrl);

      } catch (error) {
        print('_uploadImages: failed to upload ${file.name}: $error');
        // skip this file and continue with the rest
      }
    }

    return urls;
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
  // validate → confirm → save
  // ================================================
  Future<void> _handlePublish() async {
    if (_formKey.currentState!.validate() == false) return;

    // NEW — block duplicate color names within this product. Two
    // variants sharing a color name makes one invisible to the
    // cashier (SelectVariantDialog resolves by color via firstWhere,
    // which only returns the first match), silently locking out that
    // variant's entire stock with no error anywhere.
    final Set<String> seenColors = {};
    for (final variant in _variants) {
      final String colorKey = variant.colorNameController.text.trim().toLowerCase();
      if (colorKey.isEmpty) continue;
      if (seenColors.contains(colorKey)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Two variants both use the color "$colorKey". Each color must be unique within a product.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
      seenColors.add(colorKey);
    }

    // NEW — block duplicate sizes within the same color variant. Two
    // identical size rows (e.g. two "9" rows) would create two stock
    // entries for the same size, splitting/confusing stock counts.
    for (final variant in _variants) {
      final Set<String> seenSizes = {};
      final String colorLabel = variant.colorNameController.text.trim();
      for (final row in variant.sizeRows) {
        final String sizeKey = row.sizeController.text.trim().toLowerCase();
        if (sizeKey.isEmpty) continue;
        if (seenSizes.contains(sizeKey)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'The size "${row.sizeController.text.trim()}" is entered twice for color "$colorLabel". Each size should only appear once per color.'),
              backgroundColor: Colors.red,
            ));
          }
          return;
        }
        seenSizes.add(sizeKey);
      }
    }

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
  // builds variant data map → calls service → uploads images
  // ================================================
  Future<void> _saveProduct() async {
    setState(() => _isLoading = true);

    try {
      // build variants data list for service
      List<Map<String, dynamic>> variantsData = [];

      for (int i = 0; i < _variants.length; i = i + 1) {
        VariantData v = _variants[i];

        // build size rows list
        List<Map<String, dynamic>> sizeRows = [];
        for (int j = 0; j < v.sizeRows.length; j = j + 1) {
          sizeRows.add({
            'size': v.sizeRows[j].sizeController.text.trim(),
            'stockQty': int.tryParse(
                  v.sizeRows[j].stockController.text.trim(),
                ) ??
                0,
          });
        }

        variantsData.add({
          'colorName': v.colorNameController.text.trim(),
          'costPrice': double.tryParse(v.costController.text.trim()) ?? 0,
          'retailPrice': double.tryParse(v.retailController.text.trim()) ?? 0,
          'sizeRows': sizeRows,
          // pass picked files so we can upload after product is saved
          'pickedFiles': v.pickedImageFiles,
        });
      }

      // save product + variants + sizes to Supabase
      // service returns null on success, error string on failure
      String? error = await _service.addProduct(
        productName: _productNameController.text.trim(),
        brandName: _selectedBrand!,
        categoryName: _selectedCategory!,
        description: _detailsController.text.trim(),
        variants: variantsData,
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

      // ── UPLOAD IMAGES ──
      // fetch the newly created variants to get their IDs
      // then upload images for each variant
      try {
        List<dynamic> newVariants = await _supabase
            .from('product_variant')
            .select('variant_id')
            .order('variant_id', ascending: false)
            .limit(_variants.length);

        // newVariants are in reverse order (newest first)
        // so we reverse to match our _variants order
        List<dynamic> orderedVariants = newVariants.reversed.toList();

        for (int i = 0; i < _variants.length; i = i + 1) {
          List<PlatformFile> files = _variants[i].pickedImageFiles;

          if (files.isEmpty) continue;

          int variantId = orderedVariants[i]['variant_id'] as int;

          // upload images and get public URLs
          List<String> imageUrls = await _uploadImages(variantId, files);

          // save image URLs to product_image table
          for (int j = 0; j < imageUrls.length; j = j + 1) {
            await _supabase.from('product_image').insert({
              'variant_id': variantId,
              'image_url': imageUrls[j],
              // first image is the primary image
              'is_primary': j == 0,
            });
          }
        }
      } catch (imageError) {
        // images failed but product was saved — not critical
        print('Image upload error: $imageError');
      }

      // tell inventory_screen to refresh
      widget.onProductAdded();

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
      print('_saveProduct error: $error');
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
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

  Widget _buildNumericField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    bool allowDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      ),
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
  // BUILD IMAGE UPLOAD BOX
  // clickable — opens file picker
  // shows previews of picked images
  // ================================================
  Widget _buildImageUploadBox(int variantIndex) {
    List<PlatformFile> pickedFiles =
        _variants[variantIndex].pickedImageFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // clickable upload area
        GestureDetector(
          onTap: () => _pickImages(variantIndex),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.upload_outlined,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                SizedBox(width: 8),
                Text(
                  'Click to browse images',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),

        // image previews — shown after picking
        if (pickedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(pickedFiles.length, (int imgIndex) {
              PlatformFile file = pickedFiles[imgIndex];

              return Stack(
                children: [

                  // image preview box
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: file.bytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              file.bytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : file.path != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(file.path!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.image_outlined,
                                size: 24,
                                color: Color(0xFF9CA3AF),
                              ),
                  ),

                  // remove button on top right
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeImage(variantIndex, imgIndex),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // primary badge on first image
                  if (imgIndex == 0)
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Main',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),

          // count hint
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${pickedFiles.length}/4 images selected',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ],
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

        // show loading spinner while brands load
        _isLoadingDropdowns
            ? const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2563EB),
                  ),
                ),
              )
            : _buildDropdown(
                hint: 'Select Brand',
                value: _selectedBrand,
                items: _brands,
                onChanged: (v) => setState(() => _selectedBrand = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please select a brand' : null,
              ),

        const SizedBox(height: 14),

        _buildLabel('Category'),

        _isLoadingDropdowns
            ? const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2563EB),
                  ),
                ),
              )
            : _buildDropdown(
                hint: 'Select Category',
                value: _selectedCategory,
                items: _categories,
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please select a category'
                        : null,
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

          // variant header + remove button
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
              if (_variants.length > 1)
                GestureDetector(
                  onTap: () => _removeVariant(variantIndex),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

         _buildLabel('Color Name'),
          _buildTextField(
            controller: variant.colorNameController,
            hint: 'e.g. White, Black, Red',
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter a color name';
              }
              final String trimmed = v.trim();
              if (trimmed.length < 2) {
                return 'Color name is too short';
              }
              if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(trimmed)) {
                return 'Color name can only have letters, spaces, and hyphens';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),
          
          // ── IMAGE UPLOAD — now clickable! ──
          _buildLabel('Upload Image'),
          const Text(
            'JPG or PNG format • Max 4 images per color',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          _buildImageUploadBox(variantIndex),

          const SizedBox(height: 14),

          _buildLabel('Cost'),
          _buildNumericField(
            controller: variant.costController,
            hint: 'Enter Cost Price',
            allowDecimal: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a cost price';
              final double? parsed = double.tryParse(v);
              if (parsed == null) return 'Enter a valid number';
              if (parsed <= 0) return 'Cost price must be greater than ₱0';
              return null;
            },
          ),

          const SizedBox(height: 14),

          _buildLabel('Retail'),
          _buildNumericField(
            controller: variant.retailController,
            hint: 'Enter Retail Price',
            allowDecimal: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a retail price';
              final double? parsed = double.tryParse(v);
              if (parsed == null) return 'Enter a valid number';
              if (parsed <= 0) return 'Retail price must be greater than ₱0';
              return null;
            },
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

                    // size field
                    Expanded(
                      child: TextFormField(
                        controller: row.sizeController,
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration('Enter Size').copyWith(
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // stock field
                    Expanded(
                      child: TextFormField(
                        controller: row.stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration('Enter Stock').copyWith(
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // delete row button
                    ElevatedButton(
                      onPressed: () => _removeSizeRow(variantIndex, rowIndex),
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

                    // add row button
                    ElevatedButton(
                      onPressed: () => _addSizeRow(variantIndex),
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
  // VARIANT LIST SECTION
  // ================================================
  Widget _buildVariantListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading('Variant List'),
        Column(
          children: List.generate(
            _variants.length,
            (index) => _buildVariantBlock(index),
          ),
        ),
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
        clipBehavior: Clip.antiAlias,
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

              // ── HEADER ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Add Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fill in the product details below',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 20),
                    Divider(color: Color(0xFFE5E7EB), height: 1),
                  ],
                ),
              ),

              // ── SCROLLABLE CONTENT ──
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

              // ── BOTTOM BUTTONS ──
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
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
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
                    ElevatedButton(
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
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
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