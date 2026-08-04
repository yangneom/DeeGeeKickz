import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/product.dart';
import '../../widgets/customer/shop/shop_filter_drawer.dart' show ShopFilterState;
import '../../widgets/customer/shop/shop_sort_dropdown.dart' show ShopSortOption;
import '../../providers/product/product_provider.dart';

/// Current filter selection (brands, categories, size, max price).
/// Read/write this from the Shop screen, the filter drawer/sidebar,
/// AND from Home's FeaturedCategoriesSection (to pre-filter by
/// category on tap-through).
final shopFilterStateProvider =
    StateProvider<ShopFilterState>((ref) => const ShopFilterState());

/// Current sort selection.
final shopSortOptionProvider =
    StateProvider<ShopSortOption>((ref) => ShopSortOption.featured);

/// The single source of truth for "what should render in the shop grid
/// right now." Combines the live backend product list with whatever
/// filter/sort state is currently selected. Watch this from ShopScreen
/// instead of watching productsProvider directly.
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final filter = ref.watch(shopFilterStateProvider);
  final sort = ref.watch(shopSortOptionProvider);

  return productsAsync.whenData((products) {
    final filtered = products.where((p) {
      if (filter.brands.isNotEmpty && !filter.brands.contains(p.brand)) {
        return false;
      }
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(p.category)) {
        return false;
      }
      if (filter.size != null) {
        final hasSize = p.variants.any(
          (v) => v.sizes.any(
            (s) => s.size == filter.size && s.availableQty > 0,
          ),
        );
        if (!hasSize) return false;
      }
      if (p.variants.isNotEmpty) {
        final lowestPrice = p.variants
            .map((v) => v.retailPrice)
            .reduce((a, b) => a < b ? a : b);
        if (lowestPrice > filter.maxPrice) return false;
      }
      return true;
    }).toList();

    switch (sort) {
      case ShopSortOption.priceLowHigh:
        filtered.sort((a, b) => a.averagePrice.compareTo(b.averagePrice));
        break;
      case ShopSortOption.priceHighLow:
        filtered.sort((a, b) => b.averagePrice.compareTo(a.averagePrice));
        break;
      case ShopSortOption.topRated:
        // NOTE: Product currently has no rating field (only
        // ProductModel — the mock type — does). This falls back to
        // featured order until ratings are added to the real model.
        // Flagging rather than faking a sort.
        break;
      case ShopSortOption.featured:
        break;
    }

    return filtered;
  });
});

/// Brand options for the filter UI, derived from whatever is actually
/// in the backend right now rather than a hardcoded list — so if you
/// add a new brand in Inventory, it shows up in the filter automatically.
/// Falls back to [kShopBrands] while loading/on error/empty.
final availableBrandsProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.maybeWhen(
    data: (products) {
      final set = products.map((p) => p.brand).toSet().toList()..sort();
      return set;
    },
    orElse: () => const [],
  );
});

/// Same idea as [availableBrandsProvider], for categories.
final availableCategoriesProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.maybeWhen(
    data: (products) {
      final set = products.map((p) => p.category).toSet().toList()..sort();
      return set;
    },
    orElse: () => const [],
  );
});