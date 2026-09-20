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
    // Renders the banner exactly as uploaded — no grayscale filter,
    // no opacity reduction. Previously forced every uploaded banner
    // through a grayscale + 80% opacity effect regardless of what
    // the admin actually uploaded.
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.black),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _mdBreakpoint;

    // Aspect-ratio based instead of a raw viewport-height percentage —
    // scales with the banner's own visual proportions instead of an
    // arbitrary number that produced the same oversized 85vh banner
    // on every mobile device regardless of orientation. Desktop gets
    // a wide, prominent presentation; mobile gets a much shorter,
    // still-visible one, matching how promotional banners are
    // typically composed for each format.
    final double aspectRatio = isDesktop ? 21 / 9 : 4 / 3;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
          ],
        ),
      ),
    );
  }
}