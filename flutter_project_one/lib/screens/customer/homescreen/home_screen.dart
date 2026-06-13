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


/// Landing / Home screen for the DeeGeeKickz customer-facing website.
///
/// Single responsive screen that adapts across desktop, laptop, tablet,
/// and mobile by reusing the shared common widgets (top bar, bottom nav,
/// footer) and the landing-specific section widgets.
///
/// MOCK DATA ONLY -- no Supabase / API calls. See lib/models for fake data.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
 
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
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ShopScreen(),
              ),
            );
          }
        },
      ),
    );
  }
}