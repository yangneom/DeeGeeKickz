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

class PromoScreen extends ConsumerStatefulWidget {
  const PromoScreen({super.key});

  @override
  ConsumerState<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends ConsumerState<PromoScreen> {
  static const double _mdBreakpoint = 768;

  ShopFilterState _filters = const ShopFilterState();
  ShopSortOption _sort = ShopSortOption.featured;

  // Fetched once, held across rebuilds — see initState.
  late final Future<Map<int, Discount>> _discountsFuture;

  @override
  void initState() {
    super.initState();
   _discountsFuture = DiscountService().fetchActiveDiscountsByProduct();
  }

  // Product.productId is a String in the model (DB column is int8),
  // so parse before looking it up in the int-keyed discounts map.
  Discount? _discountFor(Product product, Map<int, Discount> discounts) {
    final int? pid = int.tryParse(product.productId);
    if (pid == null) return null;
    return discounts[pid];
  }

  List<Product> _applyFilters(
    List<Product> all,
    Map<int, Discount> discounts,
  ) {
    // Only products with a currently-live discount belong on this page.
    var list = all.where((p) {
      if (_discountFor(p, discounts) == null) return false;
      if (p.totalAvailable == 0) return false;
      if (_filters.brands.isNotEmpty && !_filters.brands.contains(p.brand)) {
        return false;
      }
      if (_filters.categories.isNotEmpty &&
          !_filters.categories.contains(p.category)) {
        return false;
      }
      if (_filters.size != null) {
        final hasSize = p.variants
            .any((v) => v.sizes.any((s) => s.size == _filters.size));
        if (!hasSize) return false;
      }
      final minPrice = p.variants.isEmpty
          ? 0.0
          : p.variants
              .map((v) => v.retailPrice)
              .reduce((a, b) => a < b ? a : b);
      if (minPrice > _filters.maxPrice) return false;
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
      BuildContext context,
      List<String> brands,
      List<String> categories) async {
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
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AnnouncementBar(),
            const AppTopBar(activeRoute: 'promo'),
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allProducts) {
                  return FutureBuilder<Map<int, Discount>>(
                    future: _discountsFuture,
                    builder: (context, discountSnapshot) {
                      if (!discountSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final Map<int, Discount> discounts = discountSnapshot.data!;

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

                      final products = _applyFilters(allProducts, discounts);

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
                                  padding: EdgeInsets.fromLTRB(
                                      hPad, 32, hPad, 80),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 1440),
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
                                            onFilterTap: () =>
                                                _openFilterDrawer(
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
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) Navigator.of(context).popUntil((r) => r.isFirst);
          if (index == 2) Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ── Desktop ──────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final List<Product> products;
  final Map<int, Discount> discounts;
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
              _PromoHeader(
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

// ── Mobile ───────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final List<Product> products;
  final Map<int, Discount> discounts;
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
        _PromoHeader(
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
                        const Icon(Icons.tune,
                            size: 20, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopSortDropdown(
                  selected: sort, onChanged: onSortChanged),
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

// ── Promo header ─────────────────────────────────────────────────

class _PromoHeader extends StatelessWidget {
  final int count;
  final ShopSortOption sort;
  final ValueChanged<ShopSortOption> onSortChanged;
  final bool showSort;

  const _PromoHeader({
    required this.count,
    required this.sort,
    required this.onSortChanged,
    this.showSort = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.black,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text(
            'LIMITED TIME DEALS • UP TO 30% OFF SELECT STYLES',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROMOTIONS',
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
                  'Showing $count deal${count == 1 ? '' : 's'}',
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
        ),
      ],
    );
  }
}

// ── Product grid ─────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Map<int, Discount> discounts;
  final int crossCount;

  const _ProductGrid({
    required this.products,
    required this.discounts,
    required this.crossCount,
  });

  Discount? _discountFor(Product product) {
    final int? pid = int.tryParse(product.productId);
    if (pid == null) return null;
    return discounts[pid];
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < products.length; i += crossCount) {
      final rowItems = products.sublist(
        i,
        (i + crossCount) > products.length
            ? products.length
            : i + crossCount,
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
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

// ── Empty state ──────────────────────────────────────────────────

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
            Icon(Icons.local_offer_outlined,
                size: 48, color: Color(0xFFCFC4C5)),
            SizedBox(height: 16),
            Text(
              'NO DEALS FOUND',
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