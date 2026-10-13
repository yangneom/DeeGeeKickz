import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../models/promotion_banner_model.dart';
import '../../../services/admin/promotionDiscount/banner_service.dart';

/// Hero / banner section.
///
/// Background image rotates through the Active banners uploaded
/// in the admin "Promotion & Discounts" screen (auto-advancing, like
/// a slider). Falls back to the original static hero image if there
/// are zero Active banners, so the homepage never renders blank.
///
/// The promo text and the shoes are part of the banner image itself,
/// so the image must never be cropped. Each banner is drawn WHOLE
/// (BoxFit.contain). Banners are cropped to 21:9 by the admin dialogs,
/// so in a 21:9 box they fill it exactly: no bands, no grey. A banner
/// with a different shape (e.g. an older 16:5 one saved by the Edit
/// dialog before it was fixed to 21:9) is still shown whole, with the
/// leftover space filled by a blurred, UNdimmed copy of itself.
///
/// Layouts:
///   - phone (< 768px): a rounded card inset by the page's side
///     padding, 21:9. (Before: a full-bleed 4:3 box with BoxFit.cover,
///     which cut off ~43% of a 21:9 banner, including the left text.)
///   - tablet / desktop: full-width 21:9, as before.
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

  // Phone card layout. Change these to line the card up with the other
  // homepage sections (Shop by Brand etc.) if their padding differs.
  static const double _phoneSidePadding = 16;
  static const double _phoneTopPadding = 12;
  static const double _phoneBottomPadding = 16;
  static const double _phoneCardRadius = 12;
  // Same shape as the uploaded banners (the admin dialogs crop to 21:9),
  // so a banner fills the card exactly: no bands above or below.
  static const double _phoneAspectRatio = 21 / 9;
  static const double _wideAspectRatio = 21 / 9;

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

  // ================================================
  // BANNER IMAGE — never cropped
  //
  // Layer 1: the same image, scaled to FILL the box, blurred and
  //          darkened — only visible where the banner doesn't reach.
  // Layer 2: the banner itself, scaled to FIT inside the box (whole
  //          image visible, aspect ratio preserved, never stretched).
  //
  // Both layers use the same URL, so the image is downloaded once
  // (Flutter's image cache serves the second request).
  // ================================================
  Widget _buildBannerImage(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        ),
        Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildBackground({required bool isPhone}) {
    // Still loading banners on first frame — show fallback so nothing pops in.
    if (_isLoading) {
      return _buildBannerImage(_fallbackImageUrl);
    }

    // No Active banners uploaded — use the original static image.
    if (_banners.isEmpty) {
      return _buildBannerImage(_fallbackImageUrl);
    }

    // Single Active banner — no need for a PageView/carousel.
    if (_banners.length == 1) {
      return _buildBannerImage(_banners.first.imageUrl);
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
            return _buildBannerImage(_banners[index].imageUrl);
          },
        ),
        // Slide indicator dots
        Positioned(
          // phone: close to the card's bottom edge
          bottom: isPhone ? 8 : 20,
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
                      : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                  // soft shadow keeps the dots readable on light banners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 4,
                    ),
                  ],
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
    final bool isPhone = screenWidth < _mdBreakpoint;

    final Widget hero = AspectRatio(
      aspectRatio: isPhone ? _phoneAspectRatio : _wideAspectRatio,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(isPhone: isPhone),
          ],
        ),
      ),
    );

    // Tablet / desktop: full-width hero, unchanged.
    if (!isPhone) return hero;

    // Phone: a rounded card inside the page's side padding, so it lines
    // up with the other homepage sections instead of running edge to edge.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _phoneSidePadding,
        _phoneTopPadding,
        _phoneSidePadding,
        _phoneBottomPadding,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_phoneCardRadius),
        child: hero,
      ),
    );
  }
}