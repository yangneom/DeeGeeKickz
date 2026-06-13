import 'package:flutter/material.dart';

import '../../../models/product_detail_model.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/product_detail/product_image_gallery.dart';
import '../../../widgets/customer/product_detail/product_info_section.dart';
import '../../../widgets/customer/product_detail/product_specs_section.dart';
import '../../../widgets/customer/product_detail/product_reviews_section.dart';

/// Product Detail Screen.
///
/// Accepts an optional [discountPercent] and [originalPrice] so promo
/// products show the sale price on the detail screen too.
/// When not discounted, these are null and the screen behaves normally.
class ProductDetailScreen extends StatelessWidget {
  final ProductDetailModel? product;
  final int? discountPercent;
  final double? originalPrice;

  const ProductDetailScreen({
    super.key,
    this.product,
    this.discountPercent,
    this.originalPrice,
  });

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final detail = product ?? mockVortexApexV1;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'shop'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero: gallery + info ─────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;

                        return Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 0),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child: isDesktop
                                ? _DesktopHero(
                                    product: detail,
                                    discountPercent: discountPercent,
                                    originalPrice: originalPrice,
                                  )
                                : _MobileHero(
                                    product: detail,
                                    discountPercent: discountPercent,
                                    originalPrice: originalPrice,
                                  ),
                          ),
                        );
                      },
                    ),

                    // ── Specs ────────────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child: ProductSpecsSection(product: detail),
                          ),
                        );
                      },
                    ),

                    // ── Reviews ──────────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child:
                                ProductReviewsSection(product: detail),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Desktop: gallery left (58%) + info right (42%) ───────────────

class _DesktopHero extends StatelessWidget {
  final ProductDetailModel product;
  final int? discountPercent;
  final double? originalPrice;

  const _DesktopHero({
    required this.product,
    this.discountPercent,
    this.originalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 58,
          child: ProductImageGallery(imageUrls: product.imageUrls),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 42,
          child: ProductInfoSection(
            product: product,
            discountPercent: discountPercent,
            originalPrice: originalPrice,
          ),
        ),
      ],
    );
  }
}

// ── Mobile: gallery top, info below ─────────────────────────────

class _MobileHero extends StatelessWidget {
  final ProductDetailModel product;
  final int? discountPercent;
  final double? originalPrice;

  const _MobileHero({
    required this.product,
    this.discountPercent,
    this.originalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductImageGallery(imageUrls: product.imageUrls),
        const SizedBox(height: 24),
        ProductInfoSection(
          product: product,
          discountPercent: discountPercent,
          originalPrice: originalPrice,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}