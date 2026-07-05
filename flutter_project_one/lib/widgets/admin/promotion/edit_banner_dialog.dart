import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../../../models/promotion_banner_model.dart';
import '../../../services/admin/promotionDiscount/banner_service.dart';

// ================================================
// EDIT BANNER DIALOG
//
// Same visual shell as AddBannerDialog, titled
// "Edit Promotion Banner". Pre-filled with the
// existing banner's image + status. The image is
// only replaced if the admin taps "Change image"
// and completes a new crop — otherwise the existing
// imageUrl is kept unchanged on save.
//
// How to open:
//   showEditBannerDialog(context, banner: banner);
// ================================================

Future<bool?> showEditBannerDialog(
  BuildContext context, {
  required PromotionBanner banner,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return EditBannerDialog(banner: banner);
    },
  );
}

class EditBannerDialog extends StatefulWidget {
  final PromotionBanner banner;

  const EditBannerDialog({super.key, required this.banner});

  @override
  State<EditBannerDialog> createState() => _EditBannerDialogState();
}

class _EditBannerDialogState extends State<EditBannerDialog> {
  late String _selectedStatus;

  // ── NEW IMAGE (only set if admin replaces it) ──
  Uint8List? _pickedBytes;
  Uint8List? _newCroppedBytes;
  String _fileExt = 'jpg';

  bool _isCropping = false;
  final CropController _cropController = CropController();

  bool _isSaving = false;

  final BannerService _bannerService = BannerService();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.banner.status;
  }

  // ================================================
  // PICK IMAGE (replace flow)
  // ================================================
  Future<void> _pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _pickedBytes = file.bytes;
      _fileExt = (file.extension ?? 'jpg').toLowerCase();
      _newCroppedBytes = null;
      _isCropping = true;
    });
  }

  void _confirmCrop() {
    _cropController.crop();
  }

  void _handleCropResult(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        setState(() {
          _newCroppedBytes = croppedImage;
          _isCropping = false;
        });
        break;
      case CropFailure(:final cause):
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not crop image: $cause'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        break;
    }
  }

  // ================================================
  // HANDLE SAVE
  // ================================================
  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    final String? error = await _bannerService.updateBanner(
      bannerId: widget.banner.bannerId,
      newImageBytes: _newCroppedBytes,
      fileExt: _newCroppedBytes != null ? _fileExt : null,
      status: _selectedStatus,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $error'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TITLE ROW ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Promotion Banner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: _isSaving ? null : () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Banner Image',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 8),

            if (_isCropping) _buildCropStep() else _buildImagePreview(),

            if (!_isCropping)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Image is cropped to fit the banner ratio (16:5).',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            const Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                _buildRadio(label: 'Active', value: 'Active'),
                const SizedBox(width: 24),
                _buildRadio(label: 'Inactive', value: 'Inactive'),
              ],
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD CROP STEP
  // ================================================
  Widget _buildCropStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            height: 220,
            color: const Color(0xFF111827),
            child: Crop(
              controller: _cropController,
              image: _pickedBytes!,
              aspectRatio: 16 / 5,
              baseColor: const Color(0xFF111827),
              maskColor: Colors.black.withOpacity(0.55),
              onCropped: _handleCropResult,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isCropping = false;
                    _pickedBytes = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _confirmCrop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm Crop',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================
  // BUILD IMAGE PREVIEW
  // Shows the new cropped image if one was picked,
  // otherwise the existing banner image via
  // Image.network. "Change image" floating button
  // re-opens the pick → crop flow.
  // ================================================
  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 5,
            child: _newCroppedBytes != null
                ? Image.memory(
                    _newCroppedBytes!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    widget.banner.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: const Color(0xFF1a1a2e),
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.white54,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Change image',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD RADIO BUTTON
  // ================================================
  Widget _buildRadio({
    required String label,
    required String value,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _selectedStatus,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                });
              }
            },
            activeColor: const Color(0xFF2563EB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}