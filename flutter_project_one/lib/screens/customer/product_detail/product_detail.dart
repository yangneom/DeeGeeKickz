import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/product_detail/product_image_gallery.dart';
import '../../../widgets/customer/product_detail/product_info_section.dart';
import '../../../widgets/customer/product_detail/product_specs_section.dart';
import '../../../widgets/customer/product_detail/product_reviews_section.dart';

class ProductDetailScreen extends StatelessWidget {
  /// Real product from Supabase — passed from ShopProductCard
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    // Collect all image URLs across all variants
    final List<String> allImages = product.variants
        .expand((v) => v.imageUrls)
        .where((url) => url.isNotEmpty)
        .toList();

    final int productId = int.tryParse(product.productId) ?? 0;

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
                    // ── Hero: gallery + info ──────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;

                        return Padding(
                          padding:
                              EdgeInsets.fromLTRB(hPad, 24, hPad, 0),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child: isDesktop
                                ? _DesktopHero(
                                    product: product,
                                    imageUrls: allImages,
                                  )
                                : _MobileHero(
                                    product: product,
                                    imageUrls: allImages,
                                  ),
                          ),
                        );
                      },
                    ),

                    // ── Description ───────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;
                        return Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: hPad),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child: ProductSpecsSection(
                                product: product),
                          ),
                        );
                      },
                    ),

                    // ── Reviews ───────────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop =
                            constraints.maxWidth >= _mdBreakpoint;
                        final hPad = isDesktop ? 48.0 : 16.0;
                        return Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: hPad),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1440),
                            child: ProductReviewsSection(
                              productId: productId,
                              productName: product.productName,
                            ),
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
  final Product product;
  final List<String> imageUrls;

  const _DesktopHero(
      {required this.product, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 58,
          child: ProductImageGallery(imageUrls: imageUrls),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 42,
          child: ProductInfoSection(product: product),
        ),
      ],
    );
  }
}

// ── Mobile: gallery top, info below ──────────────────────────────

class _MobileHero extends StatelessWidget {
  final Product product;
  final List<String> imageUrls;

  const _MobileHero(
      {required this.product, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductImageGallery(imageUrls: imageUrls),
        const SizedBox(height: 24),
        ProductInfoSection(product: product),
        const SizedBox(height: 16),
      ],
    );
  }
}