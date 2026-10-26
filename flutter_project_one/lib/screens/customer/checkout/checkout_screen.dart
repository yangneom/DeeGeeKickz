import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/customer/order_service.dart';
import '../../../services/customer/payment/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/login_screen.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../providers/product/product_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/checkout/checkout_progress_bar.dart';
import 'checkout_step1_shipping.dart';
import 'checkout_step2_review.dart';
import 'checkout_step3_payment.dart';
import '../../../models/customer_cart_item.dart';

/// Checkout shell — manages the 3-step flow.
/// Holds all shared state (shipping info, payment method)
/// and passes it down to each step screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  /// NEW — when provided, checkout is for THIS item only ("Buy Now"),
  /// completely bypassing the saved cart. When null (default), checkout
  /// behaves as before — the full saved cart ("Add to Bag" → Cart →
  /// Checkout).
  final CustomerCartItem? buyNowItem;

  const CheckoutScreen({super.key, this.buyNowItem});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {

  // ── Step tracker ──────────────────────────────────────────────────────
  int _currentStep = 1;

  // ── Shared shipping state ─────────────────────────────────────────────
  String? addressId;
  String street   = '';
  String barangay = '';
  String city     = '';
  String province = '';
  String region   = '';
  String zipCode  = '';
  String landmark = '';

  // ── Real shipping fee (from Lalamove, via Step 1) ─────────────────────
  // UPDATE: no more flat-rate fallback (₱10/free-over-₱150) — Step 1
  // now BLOCKS checkout entirely if a real quote can't be obtained,
  // instead of silently using a guessed number. Starts at 0 since
  // there's nothing real to show until Step 1's first quote resolves;
  // the "Continue" button on Step 1 is disabled until then anyway, so
  // this initial value is never actually charged to a customer.
  double _shippingFee = 0.0;
  bool   _isLoadingShippingFee = false;

  void _onShippingFeeChanged(double fee, bool isLoading) {
    setState(() {
      _shippingFee = fee;
      _isLoadingShippingFee = isLoading;
    });
  }

  // ── Customer info ─────────────────────────────────────────────────────
    String customerName  = '';
  String customerEmail = '';
  String customerPhone = '';
  bool   _customerInfoLoaded = false;  // ← add this flag

  // Add this method to _CheckoutScreenState:
  Future<void> _loadCustomerInfo() async {
    if (_customerInfoLoaded) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final dynamic profile = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {          customerName         = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
          customerPhone        = (profile['phone'] ?? '').toString();
          customerEmail        = user.email ?? '';
          _customerInfoLoaded  = true;
        });
      }
    } catch (e) {
      // fallback — email only
      customerEmail = user.email ?? '';
      _customerInfoLoaded = true;
    }
  }

  // Call it in initState:
  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  // Lets a step change scroll the page back to the top, so the customer lands
  // at the start of the next step instead of wherever the last button was.
  final ScrollController _scrollController = ScrollController();

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The screen may have been left (or the order placed) before this frame.
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }




  // ── Payment ───────────────────────────────────────────────────────────
  // True while Step 3 is creating an order or taking a payment.
  bool _step3Busy = false;
  String paymentMethod = 'gcash';

  // ── Step navigation ───────────────────────────────────────────────────
  void _goToStep(int step) {
    // While Step 3 is creating an order or taking a payment, nobody can leave
    // it: not with the Back link, the progress bar or the system Back button.
    // Leaving mid-payment could strand a half-created order.
    if (_step3Busy && step != _currentStep) return;
    setState(() => _currentStep = step);
    _scrollToTop();
  }

  void _onShippingContinue({
    String? addressId,
    required String street,
    required String barangay,
    required String city,
    required String province,
    required String region,
    required String zipCode,
    required String landmark,
  }) {
    setState(() {
      this.addressId = addressId;
      this.street   = street;
      this.barangay = barangay;
      this.city     = city;
      this.province = province;
      this.region   = region;
      this.zipCode  = zipCode;
      this.landmark = landmark;
      _currentStep  = 2;
    });
    _scrollToTop();
  }
  void _onReviewContinue() {
    setState(() => _currentStep = 3);
    _scrollToTop();
  }

    Future<int> _onPlaceOrder() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw SessionExpiredException(
        'Your session has expired. Please log in again to continue.',
      );
    }

    // Buy Now → just the one item, never the saved cart.
    // Add to Bag flow → the full saved cart, same as before.
    final items = widget.buyNowItem != null
        ? [widget.buyNowItem!]
        : ref.read(customerCartProvider);
    final double subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    // Real Lalamove-quoted fee, set by Step 1. Step 1 blocks the
    // customer from ever reaching this point (Step 3) unless a real
    // quote was successfully obtained, so _shippingFee here is always
    // a confirmed, real number — never a guess.
    final double shipping = _shippingFee;
    final double total    = subtotal + shipping;

    final int orderId = await OrderService().createOrder(
  userId:        user.id,
  addressId:     addressId,
  street:        street,
  city:          city,
  postal:        zipCode,
  country:       region,
  items:         items,
  subtotal:      subtotal,
  shipping:      shipping,
  total:         total,
  paymentMethod: paymentMethod,
);

// Buy Now never touched the saved cart, so there's nothing to
// clear — clearing it here would wipe out unrelated items the
// customer separately added via "Add to Bag" but hasn't bought yet.
if (widget.buyNowItem == null) {
  ref.read(customerCartProvider.notifier).clearCart();
}

// Stock was just reserved for these items — refresh the shop's
// product list so anyone browsing (including this same customer,
// if they go back to the product page) sees the real, current
// available quantity instead of a stale cached number.
ref.invalidate(productsProvider);

return orderId;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

        // Buy Now → just the one item, never the saved cart.
    final items = widget.buyNowItem != null
        ? [widget.buyNowItem!]
        : ref.watch(customerCartProvider);

    final double subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    // Tax removed on purpose

    // Tax removed on purpose — only item price + Lalamove shipping
    // fee are charged. `tax` stays as a param passed to Step 2/3
    // below (still 0.0) purely so those widgets' constructors don't
    // need touching, but nothing renders a Tax row anymore.
    final double tax       = 0.0;
    final double shipping = _shippingFee; // ← real Lalamove fee, confirmed before Step 2 is reachable
    final double total    = subtotal + shipping;


      if (items.isEmpty) {
      // Safety net only — for Buy Now this should never actually be
      // empty (a single item is always passed in). For the cart flow,
      // CartSummaryCard already blocks navigation here with a snackbar
      // before this screen is normally reached — this just covers edge
      // cases like the cart emptying in another tab while this screen
      // is already open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Back (system button / browser back) on Review or Payment goes to the
    // PREVIOUS STEP instead of leaving checkout and losing the progress. On
    // Shipping it leaves checkout, as before.
    return PopScope(
      canPop: _currentStep == 1,
onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goToStep(_currentStep - 1);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      appBar: const AppTopBar(activeRoute: 'shop'),
      // The global bottom bar is hidden during checkout: it competed with the
      // progress bar and the content for space on small screens. The top bar
      // and the drawer still let the customer leave.
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = constraints.maxWidth >= 1024;

          return SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48 : 16,
                    vertical: isDesktop ? 32 : 16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Progress bar ─────────────────────────
                        CheckoutProgressBar(
                          currentStep: _currentStep,
                          // Tapping a finished step goes back to it. Nothing the
                          // customer entered is cleared.
                          onStepTap: (int step) {
                            if (step < _currentStep) _goToStep(step);
                          },
                        ),
                        SizedBox(height: isDesktop ? 40 : 20),

                        // ── Step 1 ───────────────────────────────
                        // Step 1 stays alive (only hidden) while the customer is on
                        // Review or Payment, so going back keeps the chosen address
                        // and the shipping fee instead of reloading and re-quoting.
                        Offstage(
                          offstage: _currentStep != 1,
                          child: CheckoutStep1Shipping(
                            initialStreet:   street,
                            initialBarangay: barangay,
                            initialCity:     city,
                            initialProvince: province,
                            initialRegion:   region,
                            initialZipCode:  zipCode,
                            initialLandmark: landmark,
                            items:           items,
                            subtotal:        subtotal,
                            shipping:        shipping,
                            tax:             tax,
                            total:           total,
                            onShippingFeeChanged: _onShippingFeeChanged,
                            onContinue:      _onShippingContinue,
                          ),
                        ),

                        // ── Step 2 ───────────────────────────────
                        if (_currentStep == 2)
                          CheckoutStep2Review(
                            // The name and phone used to be passed as empty text,
                            // which left blank lines in the address card.
                            firstName: customerName,
                            lastName:  '',
                            street:    barangay.isEmpty ? street : '$street, $barangay',
                            city:      [city, province].where((s) => s.isNotEmpty).join(', '),
                            postal:    zipCode,
                            phone:     customerPhone,
                            country:   region,
                            items:     items,
                            subtotal:  subtotal,
                            shipping:  shipping,
                            tax:       tax,
                            total:     total,
                            onContinue:      _onReviewContinue,
                            onEditShipping:  () => _goToStep(1),
                          ),

                        // ── Step 3 ───────────────────────────────
                        if (_currentStep == 3)
                          CheckoutStep3Payment(
                            selectedMethod:  paymentMethod,
                            onMethodChanged: (v) =>
                                setState(() => paymentMethod = v),
                            items:           items,
                            subtotal:        subtotal,
                            shipping:        shipping,
                            tax:             tax,
                            total:           total,
                            customerName:    customerName,
                            customerEmail:   customerEmail,
                            onPlaceOrder:    _onPlaceOrder,
                            onBack:          () => _goToStep(2),
                            onBusyChanged:   (bool busy) {
                              if (mounted) setState(() => _step3Busy = busy);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}