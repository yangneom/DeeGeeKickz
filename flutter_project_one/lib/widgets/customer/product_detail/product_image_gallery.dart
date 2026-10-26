import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Product image gallery.
///   - Phone: swipeable pages with tappable, labelled dots below.
///   - Desktop: a vertical strip of thumbnails on the left and one large image
///     on the right, with previous / next arrows.
///
/// The public input is unchanged: ProductImageGallery(imageUrls: [...]).
///
/// WHAT CHANGED (all of these were confirmed by reading the old code)
///   - The phone gallery used BoxFit.cover, which CROPPED the shoe. Both layouts
///     now use BoxFit.contain, so the whole shoe is always visible.
///   - The big image area is now ONE square stage on both layouts (the old one
///     was a fixed 640px tall box whose width changed with the window, and a
///     4:5 box on phones), white with a single thin #CFC4C5 border, the same
///     card look as the rest of the customer site. The old grey (#F5F5F5 / #EEEEEE)
///     box showed the photo's own background as a visible rectangle with side
///     edges.
///   - Thumbnails are a fixed 76px square, shown whole (contain), and the strip
///     is hidden when there is only one image.
///   - No images at all now shows a clear placeholder instead of an empty grey box.
///   - Changing colour used to keep the old image number, so a colour with fewer
///     images could point past the end. The gallery now returns to the first image
///     whenever the list of images changes.
///   - Dots and thumbnails can be tapped, and have spoken labels
///     ("Image 2 of 5"). Arrows have labels too.
///
/// HOW THE FRAME STAYS CLEAR OF THE DIVIDER
///   The gallery never draws the divider and never reaches past its own stage.
///   The space between the gallery and the divider below is set by the product
///   page (product_detail.dart), not here.
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

  // Remembers which layout was shown last, so a window resize across the
  // breakpoint can put the new PageView back on the same image.
  bool? _wasDesktop;

  @override
  void didUpdateWidget(covariant ProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different colour brings a different list of images. Start again from
    // the first one instead of pointing at a position that may not exist.
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls)) {
      _currentIndex = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _select(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    setState(() => _currentIndex = index);
    _goToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: _Frame(child: _NoImage()),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= _mdBreakpoint;

        // Crossing the breakpoint rebuilds the PageView; put it back on the
        // image the customer was looking at.
        if (_wasDesktop != null && _wasDesktop != isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            final int shown = _pageController.page?.round() ?? 0;
            if (shown != _currentIndex) _pageController.jumpToPage(_currentIndex);
          });
        }
        _wasDesktop = isDesktop;

        return isDesktop
            ? _DesktopGallery(
                imageUrls: widget.imageUrls,
                currentIndex: _currentIndex,
                pageController: _pageController,
                maxWidth: constraints.maxWidth,
                onSelect: _select,
                onPageChanged: (int i) => setState(() => _currentIndex = i),
              )
            : _MobileGallery(
                imageUrls: widget.imageUrls,
                currentIndex: _currentIndex,
                pageController: _pageController,
                onSelect: _select,
                onPageChanged: (int i) => setState(() => _currentIndex = i),
              );
      },
    );
  }
}

// ── The single framed stage that holds the big image ─────────────────────────

class _Frame extends StatelessWidget {
  final Widget child;
  const _Frame({required this.child});

  @override
  Widget build(BuildContext context) {
    // ONE border, drawn here and nowhere else around the big image.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: ClipRect(child: child),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            'No image available',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}

// One page of the big image. BoxFit.contain: the whole shoe, never cropped.
class _StageImage extends StatelessWidget {
  final String url;
  final int index;
  final int total;
  const _StageImage(
      {required this.url, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: 'Product image ${index + 1} of $total',
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 1.5,
            ),
          );
        },
        errorBuilder: (_, __, ___) => const _NoImage(),
      ),
    );
  }
}

// ── Mobile: square stage + tappable dots ─────────────────────────────────────

class _MobileGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final PageController pageController;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onPageChanged;

  const _MobileGallery({
    required this.imageUrls,
    required this.currentIndex,
    required this.pageController,
    required this.onSelect,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: _Frame(
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: imageUrls.length,
              itemBuilder: (BuildContext context, int index) => _StageImage(
                url: imageUrls[index],
                index: index,
                total: imageUrls.length,
              ),
            ),
          ),
        ),
        if (imageUrls.length > 1) ...[
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'Image ${currentIndex + 1} of ${imageUrls.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(imageUrls.length, (int index) {
                final bool isActive = index == currentIndex;
                // The visible dot is small, but the area you can tap is 24px
                // so a finger can hit it.
                return Semantics(
                  button: true,
                  selected: isActive,
                  label: 'Show image ${index + 1}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(index),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isActive ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.black
                                : const Color(0xFFCFC4C5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Desktop: thumbnail strip + square stage ──────────────────────────────────

class _DesktopGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final PageController pageController;
  final double maxWidth;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onPageChanged;

  static const double _thumbSize = 76;
  static const double _gap = 24;

  const _DesktopGallery({
    required this.imageUrls,
    required this.currentIndex,
    required this.pageController,
    required this.maxWidth,
    required this.onSelect,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasStrip = imageUrls.length > 1;
    final double stripWidth = hasStrip ? _thumbSize + _gap : 0;

    // The stage is a SQUARE as wide as the room allows (never wider than 760),
    // so its shape does not change with the window the way the old fixed
    // 640px-tall box did. The thumbnail strip is exactly as tall as the stage.
    final double stage = (maxWidth - stripWidth).clamp(320.0, 760.0).toDouble();

    return SizedBox(
      height: stage,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasStrip) ...[
            SizedBox(
              width: _thumbSize,
              height: stage,
              child: ListView.separated(
                itemCount: imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final bool isActive = index == currentIndex;
                  return Semantics(
                    button: true,
                    selected: isActive,
                    label: 'Show image ${index + 1} of ${imageUrls.length}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(index),
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: isActive
                                ? Colors.black
                                : const Color(0xFFCFC4C5),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: _gap),
          ],

          // Main stage. Align + fixed size keeps it square even when the
          // available width is larger than 760.
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: stage,
                height: stage,
                child: _Frame(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: pageController,
                        onPageChanged: onPageChanged,
                        itemCount: imageUrls.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _StageImage(
                          url: imageUrls[index],
                          index: index,
                          total: imageUrls.length,
                        ),
                      ),
                      if (imageUrls.length > 1)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Row(
                            children: [
                              _ArrowButton(
                                icon: Icons.chevron_left,
                                label: 'Previous image',
                                onTap: currentIndex > 0
                                    ? () => onSelect(currentIndex - 1)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              _ArrowButton(
                                icon: Icons.chevron_right,
                                label: 'Next image',
                                onTap: currentIndex < imageUrls.length - 1
                                    ? () => onSelect(currentIndex + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
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
  final String label;
  final VoidCallback? onTap;

  const _ArrowButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.black : const Color(0xFF9CA3AF),
            size: 24,
          ),
        ),
      ),
    );
  }
}