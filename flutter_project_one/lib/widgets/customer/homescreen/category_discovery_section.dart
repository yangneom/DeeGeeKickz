import 'package:flutter/material.dart';

class CategoryDiscoverySection extends StatelessWidget {
  final List<String> categories;
  final ValueChanged<String> onCategoryTap;

  const CategoryDiscoverySection({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  static const double _mdBreakpoint = 768;

  // Fill this in once real category photos exist — e.g.
  // 'Basketball': 'assets/images/categories/basketball.jpg'
  // Add the file under assets/images/categories/ and register the
  // folder in pubspec.yaml's `assets:` section. Until then, every
  // category falls back to the icon+gradient placeholder below —
  // no external URLs, no backend/database needed for this.
  static const Map<String, String> _categoryImageAssets = {};

  // A relevant icon per common category name, so the placeholder
  // still feels intentional rather than generic. Falls back to a
  // plain shoe icon for anything not explicitly listed.
  static IconData _iconFor(String category) {
    final String c = category.toLowerCase();
    if (c.contains('basketball')) return Icons.sports_basketball;
    if (c.contains('running')) return Icons.directions_run;
    if (c.contains('casual') || c.contains('lifestyle')) return Icons.weekend_outlined;
    if (c.contains('training') || c.contains('gym')) return Icons.fitness_center;
    if (c.contains('football') || c.contains('soccer')) return Icons.sports_soccer;
    return Icons.checkroom_outlined;
  }

  Widget _card(String category, double width, double height) {
    final String? assetPath = _categoryImageAssets[category];

    return GestureDetector(
      onTap: () => onCategoryTap(category),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: real image once available, otherwise a
            // dark gradient with a relevant icon watermark ──
            if (assetPath != null)
              Image.asset(assetPath, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1C1C1C), Color(0xFF343434)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(_iconFor(category), size: 64, color: Colors.white.withOpacity(0.18)),
                ),
              ),

            // ── Bottom gradient overlay, so text stays readable
            // over a real photo just as well as the placeholder ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Category label, lower portion, no arrow ──
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _mdBreakpoint;
    final double hPad = isDesktop ? 48.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SHOP BY CATEGORY',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black)),
          const SizedBox(height: 20),
          if (isDesktop)
            Row(
              children: categories
                  .map((c) => Expanded(child: _card(c, double.infinity, 220)))
                  .toList(),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, i) => _card(categories[i], 280, 200),
              ),
            ),
        ],
      ),
    );
  }
}