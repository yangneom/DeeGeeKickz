import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/product_detail_model.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/customer/product_detail/write_review_form.dart';

/// Write Review Screen.
///
/// Pushed from ProductReviewsSection's "Write a Review" button.
/// On submit: pops back to the product detail screen and shows
/// a success SnackBar.
///
/// Layout:
/// - Mobile  (<768px): single scrollable column, full width.
/// - Desktop (≥768px): centred narrow column (max 680px) with
///   a left-aligned back button — mirrors the editorial feel of
///   the rest of the site.
class WriteReviewScreen extends StatelessWidget {
  final ProductDetailModel product;

  const WriteReviewScreen({super.key, required this.product});

  static const double _mdBreakpoint = 768;
  static const double _formMaxWidth = 680;

  void _onSubmit(
    BuildContext context, {
    required double rating,
    required String title,
    required String body,
    required List<PlatformFile> photos,
  }) {
    // Pop back to product detail
    Navigator.of(context).pop();

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'REVIEW SUBMITTED — THANK YOU!',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      // Custom top bar — back arrow + title + product name
      appBar: _ReviewAppBar(productName: product.name),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _mdBreakpoint;
            final hPad = isDesktop ? 48.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? _formMaxWidth : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page heading
                      const Text(
                        'WRITE A\nREVIEW',
                        style: TextStyle(
                          fontFamily: 'Archivo Narrow',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          height: 1.05,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Thin divider line — signature design touch
                      Container(
                        width: 48,
                        height: 3,
                        color: Colors.black,
                      ),

                      const SizedBox(height: 32),

                      // The form
                      WriteReviewForm(
                        productName: product.name,
                        onSubmit: ({
                          required double rating,
                          required String title,
                          required String body,
                          required List<PlatformFile> photos,
                        }) =>
                            _onSubmit(
                          context,
                          rating: rating,
                          title: title,
                          body: body,
                          photos: photos,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      // Keep bottom nav consistent with the rest of the customer flow
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Custom AppBar ────────────────────────────────────────────────

class _ReviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String productName;

  const _ReviewAppBar({required this.productName});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCFC4C5), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),

          const SizedBox(width: 8),

          // Title + product name
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REVIEW',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.black,
                  ),
                ),
                Text(
                  productName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: Color(0xFF4C4546),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Logo — keeps brand presence on a non-standard screen
          const Text(
            'DEEGEEKICKZ',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.black,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}