import 'package:flutter/material.dart';

/// Shared footer for the DeeGeeKickz customer-web site.
///
/// Matches HTML:
/// - md and up (>=768px): 4-column grid (Brand / Support / Legal / Social)
///   plus a bottom bar with copyright + links, via `hidden md:grid`.
/// - below md: only the bottom bar is shown (the 4-column grid is
///   hidden on mobile in the source HTML), stacked vertically.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9), // bg-surface
        border: Border(
          top: BorderSide(color: Color(0xFFCFC4C5), width: 1), // outline-variant
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48), // py-lg
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _mdBreakpoint;
          final horizontalPadding = isDesktop ? 48.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktop) ...[
                      const _FooterColumnsDesktop(),
                      const SizedBox(height: 80), // mb-xl
                    ],
                    _FooterBottomBar(isDesktop: isDesktop),
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

/// 4-column grid: Brand / Support / Legal / Social (desktop & tablet only).
class _FooterColumnsDesktop extends StatelessWidget {
  const _FooterColumnsDesktop();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          flex: 1,
          child: _BrandColumn(),
        ),
        SizedBox(width: 24), // gap-gutter
        Expanded(
          flex: 1,
          child: _LinksColumn(
            title: 'Support',
            links: [
              'Help Center',
              'Shipping Info',
              'Returns & Refunds',
              'Order Status',
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: _LinksColumn(
            title: 'Legal',
            links: [
              'Privacy Policy',
              'Terms of Service',
              'Cookies Policy',
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: _SocialColumn(),
        ),
      ],
    );
  }
}

class _BrandColumn extends StatelessWidget {
  const _BrandColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'DeeGeeKickz',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Elite performance footwear for the modern athlete. '
          'Precision engineered. Designed for speed.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 24 / 16,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _LinksColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _LinksColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24), // mb-md
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12), // gap-sm
            child: InkWell(
              onTap: () {},
              child: Text(
                link,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF656464), // on-secondary-container
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SocialColumn extends StatelessWidget {
  const _SocialColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SOCIAL',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _SocialIcon(icon: Icons.public),
            const SizedBox(width: 24),
            _SocialIcon(icon: Icons.share),
            const SizedBox(width: 24),
            _SocialIcon(icon: Icons.language),
          ],
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;

  const _SocialIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Icon(icon, size: 24, color: Colors.black),
    );
  }
}

/// Bottom copyright + links bar, present on all breakpoints.
class _FooterBottomBar extends StatelessWidget {
  final bool isDesktop;

  const _FooterBottomBar({required this.isDesktop});

  static const List<String> _links = [
    'About',
    'Contact',
    'Policies',
    'Shipping',
    'Returns',
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Opacity(
        opacity: 0.4,
        child: const Text(
          '© 2024 DeeGeeKickz. Engineered for Performance.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ),
      SizedBox(height: isDesktop ? 0 : 16, width: isDesktop ? 24 : 0),
      Wrap(
        spacing: 24, // gap-md
        runSpacing: 8,
        children: _links
            .map(
              (label) => Opacity(
                opacity: 0.4,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ];

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [children[0], children[2]],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}