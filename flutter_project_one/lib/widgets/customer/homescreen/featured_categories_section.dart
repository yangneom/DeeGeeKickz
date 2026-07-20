import 'package:flutter/material.dart';
import '../../../models/category_model.dart';
import '../../../screens/customer/shop_screen.dart/shop_screen.dart'; // adjust to your real relative path

/// Featured Categories bento grid.
///
/// Matches HTML:
/// <div class="grid grid-cols-1 md:grid-cols-3 gap-gutter h-auto md:h-[600px]">
///   - tile 0 (Basketball): md:col-span-1 md:row-span-2 (tall left tile)
///   - tile 1 (Lifestyle Sneakers): md:col-span-2 md:row-span-1 (top-right wide)
///   - tile 2 (Running Tech): md:col-span-2 md:row-span-1 (bottom-right wide)
///
/// On mobile (< md), all tiles stack as a single column.
class FeaturedCategoriesSection extends StatelessWidget {
  const FeaturedCategoriesSection({super.key});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _mdBreakpoint;
        final horizontalPadding = isDesktop ? 48.0 : 16.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 80, // py-xl
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Text(
                    'FEATURED CATEGORIES',
                    style: TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: isDesktop ? 48 : 32,
                      height: isDesktop ? 52 / 48 : 36 / 32,
                      letterSpacing: -0.01 * (isDesktop ? 48 : 32),
                      fontWeight: isDesktop ? FontWeight.w700 : FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4), // mb-xs
                  Container(
                    width: 96, // w-24
                    height: 4, // h-1
                    color: Colors.black,
                  ),
                  const SizedBox(height: 48), // mb-lg

                  // Grid
                  if (isDesktop)
                    _DesktopBentoGrid(categories: mockFeaturedCategories)
                  else
                    _MobileStack(categories: mockFeaturedCategories),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desktop layout: 3-column grid, 600px total height.
/// Left column: tall Basketball tile (spans both rows).
/// Right column: two stacked wide tiles (Lifestyle, Running).
class _DesktopBentoGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  const _DesktopBentoGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: tall tile (1/3 width, full height)
          Expanded(
            flex: 1,
            child: _CategoryTile(category: categories[0]),
          ),
          const SizedBox(width: 24), // gap-gutter
          // Right: two stacked wide tiles (2/3 width)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CategoryTile(category: categories[1])),
                const SizedBox(height: 24), // gap-gutter
                Expanded(child: _CategoryTile(category: categories[2])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile layout: single column stack, each tile gets a fixed aspect ratio.
class _MobileStack extends StatelessWidget {
  final List<CategoryModel> categories;

  const _MobileStack({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < categories.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == categories.length - 1 ? 0 : 24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _CategoryTile(category: categories[i]),
            ),
          ),
      ],
    );
  }
}

/// A single bento tile: grayscale image + dark gradient overlay
/// + name/tagline text pinned to the bottom-left.
class _CategoryTile extends StatefulWidget {
  final CategoryModel category;

  const _CategoryTile({required this.category});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovering = false; // desktop mouse
  bool _pressed = false;  // touch / Android

  bool get _active => _hovering || _pressed;

  static const _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShopScreen()),
          );
        },
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with hover-zoom + grayscale->color on hover
              AnimatedScale(
                scale: _hovering ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                child: ColorFiltered(
                  colorFilter: _hovering
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                      : _grayscaleFilter,
                  child: Image.network(
                    widget.category.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Gradient overlay (from-primary/80 to-transparent)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xCC000000), // black @ 80%
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Text content
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(24), // p-md
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.category.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Archivo Narrow',
                          fontSize: 32, // headline-md
                          height: 36 / 32,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.only(left: _hovering ? 8 : 0),
                        child: Text(
                          widget.category.tagline.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14, // label-lg
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}