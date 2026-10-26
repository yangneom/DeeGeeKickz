// lib/widgets/customer/notifications/notification_tile_offer.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../../../providers/product/product_provider.dart';
import '../../../screens/customer/product_detail/product_detail.dart';
import '../../../screens/customer/promo/promo_screen.dart';
import '../../../screens/customer/shop_screen.dart/shop_screen.dart';
import '../../common/dialog/app_toast.dart';

/// Notification card for [NotificationType.promotion] (discounts and promo
/// banners) and [NotificationType.newArrival].
///
/// WHERE IT GOES:
///   - the notification names a product (referenceId)  -> that product's page
///   - an offer with no product (promo banner, or an older notice)  -> Promo
///   - a new arrival with no product (an older notice)  -> Shop
///
/// FIX: this tile used to catch every notification the screen had no tile
/// for, so cancellations, warnings and new arrivals all showed up as
/// "MEMBER EXCLUSIVE" and sent the customer to Promo. It now only handles
/// offers and new arrivals, and the whole card is the link (before, only the
/// small button opened anything; the rest of the card just marked it read).
class NotificationTileOffer extends ConsumerStatefulWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileOffer({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  ConsumerState<NotificationTileOffer> createState() =>
      _NotificationTileOfferState();
}

class _NotificationTileOfferState extends ConsumerState<NotificationTileOffer> {
  bool _busy = false;

  bool get _isNewArrival =>
      widget.notification.type == NotificationType.newArrival;

  // The product this notification is about, if it names one.
  int? get _productId => int.tryParse(widget.notification.referenceId ?? '');

  String get _label => _isNewArrival ? 'NEW ARRIVAL' : 'MEMBER EXCLUSIVE';

  IconData get _icon =>
      _isNewArrival ? Icons.new_releases_outlined : Icons.stars_rounded;

  String get _buttonLabel {
    if (_productId != null) return 'VIEW PRODUCT';
    return _isNewArrival ? 'SHOP NEW ARRIVALS' : 'SHOP THE VAULT';
  }

  Future<void> _open() async {
    // A second tap while the first is still working is ignored.
    if (_busy) return;

    widget.onMarkRead();

    final int? productId = _productId;
    if (productId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _isNewArrival ? const ShopScreen() : const PromoScreen(),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final products = await ref.read(productsProvider.future);
      final product = products.cast<dynamic>().firstWhere(
            (p) => p.productId == productId.toString(),
            orElse: () => null,
          );

      if (!mounted) return;
      if (product == null) {
        AppToast.info(
          context,
          'This product is no longer available.',
          title: 'Product unavailable',
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            scrollToReviews: false,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'We could not open this product. Please check your connection and try again.',
          title: 'Product unavailable',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppNotification notification = widget.notification;

    return GestureDetector(
      onTap: _open,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon — filled black circle ──────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 24,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 16),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          if (notification.isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            notification.timeAgo,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF656464),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF656464),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: _open,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      color: Colors.black,
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _buttonLabel,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Colors.white,
                              ),
                            ),
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