import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../models/discount_model.dart';
import '../../../providers/product/product_provider.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';
import '../../../widgets/common/nav/announcement_bar.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/shop/shop_product_card.dart';
import '../../../widgets/customer/shop/shop_filter_drawer.dart';
import '../../../widgets/customer/shop/shop_filter_sidebar.dart';
import '../../../widgets/customer/shop/shop_sort_dropdown.dart';
import '../../../providers/product/product_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  static const double _mdBreakpoint = 768;

  ShopFilterState _filters = const ShopFilterState();
  ShopSortOption _sort = ShopSortOption.featured;

  // Fetched once, held across rebuilds.
  late final Future<ActiveDiscounts> _discountsFuture;

    @override
  void initState() {
    super.initState();
    _discountsFuture = DiscountService().fetchActiveDiscounts();
    // Same reasoning as ProductDetailScreen — stock may have changed
    // elsewhere (admin approval/rejection, cashier sale, another
    // customer's checkout) since productsProvider last fetched.
    //
    // CONFIRMED ROOT CAUSE (found via live bisection): this callback
    // had no `mounted` guard. If ShopScreen gets disposed before this
    // post-frame callback fires — exactly what happens when
    // pushAndRemoveUntil navigates through/past Shop — this threw
    // "Bad state: Using 'ref' when a widget is about to or has been
    // unmounted is unsafe," which then corrupted productsProvider's
    // state for every OTHER screen watching it, explaining why the
    // crash appeared to follow into completely unrelated screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(productsProvider);
    });
  }
  // ── Derived list ─────────────────────────────────────────────
  List<Product> _applyFilters(List<Product> all) {
    var list = all.where((p) {
      if (_filters.brands.isNotEmpty && !_filters.brands.contains(p.brand)) {
        return false;
      }
      if (_filters.categories.isNotEmpty &&
          !_filters.categories.contains(p.category)) {
        return false;
      }
      if (_filters.size != null) {
        final hasSize = p.variants.any(
          (v) => v.sizes.any((s) => s.size == _filters.size),
        );
        if (!hasSize) return false;
      }
      // maxPrice == 5000 is the slider's rightmost position, labeled
      // "₱5000+" in the UI — meaning "no ceiling," not "exactly 5000."
      // Without this check, any product priced above ₱5000 was
      // invisible in the shop even at the slider's max setting, with
      // no way for a customer to ever see it.
      if (_filters.maxPrice < 5000) {
        final minPrice = p.variants.isEmpty
            ? 0.0
            : p.variants
                .map((v) => v.retailPrice)
                .reduce((a, b) => a < b ? a : b);
        if (minPrice > _filters.maxPrice) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case ShopSortOption.priceLowHigh:
        list.sort((a, b) => a.averagePrice.compareTo(b.averagePrice));
        break;
      case ShopSortOption.priceHighLow:
        list.sort((a, b) => b.averagePrice.compareTo(a.averagePrice));
        break;
      case ShopSortOption.topRated:
        break;
      case ShopSortOption.featured:
        break;
    }
    return list;
  }

  Future<void> _openFilterDrawer(
      BuildContext context, List<String> brands, List<String> categories) async {
    final result = await showShopFilterDrawer(
      context,
      _filters,
      availableBrands: brands,
      availableCategories: categories,
    );
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inventoryRealtimeProvider); // activates live stock updates
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AnnouncementBar(),
            const AppTopBar(activeRoute: 'shop'),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allProducts) {
                  return FutureBuilder<ActiveDiscounts>(
                    future: _discountsFuture,
                    builder: (context, discountSnapshot) {
                      final ActiveDiscounts discounts = discountSnapshot.data ??
                          ActiveDiscounts(byProduct: {}, byVariant: {});

                      final brands = allProducts
                          .map((p) => p.brand)
                          .toSet()
                          .toList()
                        ..sort();
                      final categories = allProducts
                          .map((p) => p.category)
                          .toSet()
                          .toList()
                        ..sort();

                      final products = _applyFilters(allProducts);

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isDesktop =
                                    constraints.maxWidth >= _mdBreakpoint;
                                final hPad = isDesktop ? 48.0 : 16.0;

                                return Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(hPad, 32, hPad, 80),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 1440),
                                    child: isDesktop
                                        ? _DesktopLayout(
                                            products: products,
                                            discounts: discounts,
                                            filters: _filters,
                                            sort: _sort,
                                            availableBrands: brands,
                                            availableCategories: categories,
                                            onFilterChanged: (f) =>
                                                setState(() => _filters = f),
                                            onSortChanged: (s) =>
                                                setState(() => _sort = s),
                                          )
                                        : _MobileLayout(
                                            products: products,
                                            discounts: discounts,
                                            sort: _sort,
                                            filters: _filters,
                                            onFilterTap: () => _openFilterDrawer(
                                                context, brands, categories),
                                            onSortChanged: (s) =>
                                                setState(() => _sort = s),
                                          ),
                                  ),
                                );
                              },
                            ),
                            const AppFooter(),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Desktop layout ───────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final List<Product> products;
  final ActiveDiscounts discounts;
  final ShopFilterState filters;
  final ShopSortOption sort;
  final List<String> availableBrands;
  final List<String> availableCategories;
  final ValueChanged<ShopFilterState> onFilterChanged;
  final ValueChanged<ShopSortOption> onSortChanged;

  const _DesktopLayout({
    required this.products,
    required this.discounts,
    required this.filters,
    required this.sort,
    required this.availableBrands,
    required this.availableCategories,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShopFilterSidebar(
          state: filters,
          onChanged: onFilterChanged,
          availableBrands: availableBrands,
          availableCategories: availableCategories,
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                  count: products.length,
                  sort: sort,
                  onSortChanged: onSortChanged),
              const SizedBox(height: 32),
              products.isEmpty
                  ? const _EmptyState()
                  : _ProductGrid(products: products, discounts: discounts, crossCount: 3),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mobile layout ────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final List<Product> products;
  final ActiveDiscounts discounts;
  final ShopSortOption sort;
  final ShopFilterState filters;
  final VoidCallback onFilterTap;
  final ValueChanged<ShopSortOption> onSortChanged;

  const _MobileLayout({
    required this.products,
    required this.discounts,
    required this.sort,
    required this.filters,
    required this.onFilterTap,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
            count: products.length,
            sort: sort,
            onSortChanged: onSortChanged,
            showSort: false),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF7E7576)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'FILTERS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!filters.isEmpty)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const Icon(Icons.tune, size: 20, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopSortDropdown(selected: sort, onChanged: onSortChanged),
            ),
          ],
        ),
        const SizedBox(height: 24),
        products.isEmpty
            ? const _EmptyState()
            : _ProductGrid(products: products, discounts: discounts, crossCount: 2),
      ],
    );
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int count;
  final ShopSortOption sort;
  final ValueChanged<ShopSortOption> onSortChanged;
  final bool showSort;

  const _PageHeader({
    required this.count,
    required this.sort,
    required this.onSortChanged,
    this.showSort = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALL SNEAKERS',
              style: TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Showing $count product${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFF4C4546),
              ),
            ),
          ],
        ),
        if (showSort)
          ShopSortDropdown(selected: sort, onChanged: onSortChanged),
      ],
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ActiveDiscounts discounts;
  final int crossCount;

  const _ProductGrid({
    required this.products,
    required this.discounts,
    required this.crossCount,
  });

  Discount? _discountFor(Product product) {
    final int? pid = int.tryParse(product.productId);
    if (pid == null) return null;

    final Discount? wholeProduct = discounts.resolve(productId: pid);
    if (wholeProduct != null) return wholeProduct;

    for (final ProductVariant v in product.variants) {
      final int? variantId = v.variantId;
      if (variantId != null) {
        final Discount? variantDiscount =
            discounts.resolve(productId: pid, variantId: variantId);
        if (variantDiscount != null) return variantDiscount;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < products.length; i += crossCount) {
      final rowItems = products.sublist(
        i,
        (i + crossCount) > products.length ? products.length : i + crossCount,
      );

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < rowItems.length; j++) ...[
                if (j > 0) SizedBox(width: crossCount == 2 ? 8 : 24),
                Expanded(
                  child: ShopProductCard(
                    product: rowItems[j],
                    discount: _discountFor(rowItems[j]),
                  ),
                ),
              ],
              for (int k = rowItems.length; k < crossCount; k++) ...[
                SizedBox(width: crossCount == 2 ? 8 : 24),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ),
      );

      if (i + crossCount < products.length) {
        rows.add(SizedBox(height: crossCount == 2 ? 24 : 32));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off_rounded,
                size: 48, color: Color(0xFFCFC4C5)),
            SizedBox(height: 16),
            Text(
              'NO PRODUCTS FOUND',
              style: TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Color(0xFF4C4546),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF4C4546),
              ),
            ),
          ],
        ),
      ),
    );
  }
}