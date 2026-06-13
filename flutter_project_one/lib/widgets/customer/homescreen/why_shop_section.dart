import 'package:flutter/material.dart';

/// "Why Shop With Us" feature highlights section.
///
/// Matches HTML:
/// <section class="bg-primary text-on-primary py-xl">
///   <div class="grid grid-cols-1 md:grid-cols-3 gap-xl">
///     3x { icon, title, description }, each centered
/// </section>
class WhyShopSection extends StatelessWidget {
  const WhyShopSection({super.key});

  static const double _mdBreakpoint = 768;

  static const List<_Feature> _features = [
    _Feature(
      icon: Icons.rocket_launch_outlined,
      title: 'Elite Delivery',
      description:
          "Next-day shipping on all performance gear to ensure you're "
          'always ready for the next challenge.',
    ),
    _Feature(
      icon: Icons.verified_outlined,
      title: '100% Authentic',
      description:
          'Direct verification on every drop. We guarantee pure '
          'performance from the original source.',
    ),
    _Feature(
      icon: Icons.swap_horiz,
      title: 'Precision Fit',
      description:
          '30-day performance trials. If it doesn\'t improve your game, '
          'return it with no questions asked.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black, // bg-primary
      padding: const EdgeInsets.symmetric(vertical: 80), // py-xl
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _mdBreakpoint;
          final horizontalPadding = isDesktop ? 48.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _features.length; i++) ...[
                            if (i != 0) const SizedBox(width: 80), // gap-xl
                            Expanded(child: _FeatureColumn(feature: _features[i])),
                          ],
                        ],
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < _features.length; i++) ...[
                            if (i != 0) const SizedBox(height: 80), // gap-xl
                            _FeatureColumn(feature: _features[i]),
                          ],
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _FeatureColumn extends StatelessWidget {
  final _Feature feature;

  const _FeatureColumn({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(feature.icon, size: 48, color: Colors.white), // text-[48px]
        const SizedBox(height: 24), // mb-md
        Text(
          feature.title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12), // mb-sm
        Opacity(
          opacity: 0.8,
          child: Text(
            feature.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 24 / 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}