import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/promotion_banner_model.dart';
import '../../../services/admin/promotionDiscount/banner_service.dart';

/// Hero / banner section.
///
/// Background image now rotates through the Active banners uploaded
/// in the admin "Promotion & Discounts" screen (auto-advancing, like
/// a slider). Falls back to the original static hero image if there
/// are zero Active banners, so the homepage never renders blank.
///
/// Foreground copy ("NEW SEASON ARRIVAL" / "ENGINEERED FOR SPEED")
/// stays static — PromotionBanner has no per-banner title/subtitle
/// fields, only image + status, so only the background rotates.
///
/// Matches HTML:
/// <section class="relative w-full h-[85vh] overflow-hidden bg-primary
///   flex items-center justify-start">
///   <img class="... opacity-80 grayscale mix-blend-luminosity" .../>
///   <div class="relative z-10 ... max-w-2xl text-on-primary">
///     <p>NEW SEASON ARRIVAL</p>
///     <h2>ENGINEERED FOR SPEED</h2>
///     <p>Discover the next generation...</p>
///   </div>
/// </section>
///
/// Headline font size: 32px (text-headline-lg-mobile) on mobile,
/// 80px (text-display-lg) on md and up.
class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  // Fallback image, used only if there are no Active banners in the DB
  // (e.g. brand-new install before an admin has uploaded any).
  static const String _fallbackImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBxJxWno1DIhKpCA7lZJF763DHKcT385Nn_g8Hy9ss8hlnvnU6sHLwjTuTGsQ8srJNRV2a0rGXvXBmWhJQXmc-_CapyJJ-x5PI9PqBXy8v0DKjrvvUjlGWIIMTynFbXu9stNjuLJIvORDxZfg6ug2DPGqbYmK21U_5262TMpnVKDaIzztQcCsRf7oXNfSibeMXzQDS4v6dJGpuaJKwo2H8gUZ5QnkIEpILR7kcviERSO4phWurzHBcHrxz8I_wm8hxdVreXoJxkZXY';

  static const double _mdBreakpoint = 768;
  static const Duration _slideDuration = Duration(seconds: 6);

  final BannerService _bannerService = BannerService();
  final PageController _pageController = PageController();

  List<PromotionBanner> _banners = [];
  bool _isLoading = true;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    final List<PromotionBanner> result = await _bannerService.fetchActiveBanners();
    if (!mounted) return;
    setState(() {
      _banners = result;
      _isLoading = false;
    });
if (_banners.length > 1) {
      _startAutoPlay();
    } else {
      // Fewer than 2 banners now (e.g. re-fetch shrank the list) —
      // no PageView is rendered in this case, so any timer left over
      // from a previous fetch must stop, or it'll keep calling
      // animateToPage on a controller with nothing attached.
      _autoPlayTimer?.cancel();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_slideDuration, (_) {
      if (!mounted || _banners.length <= 1) {
        _autoPlayTimer?.cancel();
        return;
      }
      // Guard against firing before the PageView has attached its
      // controller (or after it's been swapped out), which is what
      // was throwing "PageController is not attached to a PageView."
      if (!_pageController.hasClients) return;

      final int nextPage = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }
  Widget _buildGrayscaleImage(String url) {
    return Opacity(
      opacity: 0.8,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Still loading banners on first frame — show fallback so nothing pops in.
    if (_isLoading) {
      return _buildGrayscaleImage(_fallbackImageUrl);
    }

    // No Active banners uploaded — use the original static image.
    if (_banners.isEmpty) {
      return _buildGrayscaleImage(_fallbackImageUrl);
    }

    // Single Active banner — no need for a PageView/carousel.
    if (_banners.length == 1) {
      return _buildGrayscaleImage(_banners.first.imageUrl);
    }

    // Multiple Active banners — auto-advancing carousel.
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _banners.length,
          onPageChanged: (int page) => setState(() => _currentPage = page),
          itemBuilder: (context, index) {
            return _buildGrayscaleImage(_banners[index].imageUrl);
          },
        ),
        // Slide indicator dots
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              final bool isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      height: screenHeight * 0.85, // h-[85vh]
      color: Colors.black, // bg-primary
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image(s) — grayscale + 80% opacity to mimic
          // `opacity-80 grayscale mix-blend-luminosity`, now rotating
          // through Active promotion banners when more than one exists.
          _buildBackground(),

          // Foreground text content
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= _mdBreakpoint;
              final horizontalPadding = isDesktop ? 48.0 : 16.0;

              return Align(
                alignment: Alignment.centerLeft,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // NEW SEASON ARRIVAL
                              const Text(
                                'NEW SEASON ARRIVAL',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14, // label-lg
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.8, // tracking-[0.2em]
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16), // mb-4

                              // ENGINEERED FOR SPEED
                              Text(
                                'ENGINEERED\nFOR SPEED',
                                style: TextStyle(
                                  fontFamily: 'Archivo Narrow',
                                  fontSize: isDesktop ? 80 : 32,
                                  height: isDesktop ? 88 / 80 : 36 / 32,
                                  letterSpacing: -0.02 * (isDesktop ? 80 : 32),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8), // mb-base

                              // Body copy
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 448), // max-w-md
                                child: const Text(
                                  'Discover the next generation of performance footwear. '
                                  'Precision crafted for those who demand more from every step.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18, // body-lg
                                    height: 28 / 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 48), // mb-lg
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}