import 'package:flutter/material.dart';

/// Slim announcement bar shown at the very top of every page.
///
/// Matches HTML:
/// <div id="announcement-bar" class="... bg-primary text-on-primary py-xs px-margin-mobile text-center">
///   FREE SHIPPING ON ALL ORDERS OVER $150 • SHOP THE NEW PERFORMANCE ELITE COLLECTION
/// </div>
class AnnouncementBar extends StatelessWidget {
  const AnnouncementBar({super.key});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= _mdBreakpoint;

        return Container(
          width: double.infinity,
          color: Colors.black, // bg-primary
          padding: EdgeInsets.symmetric(
            vertical: 4,
            horizontal: isDesktop ? 16 : 10,
          ),
          child: Text(
            'FREE SHIPPING ON ALL ORDERS OVER \$150 • SHOP THE NEW PERFORMANCE ELITE COLLECTION',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: isDesktop ? 12 : 10,
              fontWeight: FontWeight.w500,
              letterSpacing: isDesktop ? 1.5 : 0.4,
              height: isDesktop ? 16 / 12 : 14 / 10,
            ),
          ),
        );
      },
    );
  }
}