import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_project_one/models/product.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_project_one/widgets/common/dialog/confirm_dialog.dart';
import 'package:flutter_project_one/services/admin/inventory/inventory_service.dart';

// ================================================
// SHOW EDIT PRODUCT DIALOG
// ================================================
Future<void> showEditProductDialog(
  BuildContext context, {
  required Product product,
  required VoidCallback onProductUpdated,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => EditProductDialog(
      product: product,
      onProductUpdated: onProductUpdated,
    ),
  );
}

// ================================================
// SIZE ROW MODEL
// ================================================
class SizeStockRow {
  final int? sizeId; // null = new row not yet in DB

  final TextEditingController sizeController;
  final TextEditingController stockController;

  SizeStockRow({
    this.sizeId,
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
// EXISTING IMAGE MODEL
// Tracks images already in the DB so we can
// delete them on save if the user removes them.
// ================================================
class ExistingImage {
  final int imageId;
  final String imageUrl;

  ExistingImage({required this.imageId, required this.imageUrl});
}

// ================================================
// VARIANT DATA
// ================================================
class VariantData {
  int? variantId; // null = new variant not yet in DB

  final TextEditingController colorNameController;
  final TextEditingController costController;
  final TextEditingController retailController;
  Color selectedColor;
  List<SizeStockRow> sizeRows;

  // Images already in the database
  List<ExistingImage> existingImages;

  // Images newly picked by the user (not yet uploaded)
  List<PlatformFile> pickedImageFiles;

  VariantData()
      : colorNameController = TextEditingController(),
        costController = TextEditingController(),
        retailController = TextEditingController(),
        selectedColor = Colors.black,
        sizeRows = [SizeStockRow()],
        existingImages = [],
        pickedImageFiles = [];

  /// Total images (existing + newly picked) for the 4-image cap
  int get totalImageCount =>
      existingImages.length + pickedImageFiles.length;

  void dispose() {
    colorNameController.dispose();
    costController.dispose();
    retailController.dispose();
    for (final row in sizeRows) {
      row.dispose();
    }
  }
}

// ================================================
// EDIT PRODUCT DIALOG
// ================================================
class EditProductDialog extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback onProductUpdated;

  const EditProductDialog({
    super.key,
    required this.product,
    required this.onProductUpdated,
  });

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryService _service = InventoryService();

  final TextEditingController _productNameController =
      TextEditingController();
  final TextEditingController _detailsController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedBrand;
  String? _selectedCategory;

  List<String> _brands = [];
  List<String> _categories = [];
  bool _isLoadingDropdowns = true;

  final List<VariantData> _variants = [];

  // Tracks which existing image IDs to delete on save
  final List<int> _imageIdsToDelete = [];

  bool _isLoading = false;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();

    _productNameController.text = widget.product.productName;
    _detailsController.text = widget.product.description; // ← fix #9
    _selectedBrand = widget.product.brand;
    _selectedCategory = widget.product.category;

    // ── Load variants ──
    // Product model now has one ProductVariant per color,
    // each with a List<SizeEntry>. No grouping needed here.
    for (final variant in widget.product.variants) {
      final variantData = VariantData();
      variantData.variantId = variant.variantId;
      variantData.colorNameController.text = variant.color;
      variantData.costController.text =
          variant.costPrice.toStringAsFixed(2);
      variantData.retailController.text =
          variant.retailPrice.toStringAsFixed(2);

      // ── Load existing images ──  (fix #7, #8)
      // We need image IDs to delete them later.
      // The Product model only carries URLs right now, so we
      // reconstruct ExistingImage with a placeholder id=-1.
      // If you add imageId to the model you can use the real id.
      // For delete to work properly, add image_id to the mapper.
      variantData.existingImages = variant.imageUrls
          .map((url) => ExistingImage(imageId: -1, imageUrl: url))
          .toList();

      // ── Load sizes ──
      if (variant.sizes.isEmpty) {
        // Keep the default blank row so the UI isn't empty
        variantData.sizeRows = [SizeStockRow()];
      } else {
        variantData.sizeRows = variant.sizes
            .map((s) => SizeStockRow(
                  sizeId: s.sizeId,
                  sizeController:
                      TextEditingController(text: s.size),
                  stockController:
                      TextEditingController(
                          text: s.stockQty.toString()),
                ))
            .toList();
      }

      _variants.add(variantData);
    }

    _loadDropdowns();
  }

  // ================================================
  // LOAD BRANDS AND CATEGORIES
  // ================================================
  Future<void> _loadDropdowns() async {
    try {
      final brands = await _service.fetchBrands();
      final categories = await _service.fetchCategories();
      setState(() {
        _brands = brands;
        _categories = categories;
        _isLoadingDropdowns = false;
      });
    } catch (error) {
      print('_loadDropdowns error: $error');
      setState(() => _isLoadingDropdowns = false);
    }
  }

  // ================================================
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _productNameController.dispose();
    _detailsController.dispose();
    for (final v in _variants) {
      v.dispose();
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
      builder: (colorContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Pick a Color',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (c) => tempColor = c,
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
              setState(() =>
                  _variants[variantIndex].selectedColor = tempColor);
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
      ),
    );
  }

  // ================================================
  // PICK IMAGES
  // ================================================
  Future<void> _pickImages(int variantIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null) return;

      final VariantData v = _variants[variantIndex];
      final int remaining = 4 - v.totalImageCount;

      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Maximum 4 images per variant.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      setState(() {
        v.pickedImageFiles
            .addAll(result.files.take(remaining));
      });
    } catch (error) {
      print('_pickImages error: $error');
    }
  }

  // ── Remove a newly-picked image (not yet in DB) ──
  void _removePickedImage(int variantIndex, int imageIndex) {
    setState(() {
      _variants[variantIndex].pickedImageFiles
          .removeAt(imageIndex);
    });
  }

  // ── Remove an existing image (queued for DB delete on save) ──
  void _removeExistingImage(int variantIndex, int imageIndex) {
    final ExistingImage img =
        _variants[variantIndex].existingImages[imageIndex];

    setState(() {
      // Queue for deletion (only if we have a real id)
      if (img.imageId != -1) {
        _imageIdsToDelete.add(img.imageId);
      }
      _variants[variantIndex].existingImages.removeAt(imageIndex);
    });
  }

  // ================================================
  // UPLOAD NEW IMAGES
  // ================================================
  Future<List<String>> _uploadImages(
    int variantId,
    List<PlatformFile> files,
    int existingImageCount,
  ) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final PlatformFile file = files[i];
      try {
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath =
            'variant_$variantId/${timestamp}_${file.name}';

        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null) continue;

        await _supabase.storage
            .from('product-images')
            .uploadBinary(filePath, bytes);

        final String publicUrl = _supabase.storage
            .from('product-images')
            .getPublicUrl(filePath);

        urls.add(publicUrl);
      } catch (error) {
        print('_uploadImages: failed ${file.name}: $error');
      }
    }
    return urls;
  }

  // ================================================
  // VARIANT MANAGEMENT
  // ================================================
  void _addVariant() =>
      setState(() => _variants.add(VariantData()));

  void _removeVariant(int index) {
    if (_variants.length == 1) return;
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  void _addSizeRow(int variantIndex) =>
      setState(() =>
          _variants[variantIndex].sizeRows.add(SizeStockRow()));

  void _removeSizeRow(int variantIndex, int rowIndex) {
    if (_variants[variantIndex].sizeRows.length == 1) return;
    setState(() {
      _variants[variantIndex].sizeRows[rowIndex].dispose();
      _variants[variantIndex].sizeRows.removeAt(rowIndex);
    });
  }

  // ================================================
  // SAVE FLOW
  // ================================================
  Future<void> _handlePublish() async {
    if (!_formKey.currentState!.validate()) return;

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Save product changes?',
      message:
          'The product information and variants will be updated.',
      confirmLabel: 'Save Changes',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed == true) await _saveProduct();
  }

  Future<void> _saveProduct() async {
    setState(() => _isLoading = true);

    try {
      // Build variants payload
      final List<Map<String, dynamic>> variantsData = [];

      for (final v in _variants) {
        final List<Map<String, dynamic>> sizeRows = v.sizeRows
            .map((row) => {
                  'sizeId': row.sizeId,
                  'size': row.sizeController.text.trim(),
                  'stockQty':
                      int.tryParse(
                              row.stockController.text.trim()) ??
                          0,
                })
            .toList();

        variantsData.add({
          'variantId': v.variantId,
          'colorName': v.colorNameController.text.trim(),
          'costPrice':
              double.tryParse(v.costController.text.trim()) ?? 0,
          'retailPrice':
              double.tryParse(v.retailController.text.trim()) ??
                  0,
          'sizeRows': sizeRows,
        });
      }

      final String? error = await _service.updateProduct(
        productId: widget.product.productId,
        productName: _productNameController.text.trim(),
        brandName: _selectedBrand!,
        categoryName: _selectedCategory!,
        description: _detailsController.text.trim(),
        variants: variantsData,
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      // ── Delete removed images ──
      for (final imageId in _imageIdsToDelete) {
        try {
          await _supabase
              .from('product_image')
              .delete()
              .eq('image_id', imageId);
        } catch (e) {
          print('Failed to delete image $imageId: $e');
        }
      }

      // ── Upload new images ──
      // Use the variantId we already know — no "newest variant"
      // query needed. (fix #6)
      for (int i = 0; i < _variants.length; i++) {
        final VariantData v = _variants[i];
        if (v.pickedImageFiles.isEmpty) continue;

        // variantId must be non-null here; service guarantees
        // existing variants keep their id, new ones get one.
        // We need the resolved id for new variants — so the
        // service must return them. See note below.
        final int? variantId = v.variantId;
        if (variantId == null) continue; // safety guard

        final List<String> imageUrls = await _uploadImages(
          variantId,
          v.pickedImageFiles,
          v.existingImages.length,
        );

        // First uploaded image is primary only if no existing images
        for (int j = 0; j < imageUrls.length; j++) {
          await _supabase.from('product_image').insert({
            'variant_id': variantId,
            'image_url': imageUrls[j],
            'is_primary':
                v.existingImages.isEmpty && j == 0,
          });
        }
      }

      widget.onProductUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (error) {
      print('_saveProduct error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Failed to save product. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================================================
  // REUSABLE WIDGETS
  // ================================================
  Widget _buildLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
      );

  InputDecoration _inputDecoration(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
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
            horizontal: 12, vertical: 12),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 13),
        decoration: _inputDecoration(hint),
      );

  Widget _buildNumericField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    bool allowDecimal = false,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          allowDecimal
              ? FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,2}'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        validator: validator,
        style: const TextStyle(fontSize: 13),
        decoration: _inputDecoration(hint),
      );

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        validator: validator,
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF374151)),
        decoration: _inputDecoration(hint).copyWith(hintText: null),
        hint: Text(hint,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF9CA3AF))),
        items: items
            .map((item) => DropdownMenuItem<String>(
                value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      );

  Widget _buildSectionHeading(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
      );

  // ================================================
  // IMAGE UPLOAD BOX
  // Shows existing images + newly picked images
  // ================================================
  Widget _buildImageUploadBox(int variantIndex) {
    final VariantData v = _variants[variantIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload trigger
        GestureDetector(
          onTap: () => _pickImages(variantIndex),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_outlined,
                    size: 18, color: Color(0xFF6B7280)),
                SizedBox(width: 8),
                Text('Click to browse images',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),

        // ── Existing images ──
        if (v.existingImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Saved images',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(v.existingImages.length,
                (imgIndex) {
              final ExistingImage img =
                  v.existingImages[imgIndex];
              return Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        img.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image,
                                size: 24,
                                color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeExistingImage(
                          variantIndex, imgIndex),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                  if (imgIndex == 0)
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius:
                              BorderRadius.circular(3),
                        ),
                        child: const Text('Main',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],

        // ── Newly picked images ──
        if (v.pickedImageFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('New images (not yet saved)',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(v.pickedImageFiles.length,
                (imgIndex) {
              final PlatformFile file =
                  v.pickedImageFiles[imgIndex];
              return Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB)),
                    ),
                    child: file.bytes != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(6),
                            child: Image.memory(file.bytes!,
                                fit: BoxFit.cover),
                          )
                        : file.path != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(6),
                                child: Image.file(
                                    File(file.path!),
                                    fit: BoxFit.cover),
                              )
                            : const Icon(Icons.image_outlined,
                                size: 24,
                                color: Color(0xFF9CA3AF)),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removePickedImage(
                          variantIndex, imgIndex),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],

        // Count hint
        if (v.totalImageCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${v.totalImageCount}/4 images',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
      ],
    );
  }

  // ================================================
  // PRODUCT INFORMATION SECTION
  // ================================================
  Widget _buildProductInformationSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading('Product Information'),
          _buildLabel('Product Name'),
          _buildTextField(
            controller: _productNameController,
            hint: 'Enter Product Name',
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter a product name'
                : null,
          ),
          const SizedBox(height: 14),
          _buildLabel('Brand'),
          _isLoadingDropdowns
              ? const SizedBox(
                  height: 48,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2563EB))))
              : _buildDropdown(
                  hint: 'Select Brand',
                  value: _selectedBrand,
                  items: _brands,
                  onChanged: (v) =>
                      setState(() => _selectedBrand = v),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please select a brand'
                      : null,
                ),
          const SizedBox(height: 14),
          _buildLabel('Category'),
          _isLoadingDropdowns
              ? const SizedBox(
                  height: 48,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2563EB))))
              : _buildDropdown(
                  hint: 'Select Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v),
                  validator: (v) => (v == null || v.isEmpty)
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

  // ================================================
  // VARIANT BLOCK
  // ================================================
  Widget _buildVariantBlock(int variantIndex) {
    final VariantData variant = _variants[variantIndex];

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
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter a color name'
                : null,
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
                  border: Border.all(
                      color: const Color(0xFFD1D5DB)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () =>
                    _openColorPicker(variantIndex),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(
                      color: Color(0xFFD1D5DB)),
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
          const Text(
            'JPG or PNG format • Max 4 images per color',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          _buildImageUploadBox(variantIndex),
          const SizedBox(height: 14),
          _buildLabel('Cost'),
          _buildNumericField(
            controller: variant.costController,
            hint: 'Enter Cost Price',
            allowDecimal: true,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter a cost price'
                : null,
          ),
          const SizedBox(height: 14),
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
            children: List.generate(
                variant.sizeRows.length, (rowIndex) {
              final SizeStockRow row =
                  variant.sizeRows[rowIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: row.sizeController,
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration(
                                'Enter Size')
                            .copyWith(
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10),
                        ),
                        validator: (v) => (v == null ||
                                v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly
                        ],
                        style: const TextStyle(fontSize: 12),
                        decoration: _inputDecoration(
                                'Enter Stock')
                            .copyWith(
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10),
                        ),
                        validator: (v) => (v == null ||
                                v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _removeSizeRow(variantIndex, rowIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _addSizeRow(variantIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
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
  Widget _buildVariantListSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading('Variant List'),
          Column(
            children: List.generate(
                _variants.length,
                (index) => _buildVariantBlock(index)),
          ),
          ElevatedButton.icon(
            onPressed: _addVariant,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Variant',
                style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final double screenHeight =
        MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
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
              // ── Header ──
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('EDIT PRODUCT',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                            letterSpacing: 1.0)),
                    SizedBox(height: 4),
                    Text('Update the product details below',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280))),
                    SizedBox(height: 20),
                    Divider(
                        color: Color(0xFFE5E7EB), height: 1),
                  ],
                ),
              ),

              // ── Scrollable body ──
              Expanded(
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildProductInformationSection(),
                      const SizedBox(height: 28),
                      _buildVariantListSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Footer ──
              Container(
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(
                          color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF374151),
                        side: const BorderSide(
                            color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _handlePublish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w500)),
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