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

  /// When true, auto-scrolls to the Reviews section once loaded —
  /// used when arriving here from a "review reply" notification.
  final bool scrollToReviews;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.scrollToReviews = false,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const double _mdBreakpoint = 768;
  ProductVariant? _selectedVariant;
  final GlobalKey _reviewsKey = GlobalKey();

  void _onVariantChanged(ProductVariant v) {
    setState(() => _selectedVariant = v);
  }

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
      if (widget.scrollToReviews) {
        _scrollToReviewsWhenReady();
      }
    });
  }

  // Reviews load async (ProductReviewsSection watches its own
  // provider), so the key's context may not exist on the very first
  // frame — retry briefly instead of scrolling to nothing.
  Future<void> _scrollToReviewsWhenReady() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final ctx = _reviewsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        return;
      }
    }
  }

   @override
  Widget build(BuildContext context) {
    ref.watch(inventoryRealtimeProvider); // activates live stock updates
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

        // Only show images for the currently selected variant/color.
    // Falls back to the first variant if nothing's been picked yet,
    // or if the previously selected variant no longer exists on this
    // product (e.g. after a fresh fetch invalidates stale data).
    final ProductVariant selectedVariant = (_selectedVariant != null &&
            product.variants
                .any((v) => v.variantId == _selectedVariant!.variantId))
        ? product.variants
            .firstWhere((v) => v.variantId == _selectedVariant!.variantId)
        : product.variants.first;

    final List<String> allImages = selectedVariant.imageUrls
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
                                    onVariantChanged: _onVariantChanged,
                                  )
                                : _MobileHero(
                                    product: product,
                                    imageUrls: allImages,
                                    onVariantChanged: _onVariantChanged,
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
                    KeyedSubtree(
                      key: _reviewsKey,
                      child: LayoutBuilder(
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
  final ValueChanged<ProductVariant> onVariantChanged;

  const _DesktopHero({
    required this.product,
    required this.imageUrls,
    required this.onVariantChanged,
  });

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
                            ProductInfoSection(
                product: product,
                onVariantChanged: onVariantChanged,
              ),
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

// ── Mobile: gallery top, info below ──────────────────────────────

class _MobileHero extends StatelessWidget {
  final Product product;
  final List<String> imageUrls;
  final ValueChanged<ProductVariant> onVariantChanged;

  const _MobileHero({
    required this.product,
    required this.imageUrls,
    required this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductImageGallery(imageUrls: imageUrls),
        const SizedBox(height: 24),
        ProductInfoSection(
          product: product,
          onVariantChanged: onVariantChanged,
        ),
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
