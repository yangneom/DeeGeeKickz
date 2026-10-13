import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../models/discount_model.dart';
import '../../../providers/product/product_provider.dart';
import '../../../services/admin/promotionDiscount/discount_service.dart';
import '../../../widgets/common/nav/announcement_bar.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/customer/homescreen/hero_section.dart';
import '../../../widgets/customer/homescreen/brand_discovery_section.dart';
import '../../../widgets/customer/homescreen/category_discovery_section.dart';
import '../../../widgets/customer/homescreen/why_shop_section.dart';
import '../../../widgets/customer/homescreen/app_download_section.dart';
import '../../../widgets/customer/shop/shop_product_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const double _mdBreakpoint = 768;

  String? _selectedBrand;
  String? _selectedCategory;
  final GlobalKey _collectionKey = GlobalKey();

  late final Future<ActiveDiscounts> _discountsFuture;

  @override
  void initState() {
    super.initState();
    _discountsFuture = DiscountService().fetchActiveDiscounts();
  }

  List<Product> _applyHomeFilters(List<Product> all) {
    return all.where((p) {
      if (_selectedBrand != null && p.brand != _selectedBrand) return false;
      if (_selectedCategory != null && p.category != _selectedCategory) return false;
      return true;
    }).toList();
  }

  void _selectAndScrollTo({String? brand, String? category}) {
    setState(() {
      if (brand != null) _selectedBrand = brand;
      if (category != null) _selectedCategory = category;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _collectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  Widget _buildCollectionFilters(List<String> brands, List<String> categories) {
    final List<String> brandOptions = ['All', ...brands];
    final List<String> categoryOptions = ['All', ...categories];

    Widget pill(String label, bool isSelected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              border: Border.all(color: isSelected ? Colors.black : const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...categoryOptions.map((c) => pill(
                c,
                c == 'All' ? _selectedCategory == null : _selectedCategory == c,
                () => setState(() => _selectedCategory = c == 'All' ? null : c),
              )),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products, ActiveDiscounts discounts) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _mdBreakpoint;
    final int crossAxisCount = isDesktop ? (screenWidth >= 1200 ? 4 : 3) : 2;

    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No shoes found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Try another brand or category.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final Product product = products[index];
        final Discount? discount = discounts.byProduct[product.productId];
        return ShopProductCard(product: product, discount: discount);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    ref.watch(inventoryRealtimeProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _mdBreakpoint;
    final double hPad = isDesktop ? 48.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AnnouncementBar(),
            const AppTopBar(activeRoute: 'home'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HeroSection(),

                    productsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: Text('Could not load products: $e')),
                      ),
                      data: (allProducts) {
                        final List<String> brands =
                            allProducts.map((p) => p.brand).toSet().toList()..sort();
                        final List<String> categories =
                            allProducts.map((p) => p.category).toSet().toList()..sort();
                        final List<Product> filtered = _applyHomeFilters(allProducts);

                        return FutureBuilder<ActiveDiscounts>(
                          future: _discountsFuture,
                          builder: (context, snapshot) {
                            final ActiveDiscounts discounts =
                                snapshot.data ?? ActiveDiscounts(byProduct: {}, byVariant: {});

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BrandDiscoverySection(
                                  brands: brands,
                                  onBrandTap: (b) => _selectAndScrollTo(brand: b),
                                ),
                                CategoryDiscoverySection(
                                  categories: categories,
                                  onCategoryTap: (c) => _selectAndScrollTo(category: c),
                                ),

                                // ── SHOP THE COLLECTION — filtering
                                // becomes prominent only here ──
                                Padding(
                                  key: _collectionKey,
                                  padding: EdgeInsets.fromLTRB(hPad, 56, hPad, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('SHOP THE COLLECTION',
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 18),
                                      _buildCollectionFilters(brands, categories),
                                      const SizedBox(height: 24),
                                      _buildProductGrid(context, filtered, discounts),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const WhyShopSection(),
                    const AppDownloadSection(),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}