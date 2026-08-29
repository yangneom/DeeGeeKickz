import 'package:flutter/material.dart';

import '../../../widgets/common/nav/announcement_bar.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/customer/homescreen/hero_section.dart';
import '../../../widgets/customer/homescreen/featured_categories_section.dart';
import '../../../widgets/customer/homescreen/trending_products_section.dart';
import '../../../widgets/customer/homescreen/new_drops_section.dart';
import '../../../widgets/customer/homescreen/why_shop_section.dart';
import '../shop_screen.dart/shop_screen.dart';
import '../../../services/customer/address/psgc_service.dart'; // TEMP

/// Landing / Home screen for the DeeGeeKickz customer-facing website.
///
/// Single responsive screen that adapts across desktop, laptop, tablet,
/// and mobile by reusing the shared common widgets (top bar, bottom nav,
/// footer) and the landing-specific section widgets.
///
/// MOCK DATA ONLY -- no Supabase / API calls. See lib/models for fake data.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _testPsgc(); // TEMP — remove after verifying
  }

  Future<void> _testPsgc() async {
    await PsgcService.instance.load();

    final ncrCities = PsgcService.instance.citiesForRegion('13');
    print('NCR cities found: ${ncrCities.length}');
    print('Includes Caloocan? ${ncrCities.any((c) => c.name.contains('Caloocan'))}');

    final ncrProvinces = PsgcService.instance.provincesForRegion('13');
    print('NCR provinces found (should be 0): ${ncrProvinces.length}');

    final bulacanProvince = PsgcService.instance.provincesForRegion('03')
        .firstWhere((p) => p.name == 'Bulacan');
    final bulacanCities = PsgcService.instance.citiesForProvince(bulacanProvince.code);
    print('Bulacan cities found: ${bulacanCities.length}');
    print('Includes Meycauayan? ${bulacanCities.any((c) => c.name.contains('Meycauayan'))}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // bg-background
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bars (sticky stack: announcement + nav)
            const AnnouncementBar(),
            const AppTopBar(activeRoute: 'home'),

            // Scrollable page content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    HeroSection(),
                    FeaturedCategoriesSection(),
                    TrendingProductsSection(),
                    NewDropsSection(),
                    WhyShopSection(),
                    // Footer is shared/common, rendered at the end of
                    // every page's scroll content.
                    AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom nav bar: shared/common widget, self-hides on tablet/desktop.
      // Navigation is now handled entirely inside BottomNavBar itself
      // (see bottom_nav_bar.dart) — no onTap override needed here.
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}