import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../../../services/admin/promotionDiscount/banner_service.dart';

// ================================================
// ADD BANNER DIALOG
//
// This dialog lets the admin upload a banner image.
// New banners always upload as "Active" — pausing a
// banner (setting it Inactive) is an editing concern
// only, handled in EditBannerDialog.
//
// Features:
//   - Upload area (file_picker, Flutter Web)
//   - Real interactive crop step locked to 16:5
//     using crop_your_image
//   - Cancel and Upload Banner buttons
//
// How to open:
//   showAddBannerDialog(context);
// ================================================

// ================================================
// SHOW FUNCTION
// Call this from BannersTable to open the dialog.
// Returns `true` on a successful upload (the table
// re-fetches from Supabase rather than receiving a
// Map back).
// ================================================
Future<bool?> showAddBannerDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const AddBannerDialog();
    },
  );
}

// ================================================
// STATEFUL WIDGET
// ================================================
class AddBannerDialog extends StatefulWidget {
  const AddBannerDialog({super.key});

  @override
  State<AddBannerDialog> createState() => _AddBannerDialogState();
}

class _AddBannerDialogState extends State<AddBannerDialog> {
  // New banners always go live immediately as Active.
  static const String _uploadStatus = 'Active';

  // ── IMAGE PICKED (raw, pre-crop) ──
  Uint8List? _pickedBytes;
  String _fileExt = 'jpg';

  // ── CROPPED RESULT (what actually gets uploaded) ──
  Uint8List? _croppedBytes;

  // ── CROP STEP STATE ──
  bool _isCropping = false;
  final CropController _cropController = CropController();

  // ── UPLOAD STATE ──
  bool _isUploading = false;

  final BannerService _bannerService = BannerService();

  // ================================================
  // PICK IMAGE
  // Opens file_picker (Web) with bytes, then enters
  // crop mode locked to 16:5.
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
      _croppedBytes = null;
      _isCropping = true;
    });
  }

  // ================================================
  // CONFIRM CROP
  // Triggers CropController.crop(); result arrives
  // via the Crop widget's onCropped callback.
  // ================================================
  void _confirmCrop() {
    _cropController.crop();
  }

  // ================================================
  // HANDLE CROP RESULT
  // ================================================
  void _handleCropResult(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        setState(() {
          _croppedBytes = croppedImage;
          _isCropping = false;
        });
        break;
      case CropFailure(:final cause):
        setState(() {
          _isCropping = false;
        });
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
  // HANDLE UPLOAD BUTTON
  // ================================================
  Future<void> _handleUpload() async {
    if (_croppedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a banner image first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final String? error = await _bannerService.addBanner(
      imageBytes: _croppedBytes!,
      fileExt: _fileExt,
      status: _uploadStatus,
    );

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload banner: $error'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  // ================================================
  // BUILD
  // ================================================
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
            // ── TITLE ──
            const Text(
              'Add Promotion Banner',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upload a new banner for the homepage slider.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 24),

            // ── UPLOAD BANNER IMAGE LABEL ──
            const Text(
              'Upload Banner Image',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 8),

            // ── UPLOAD AREA / CROP STEP / PREVIEW ──
            if (_isCropping)
              _buildCropStep()
            else if (_croppedBytes == null)
              GestureDetector(
                onTap: _pickImage,
                child: _buildUploadPlaceholder(),
              )
            else
              _buildCroppedPreview(),

            // ── CROP NOTE ──
            if (_croppedBytes != null && !_isCropping)
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

            const SizedBox(height: 8),

            // ── LIVE-ON-UPLOAD NOTE ──
            // Replaces the old status radio group — new banners always
            // go live immediately. Pausing happens later, via Edit.
            const Text(
              'This banner will go live on the homepage immediately after upload. '
              'You can pause it later from the Edit dialog.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),

            const SizedBox(height: 28),

            // ── BOTTOM BUTTONS ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isUploading ? null : () => Navigator.pop(context),
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
                    onPressed: _isUploading ? null : _handleUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUploading
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
                                                        'Upload & Publish Banner',
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
  // BUILD UPLOAD PLACEHOLDER
  // ================================================
  Widget _buildUploadPlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_outlined,
            size: 28,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Click to upload',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ' or drag and drop',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Recommended size: 1920x700 JPG or PNG',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD CROP STEP
  // Real interactive crop UI, locked to 16:5, shown
  // right after a file is picked and before upload.
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
              // AUDIT FIX: was 16/5, matching neither of hero_section's
              // two real display ratios (21/9 desktop, 4/3 mobile) —
              // now matches Desktop exactly, since that's the primary
              // experience and closest in shape to the original value.
              // Mobile's own, separate 4/3 crop remains an intentional,
              // documented design choice in hero_section.dart itself.
              aspectRatio: 21 / 9,
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
                  'Choose Different Image',
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
  // BUILD CROPPED PREVIEW
  // Shows the final cropped bytes at the 16:5 ratio.
  // ================================================
  Widget _buildCroppedPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
            aspectRatio: 21 / 9,
            child: Image.memory(
              _croppedBytes!,
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
}