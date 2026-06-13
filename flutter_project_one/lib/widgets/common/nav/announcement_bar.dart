import 'package:flutter/material.dart';

/// Slim announcement bar shown at the very top of every page.
///
/// Matches HTML:
/// <div id="announcement-bar" class="... bg-primary text-on-primary py-xs px-margin-mobile text-center">
///   FREE SHIPPING ON ALL ORDERS OVER $150 • SHOP THE NEW PERFORMANCE ELITE COLLECTION
/// </div>
class AnnouncementBar extends StatelessWidget {
  const AnnouncementBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black, // bg-primary
      padding: const EdgeInsets.symmetric(
        vertical: 4, // py-xs (4px)
        horizontal: 16, // px-margin-mobile (16px)
      ),
      child: const Text(
        'FREE SHIPPING ON ALL ORDERS OVER \$150 • SHOP THE NEW PERFORMANCE ELITE COLLECTION',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white, // text-on-primary
          fontFamily: 'Inter',
          fontSize: 12, // label-sm
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5, // tracking-widest
          height: 16 / 12,
        ),
      ),
    );
  }
}