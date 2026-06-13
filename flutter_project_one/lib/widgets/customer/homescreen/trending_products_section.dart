import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

/// "Trending Now" horizontal scrolling product carousel.
///
/// Matches HTML:
/// <section class="bg-surface-container-low py-xl overflow-hidden">
///   header row: "TRENDING NOW" + "View All" link
///   <div class="flex gap-gutter overflow-x-auto ... hide-scrollbar">
///     product cards, each min-w-[300px] md:min-w-[400px], aspect-[4/5] image
///   </div>
/// </section>
class TrendingProductsSection extends StatelessWidget {
  const TrendingProductsSection({super.key});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F3F4), // surface-container-low
      padding: const EdgeInsets.symmetric(vertical: 80), // py-xl
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _mdBreakpoint;
          final horizontalPadding = isDesktop ? 48.0 : 16.0;
          final cardWidth = isDesktop ? 400.0 : 260.0;
          final captionHeight = isDesktop ? 110.0 : 88.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48), // mb-lg
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRENDING NOW',
                                style: TextStyle(
                                  fontFamily: 'Archivo Narrow',
                                  fontSize: isDesktop ? 48 : 32,
                                  height: isDesktop ? 52 / 48 : 36 / 32,
                                  letterSpacing: -0.01 * (isDesktop ? 48 : 32),
                                  fontWeight: isDesktop ? FontWeight.w700 : FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(width: 96, height: 4, color: Colors.black),
                            ],
                          ),
                          const Text(
                            'VIEW ALL',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                              decorationThickness: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Horizontal scroll row
              SizedBox(
                height: cardWidth * 5 / 4 + captionHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: mockTrendingProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 24), // gap-gutter
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: cardWidth,
                      child: _TrendingProductCard(
                        product: mockTrendingProducts[index],
                        isDesktop: isDesktop,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrendingProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isDesktop;

  const _TrendingProductCard({required this.product, required this.isDesktop});

  @override
  State<_TrendingProductCard> createState() => _TrendingProductCardState();
}

class _TrendingProductCardState extends State<_TrendingProductCard> {
  bool _hovering = false;

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
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRect(
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: AnimatedScale(
                  scale: _hovering ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: ColorFiltered(
                    colorFilter: _hovering
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : _grayscaleFilter,
                    child: Image.network(
                      widget.product.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ),

            // Caption
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(widget.isDesktop ? 24 : 16), // p-md / smaller on mobile
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _hovering ? Colors.black : const Color(0xFFCFC4C5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Archivo Narrow',
                            fontSize: widget.isDesktop ? 32 : 20,
                            height: widget.isDesktop ? 36 / 32 : 24 / 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.formattedPrice,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4), // mb-xs
                  Text(
                    widget.product.category.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: Color(0xFF5F5E5E), // secondary
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}