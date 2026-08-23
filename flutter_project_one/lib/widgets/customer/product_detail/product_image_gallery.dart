import 'package:flutter/material.dart';

/// Swipeable image gallery with:
/// - Mobile: horizontal PageView + animated dot indicators below
/// - Desktop: vertical thumbnail strip (left) + large image (right)
///   with floating prev/next arrows, Nike-style
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

  void _goToPage(int index) {
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
                  _goToPage(i);
                }),
                onPrev: () => setState(() {
                  if (_currentIndex > 0) {
                    _currentIndex--;
                    _goToPage(_currentIndex);
                  }
                }),
                onNext: () => setState(() {
                  if (_currentIndex < widget.imageUrls.length - 1) {
                    _currentIndex++;
                    _goToPage(_currentIndex);
                  }
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
// (unchanged)

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
                color: isActive ? Colors.black : const Color(0xFFCFC4C5),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Desktop: vertical thumbnail strip + large image, Nike-style ──

class _DesktopGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final ValueChanged<int> onThumbnailTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  static const double _galleryHeight = 640;
  static const double _thumbWidth = 76;

  const _DesktopGallery({
    required this.imageUrls,
    required this.currentIndex,
    required this.onThumbnailTap,
    required this.onPrev,
    required this.onNext,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _galleryHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Vertical thumbnail strip ──────────────────────────
          SizedBox(
            width: _thumbWidth,
            height: _galleryHeight,
            child: ListView.separated(
              itemCount: imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final isActive = index == currentIndex;
                return GestureDetector(
                  onTap: () => onThumbnailTap(index),
                  child: Container(
                    width: _thumbWidth,
                    height: _thumbWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border.all(
                        color: isActive
                            ? Colors.black
                            : const Color(0xFFE0E0E0),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 24),

          // ── Main image + floating prev/next arrows ────────────
          Expanded(
            child: SizedBox(
              height: _galleryHeight,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: _galleryHeight,
                    color: const Color(0xFFF5F5F5),
                    child: PageView.builder(
                      controller: pageController,
                      onPageChanged: onPageChanged,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
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

                  // Prev / Next arrows, bottom-right, floating
                  if (imageUrls.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          _ArrowButton(
                            icon: Icons.chevron_left,
                            onTap: currentIndex > 0 ? onPrev : null,
                          ),
                          const SizedBox(width: 8),
                          _ArrowButton(
                            icon: Icons.chevron_right,
                            onTap: currentIndex < imageUrls.length - 1
                                ? onNext
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.black : const Color(0xFFCFC4C5),
          size: 24,
        ),
      ),
    );
  }
}