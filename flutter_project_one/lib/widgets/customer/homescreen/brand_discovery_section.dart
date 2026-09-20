import 'package:flutter/material.dart';

class BrandDiscoverySection extends StatelessWidget {
  final List<String> brands;
  final ValueChanged<String> onBrandTap;

  const BrandDiscoverySection({
    super.key,
    required this.brands,
    required this.onBrandTap,
  });

  static const double _mdBreakpoint = 768;

  // Same pattern as categories — fill in once real logos/brand
  // photography exist, e.g. 'Nike': 'assets/images/brands/nike.jpg'
  static const Map<String, String> _brandImageAssets = {};

  Widget _tile(String brand, double width, double height) {
    final String? assetPath = _brandImageAssets[brand];

    return GestureDetector(
      onTap: () => onBrandTap(brand),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (assetPath != null)
              Image.asset(assetPath, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D0D0D), Color(0xFF2A2A2A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.center,
              child: Text(
                brand.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
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
          const Text('SHOP BY BRAND',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black)),
          const SizedBox(height: 20),
          if (isDesktop)
            Row(
              children: brands
                  .take(5)
                  .map((b) => Expanded(child: _tile(b, double.infinity, 110)))
                  .toList(),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: brands.length,
                itemBuilder: (context, i) => _tile(brands[i], 170, 110),
              ),
            ),
        ],
      ),
    );
  }
}