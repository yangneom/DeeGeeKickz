import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart' hide ProductImage;

import '../../../models/product.dart';
import '../../../providers/product/product_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/product_detail/product_image_gallery.dart';
import '../../../widgets/customer/product_detail/product_info_section.dart';
import '../../../widgets/customer/product_detail/product_specs_section.dart';
import '../../../widgets/customer/product_detail/product_reviews_section.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  /// Real product from Supabase — passed from ShopProductCard.
  /// Used only as an initial value / fallback; the screen re-reads
  /// productsProvider below so stock numbers (reserved/available)
  /// are never frozen at whatever they were when this was tapped.
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const double _mdBreakpoint = 768;

  @override
  void initState() {
    super.initState();
    // Someone else (Admin approving/rejecting an order, a cashier
    // sale, another customer checking out) may have changed stock
    // for this exact product since productsProvider last fetched.
    // Force a fresh fetch every time this screen opens, instead of
    // trusting whatever was cached from earlier in the session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(productsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    // Look up the freshest version of this exact product by ID.
    // Falls back to the object passed into the constructor while
    // the fresh list is still loading, or if it's ever missing —
    // so this screen never crashes, it just may show slightly stale
    // data for a moment instead of failing outright.
    final Product product = productsAsync.maybeWhen(
      data: (products) => products.firstWhere(
        (p) => p.productId == widget.product.productId,
        orElse: () => widget.product,
      ),
      orElse: () => widget.product,
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductInfoSection(product: product),
        const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mobile: gallery top, info below ──────────────────────────────

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

// ── Back bar ──────────────────────────────────────────────────────
// Matches the monochrome Inter/uppercase/letter-spaced theme used in
// WriteReviewForm and the review screen's app bar (thin grey bottom
// border, black arrow). maybePop() is used instead of pop() so this
// never crashes if the screen is ever reached with no back stack.
// ── Floating back button — sits on top of the product image, top-left ──


// ── "Ask about this item" — stages a product attachment then opens chat ──
