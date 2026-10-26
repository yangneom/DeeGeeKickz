import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/order.dart';
import '../../../services/customer/History/order_history_service.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/orders/order_tracking_timeline.dart';
import '../../../widgets/common/dialog/app_toast.dart';
import '../../../widgets/customer/orders/order_status_style.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart'
    show formatPeso;
import '../../customer/messages/customer_chat_screen.dart';

// ================================================
// ORDER TRACKING SCREEN
//
// FIX: "TRACK PACKAGE" button now opens the real
//      Lalamove URL stored in order.trackingUrl.
//      If no URL yet (not shipped), shows disabled
//      state with a helpful message.
// ================================================

// ================================================
// THE SCREEN THE REST OF THE APP OPENS (the order list, notifications).
//
// Same name and same input as before, so nothing that opens it changes. It now
// KEEPS THE ORDER FRESH:
//   - it loads the real dates of each step (order_progress);
//   - it listens for changes to THIS order (the `orders` table is in your
//     realtime publication) and reloads, so if the store confirms or ships the
//     order while the page is open, the tracker moves by itself.
// If realtime is unavailable the page just behaves as it did before.
// ================================================
class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final OrderHistoryService _service = OrderHistoryService();

  late Order _order = widget.order;
  OrderProgressInfo _progress = const OrderProgressInfo();
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _subscribe();
  }

  Future<void> _loadProgress() async {
    final OrderProgressInfo info = await _service.fetchProgress(_order.orderId);
    if (!mounted) return;
    setState(() => _progress = info);
  }

  // Reloads this order's status, tracking link and step dates from the database.
  Future<void> _refresh() async {
    final Order? fresh = await _service.fetchOrderById(_order.orderId);
    final OrderProgressInfo info = await _service.fetchProgress(_order.orderId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _progress = info;
    });
  }

  void _subscribe() {
    final int? id = int.tryParse(_order.orderId);
    if (id == null) return;

    _channel = Supabase.instance.client
        .channel('order_tracking_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: id,
          ),
          // Several rows can change in quick succession; reload once.
          callback: (PostgresChangePayload payload) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              if (mounted) _refresh();
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final RealtimeChannel? channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrderTrackingView(order: _order, progress: _progress);
  }
}

// The page itself. Same layout code as before; it just receives the order and
// the loaded progress instead of owning them.
class OrderTrackingView extends StatelessWidget {
  final Order order;

  /// Real dates and the customer's own cancel reason, loaded separately.
  final OrderProgressInfo progress;

  const OrderTrackingView({
    super.key,
    required this.order,
    this.progress = const OrderProgressInfo(),
  });

  // The first step tells apart an order still waiting for PAYMENT ("Awaiting
  // Payment") from one waiting for the STORE to confirm ("Pending"). Both are
  // real, different statuses in the database.
  List<String> get _steps => [
        _isAwaitingPayment ? 'Awaiting Payment' : 'Pending',
        'Confirmed',
        'Preparing',
        'Shipped',
        'Delivered',
      ];

  int get _currentStep {
    switch (order.orderStatus.toLowerCase()) {
      case 'confirmed':  return 1;
      case 'preparing':  return 2;
      case 'shipped':    return 3;
      case 'delivered':
      // "Completed" is the final status of a Cash on Delivery order (the admin
      // marks it Completed when the cash is collected). The old code sent it to
      // the default below and showed a finished order as Pending.
      case 'completed':  return 4;
      default:           return 0;
    }
  }

  // Real dates only. Step 1 is the placement date. Every other step shows a date
  // only if order_progress has a row for that status. No row means no date:
  // nothing is estimated, and no date is copied from another step.
  List<String?> get _timestamps => [
        order.dateTime,
        progress.stepDates['confirmed'],
        progress.stepDates['preparing'],
        progress.stepDates['shipped'],
        progress.stepDates['delivered'] ?? progress.stepDates['completed'],
      ];

  bool get _hasTrackingUrl =>
      order.trackingUrl != null && order.trackingUrl!.isNotEmpty;

  bool get _hasReceipt =>
      order.receiptUrl != null && order.receiptUrl!.isNotEmpty;

  // Same colours as the order list: both read order_status_style.dart. The old
  // version showed PENDING and CONFIRMED in plain black, while the list showed
  // them amber and blue, so one order looked like two different states.
  Color get _statusBadgeColor => orderStatusColor(order.orderStatus);
  // Opens the tracking link only if it is a real http(s) address. A malformed
  // link used to throw, and a failed open did nothing silently; now the
  // customer is told what happened.
  Future<void> _openLalamove(BuildContext context) async {
    if (!_hasTrackingUrl) return;
    final Uri? uri = Uri.tryParse(order.trackingUrl!.trim());
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      AppToast.error(
        context,
        'The tracking link for this order is not valid. Please contact support.',
        title: 'Cannot open tracking',
      );
      return;
    }

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToast.error(
        context,
        'We could not open the tracking page. Please try again.',
        title: 'Cannot open tracking',
      );
    }
  }

  Future<void> _openReceipt() async {
    if (!_hasReceipt) return;
    final Uri uri = Uri.parse(order.receiptUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget buildCancelReasonCard() {
  // The customer's own reason (read from order_progress), or whatever the
  // order already carried.
  final String? reason = progress.cancelReason ?? order.cancelReason;
  if (reason == null || reason.isEmpty) {
    return const SizedBox.shrink();
  }
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F5),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cancel_outlined, 
            size: 18, color: Color(0xFF991B1B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Cancelled',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: $reason',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final hPad      = isDesktop ? 48.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'orders'),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 896),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, 32, hPad, 80),
                          child: isDesktop
                              ? _DesktopLayout(screen: this)
                              : _MobileLayout(screen: this),
                        ),
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  // ── Shared section builders ───────────────────────────────────────────────

  Widget buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(0, 4, 12, 12),
                  child: Icon(Icons.arrow_back, size: 24, color: Colors.black),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily:  'Archivo Narrow',
                      fontSize:    28,
                      fontWeight:  FontWeight.w700,
                      letterSpacing: -0.5,
                      color:       Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Placed on ${order.dateTime}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize:   13,
                      color:      Color(0xFF656464),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              color: _statusBadgeColor,
              child: Text(
                order.orderStatus.toUpperCase(),
                style: const TextStyle(
                  fontFamily:   'Inter',
                  fontSize:     11,
                  fontWeight:   FontWeight.w700,
                  letterSpacing: 0.5,
                  color:        Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Receipt link in header if available
        if (_hasReceipt)
          GestureDetector(
            onTap: _openReceipt,
            child: const Row(
              children: [
                Icon(Icons.receipt_outlined,
                    size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text(
                  'View Receipt',
                  style: TextStyle(
                    fontFamily:  'Inter',
                    fontSize:    12,
                    color:       Color(0xFF2563EB),
                    fontWeight:  FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool get _isCancelled => order.orderStatus.toLowerCase() == 'cancelled';

  bool get _isAwaitingPayment =>
      order.orderStatus.toLowerCase() == 'awaiting payment';

  // A short line under the CURRENT step, only for the two states that wait on
  // something. Nothing is written under any other step.
  List<String?> get _stepNotes {
    final String status = order.orderStatus.toLowerCase();
    return [
      status == 'awaiting payment'
          ? 'Your payment has not been confirmed yet.'
          : (status == 'pending'
              ? 'Waiting for the store to confirm your order.'
              : null),
      null,
      null,
      null,
      null,
    ];
  }

  // Why there is no tracking link, in words that match the order's real state.
  String get _trackingUnavailableReason {
    final String status = order.orderStatus.toLowerCase();
    if (status == 'cancelled') {
      return 'Tracking is not available for a cancelled order';
    }
    if (status == 'delivered') {
      return 'This order was delivered. No tracking link was saved for it';
    }
    if (status == 'shipped') {
      return 'Your order is on its way. The tracking link is not available yet';
    }
    return 'Tracking link will appear once your order is shipped';
  }

  Widget buildTimeline() {
    // A cancelled order never reached the later steps. The step list would show
    // "Pending" as the current step, which is wrong, so show a plain notice.
    if (_isCancelled) {
      final String placed =
          order.dateTime.isNotEmpty ? ' It was placed on ${order.dateTime}.' : '';
      final String? cancelledAt = progress.stepDates['cancelled'];
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:  Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.block, size: 20, color: Color(0xFF991B1B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This order was cancelled${cancelledAt != null ? ' on $cancelledAt' : ''}.$placed',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   13,
                  height:     1.4,
                  color:      Color(0xFF4C4546),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: OrderTrackingTimeline(
        steps:       _steps,
        currentStep: _currentStep,
        timestamps:  _timestamps,
        notes:       _stepNotes,
      ),
    );
  }

  // FIX: "TRACK PACKAGE" opens real Lalamove URL.
  //      Shows disabled state if not shipped yet.
  // On a phone the text and the button STACK (button full width) instead of the
  // text being squeezed into a few words per line beside the button.
  Widget buildTrackingNumberRow(BuildContext context) {
    final bool canTrack = _hasTrackingUrl;
    final bool compact = MediaQuery.of(context).size.width < 520;

    final Widget message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DELIVERY TRACKING',
          style: TextStyle(
            fontFamily:   'Inter',
            fontSize:     10,
            fontWeight:   FontWeight.w600,
            letterSpacing: 1.0,
            color:        Color(0xFF656464),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          canTrack
              ? 'Lalamove — tap to track your delivery'
              : _trackingUnavailableReason,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize:   13,
            height:     1.4,
            color: canTrack ? Colors.black : const Color(0xFF656464),
          ),
        ),
      ],
    );

    // Enabled only when the order really has a tracking link. Disabled keeps its
    // place (so the card does not jump) and says so to screen readers.
    final Widget button = Semantics(
      button: true,
      enabled: canTrack,
      label: canTrack ? 'Track package' : 'Track package, not available yet',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canTrack ? () => _openLalamove(context) : null,
        child: Container(
          alignment: compact ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: canTrack ? Colors.black : const Color(0xFFD1D5DB),
          child: Text(
            'TRACK PACKAGE',
            style: TextStyle(
              fontFamily:   'Inter',
              fontSize:     12,
              fontWeight:   FontWeight.w600,
              letterSpacing: 1.0,
              color: canTrack ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 22, color: Color(0xFF656464)),
                    const SizedBox(width: 12),
                    Expanded(child: message),
                  ],
                ),
                const SizedBox(height: 12),
                button,
              ],
            )
          : Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 22, color: Color(0xFF656464)),
                const SizedBox(width: 12),
                Expanded(child: message),
                const SizedBox(width: 12),
                button,
              ],
            ),
    );
  }

  Widget buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width:  64,
                      height: 64,
                      color: const Color(0xFFEEEEEE),
                      child: const Icon(Icons.shopping_bag_outlined,
                          size: 28, color: Color(0xFF656464)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color:      Colors.black,
                            ),
                          ),
                          Text(
                            'Size: ${item.size}  ·  Brand: ${item.brand}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              color:      Color(0xFF656464),
                            ),
                          ),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              color:      Color(0xFF656464),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatPeso(item.total),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black,
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(height: 24, color: Color(0xFFCFC4C5)),

        _TotalRow(
            label: 'Subtotal',
            value: order.subtotal > 0
                ? order.subtotal
                : order.items.fold<double>(0, (sum, item) => sum + item.total),
          ),
          // The stored subtotal is ALREADY net of discount (every line holds the
          // discounted price) and total = subtotal + shipping. A negative
          // "Discount" row therefore made the lines not add up. The discount is
          // shown as what the customer saved, outside the sum, like checkout.
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 6),
            _TotalRow(
              label: 'You saved',
              value: order.discountAmount,
              valueColor: const Color(0xFF16A34A),
            ),
          ],
          const SizedBox(height: 6),
          _TotalRow(
            label: 'Shipping',
            value: order.shipping,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black,
                ),
              ),
              Text(
                formatPeso(order.totalAmount),
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSupportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Having trouble with your order? Our team is available 24/7 to assist you.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize:   13,
              color:      Color(0xFF656464),
              height:     1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CustomerChatScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined,
                      size: 16, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'CONTACT SELLER',
                    style: TextStyle(
                      fontFamily:   'Inter',
                      fontSize:     13,
                      fontWeight:   FontWeight.w600,
                      letterSpacing: 1.0,
                      color:        Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildShippingAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(order.customerName,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      Colors.black)),
          const SizedBox(height: 4),
          Text(order.address,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   14,
                  color:      Color(0xFF4C4546),
                  height:     1.5)),
          if (order.landmark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(order.landmark,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    color:      Color(0xFF656464))),
          ],
          const SizedBox(height: 4),
          Text(order.contact,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   13,
                  color:      Color(0xFF656464))),
        ],
      ),
    );
  }

  Widget buildAdminNoteCard() {
    if (order.adminNote == null || order.adminNote!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note from DeeGee Kickz',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.adminNote!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ─── Desktop layout ───────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final OrderTrackingView screen;
  const _DesktopLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        screen.buildHeader(context),
        const SizedBox(height: 24),
        screen.buildCancelReasonCard(),
        screen.buildAdminNoteCard(),
        const SizedBox(height: 16),
        screen.buildTimeline(),
        const SizedBox(height: 16),
        screen.buildTrackingNumberRow(context),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: screen.buildOrderSummary()),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  screen.buildSupportCard(context),
                  const SizedBox(height: 16),
                  screen.buildShippingAddressCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}



// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final OrderTrackingView screen;
  const _MobileLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        screen.buildHeader(context),
        const SizedBox(height: 16),
        screen.buildCancelReasonCard(),
        screen.buildAdminNoteCard(),
        const SizedBox(height: 20),
        screen.buildTimeline(),
        const SizedBox(height: 12),
        screen.buildTrackingNumberRow(context),
        const SizedBox(height: 12),
        screen.buildOrderSummary(),
        const SizedBox(height: 12),
        screen.buildSupportCard(context),
        const SizedBox(height: 12),
        screen.buildShippingAddressCard(),
      ],
    );
  }
}

// ─── Total row helper ─────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? valueColor;
  const _TotalRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize:   13,
                color:      Color(0xFF656464))),
        Text(formatPeso(value),
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize:   13,
                color:      valueColor ?? Colors.black)),
      ],
    );
  }
}