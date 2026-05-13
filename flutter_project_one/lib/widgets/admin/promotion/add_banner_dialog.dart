import 'package:flutter/material.dart';

// ================================================
// ADD BANNER DIALOG
//
// This dialog lets the admin upload a banner image
// and pick Active or Inactive status.
//
// Features:
//   - Upload area (click to pick image)
//   - Image crop preview — the image is cropped
//     to fit a 16:5 banner ratio using BoxFit.cover
//   - Status radio buttons (Active / Inactive)
//   - Cancel and Upload Banner buttons
//
// How to open:
//   showAddBannerDialog(context);
// ================================================

// ================================================
// SHOW FUNCTION
// Call this from BannersTable to open the dialog
// ================================================
Future<Map<String, dynamic>?> showAddBannerDialog(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const AddBannerDialog();
    },
  );
}

// ================================================
// STATEFUL WIDGET
// We need state because the user can:
//   - toggle status
//   - pick an image (simulated with a flag)
// ================================================
class AddBannerDialog extends StatefulWidget {
  const AddBannerDialog({super.key});

  @override
  State<AddBannerDialog> createState() => _AddBannerDialogState();
}

class _AddBannerDialogState extends State<AddBannerDialog> {

  // ── STATUS ──
  // 'Active' or 'Inactive'
  // default is Active when opening the dialog
  String _selectedStatus = 'Active';

  // ── IMAGE PICKED ──
  // We simulate image picking with a bool flag
  // In a real app this would be a File or Uint8List
  // from image_picker package
  bool _hasImage = false;

  // ── FAKE IMAGE URL ──
  // We use a placeholder to simulate a picked image
  // Replace this with the actual picked image later
  final String _fakeImageUrl =
      'https://via.placeholder.com/960x300/1a1a2e/ffffff?text=Banner+Preview';

  // ================================================
  // SIMULATE PICKING AN IMAGE
  // In a real app: use image_picker package
  // For now: just set _hasImage to true
  // ================================================
  void _pickImage() {
    setState(() {
      // pretend the user picked an image
      _hasImage = true;
    });
  }

  // ================================================
  // HANDLE UPLOAD BUTTON
  // Returns the data back to BannersTable
  // so the table can add it to the list
  // ================================================
  void _handleUpload() {

    // make sure user picked an image first
    if (_hasImage == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a banner image first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // build the result data to send back
    Map<String, dynamic> result = {
      'imageUrl': _fakeImageUrl,
      'uploadDate': _getFormattedDate(),
      'status': _selectedStatus,
    };

    // close the dialog and return the result
    Navigator.pop(context, result);
  }

  // ================================================
  // GET FORMATTED DATE
  // Returns today's date in "Mar 1, 2026" format
  // We build this manually with basic code
  // ================================================
  String _getFormattedDate() {

    // list of month names in order
    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    // get today's date
    DateTime now = DateTime.now();

    // build the string: "Mar 1, 2026"
    String month = months[now.month - 1];
    String day = now.day.toString();
    String year = now.year.toString();

    return '$month $day, $year';
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Promotion Banner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                // X close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
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

            // ── UPLOAD AREA ──
            // If no image picked → show dashed upload box
            // If image picked → show cropped preview
            GestureDetector(
              onTap: _pickImage,
              child: _hasImage == false
                  ? _buildUploadPlaceholder()
                  : _buildCroppedPreview(),
            ),

            // ── CROP NOTE ──
            // Only show when image is picked
            if (_hasImage == true)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Image is auto-cropped to fit the banner ratio (16:5).',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── STATUS LABEL ──
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 8),

            // ── STATUS RADIO BUTTONS ──
            Row(
              children: [

                // Active radio
                _buildRadio(
                  label: 'Active',
                  value: 'Active',
                ),

                const SizedBox(width: 24),

                // Inactive radio
                _buildRadio(
                  label: 'Inactive',
                  value: 'Inactive',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── BOTTOM BUTTONS ──
            Row(
              children: [

                // Cancel button — takes up half the width
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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

                // Upload Banner button — takes up half the width
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Upload Banner',
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
  // Shows the dashed box with upload icon
  // ================================================
  Widget _buildUploadPlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD1D5DB),
          // dashed border using strokeAlign trick
          // simple approach: just use a solid light border
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Upload arrow icon
          Icon(
            Icons.upload_outlined,
            size: 28,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 8),
          // Click to upload text
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
          // Size hint
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
  // BUILD CROPPED PREVIEW
  // Shows the picked image cropped to 16:5 ratio
  //
  // HOW CROPPING WORKS:
  // We use AspectRatio(16/5) to lock the container
  // to a wide banner shape.
  // Then BoxFit.cover fills the space and crops
  // whatever doesn't fit — just like object-fit:cover in CSS.
  // The image stays centered and fills edge to edge.
  // ================================================
  Widget _buildCroppedPreview() {
    return Stack(
      children: [

        // ── THE CROPPED IMAGE ──
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            // 16:5 ratio — wide banner shape
            aspectRatio: 16 / 5,
            child: Image.network(
              _fakeImageUrl,
              width: double.infinity,
              // BoxFit.cover = fill the box and crop the rest
              // This is what makes the image "fit" the banner
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                // if image fails to load show dark placeholder
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

        // ── CHANGE IMAGE BUTTON ──
        // Floating button on top of the preview
        // so user can pick a different image
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Change image',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
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
  // A single radio option (Active or Inactive)
  // ================================================
  Widget _buildRadio({
    required String label,
    required String value,
  }) {
    return GestureDetector(
      onTap: () {
        // when tapped update selected status
        setState(() {
          _selectedStatus = value;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // the radio circle
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
          // the label text
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