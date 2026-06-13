import 'package:flutter/material.dart';

/// Swipeable image gallery with:
/// - Mobile: horizontal PageView + animated dot indicators below
/// - Desktop: large main image + 4-column thumbnail row below
class ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const ProductImageGallery({super.key, required this.imageUrls});

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  static const double _mdBreakpoint = 768;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onThumbnailTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _mdBreakpoint;
        return isDesktop
            ? _DesktopGallery(
                imageUrls: widget.imageUrls,
                currentIndex: _currentIndex,
                onThumbnailTap: (i) => setState(() {
                  _currentIndex = i;
                  _onThumbnailTap(i);
                }),
                pageController: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
              )
            : _MobileGallery(
                imageUrls: widget.imageUrls,
                currentIndex: _currentIndex,
                pageController: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
              );
      },
    );
  }
}

// ── Mobile: full-width swipeable PageView + dot indicators ──────

class _MobileGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const _MobileGallery({
    required this.imageUrls,
    required this.currentIndex,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main swipeable image
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            color: const Color(0xFFEEEEEE),
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 1.5,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Color(0xFFCFC4C5), size: 48),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(imageUrls.length, (index) {
            final isActive = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.black
                    : const Color(0xFFCFC4C5),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Desktop: large image + thumbnail strip ───────────────────────

class _DesktopGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final ValueChanged<int> onThumbnailTap;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const _DesktopGallery({
    required this.imageUrls,
    required this.currentIndex,
    required this.onThumbnailTap,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main image — square aspect ratio on desktop
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: const Color(0xFFEEEEEE),
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 1.5,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Color(0xFFCFC4C5), size: 64),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Thumbnail row
        Row(
          children: List.generate(imageUrls.length, (index) {
            final isActive = index == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onThumbnailTap(index),
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < imageUrls.length - 1 ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? Colors.black
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      color: isActive
                          ? null
                          : Colors.white.withOpacity(0.2),
                      colorBlendMode: BlendMode.lighten,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}