import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

/// "New Drops" grid section.
///
/// Matches HTML:
/// <div class="grid grid-cols-2 lg:grid-cols-4 gap-gutter">
///   each item: square image with badge top-left, name, release date,
///   and "Remind Me" outlined button.
///
/// 2 columns on mobile/tablet, 4 columns on large screens (lg = 1024px).
class NewDropsSection extends StatelessWidget {
  const NewDropsSection({super.key});

  static const double _mdBreakpoint = 768;
  static const double _lgBreakpoint = 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktopHeader = width >= _mdBreakpoint;
        final crossAxisCount = width >= _lgBreakpoint ? 4 : 2;
        final horizontalPadding = isDesktopHeader ? 48.0 : 16.0;

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
                  // Header
                  Text(
                    'NEW DROPS',
                    style: TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: isDesktopHeader ? 48 : 32,
                      height: isDesktopHeader ? 52 / 48 : 36 / 32,
                      letterSpacing: -0.01 * (isDesktopHeader ? 48 : 32),
                      fontWeight: isDesktopHeader ? FontWeight.w700 : FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(width: 96, height: 4, color: Colors.black),
                  const SizedBox(height: 48), // mb-lg

                  // Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mockNewDrops.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24, // gap-gutter
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      return _DropCard(product: mockNewDrops[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DropCard extends StatefulWidget {
  final ProductModel product;

  const _DropCard({required this.product});

  @override
  State<_DropCard> createState() => _DropCardState();
}

class _DropCardState extends State<_DropCard> {
  bool _hovering = false;
  bool _buttonHovering = false;

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
            // Image with badge
            Expanded(
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedScale(
                      scale: _hovering ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      child: ColorFiltered(
                        colorFilter: _hovering
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                            : _grayscaleFilter,
                        child: Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (widget.product.badge != null)
                      Positioned(
                        top: 16, // top-4
                        left: 16, // left-4
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-sm py-xs
                          color: Colors.black,
                          child: Text(
                            widget.product.badge!.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24), // mb-md

            // Name
            Text(
              widget.product.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4), // mb-xs

            // Release date
            Text(
              (widget.product.releaseDate ?? '').toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5F5E5E), // secondary
              ),
            ),
            const SizedBox(height: 8), // mb-base

            // Remind Me button
            MouseRegion(
              onEnter: (_) => setState(() => _buttonHovering = true),
              onExit: (_) => setState(() => _buttonHovering = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12), // py-sm
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                  color: _buttonHovering ? Colors.black : Colors.transparent,
                ),
                child: Text(
                  'REMIND ME',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: _buttonHovering ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}