import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/customer/order_service.dart';
import '../../../services/customer/payment/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/login_screen.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/checkout/checkout_progress_bar.dart';
import 'checkout_step1_shipping.dart';
import 'checkout_step2_review.dart';
import 'checkout_step3_payment.dart';

/// Checkout shell — manages the 3-step flow.
/// Holds all shared state (shipping info, payment method)
/// and passes it down to each step screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

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
  // Starts at the old flat-rate default so totals still render sensibly
  // before Step 1's first quote comes back; Step 1 overwrites this the
  // moment an address is selected.
  double _shippingFee = 10.0;
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
  bool   _customerInfoLoaded = false;  // ← add this flag


  // Add this method to _CheckoutScreenState:
  Future<void> _loadCustomerInfo() async {
    if (_customerInfoLoaded) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final dynamic profile = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          customerName         = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
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


  // ── Payment ───────────────────────────────────────────────────────────
  String paymentMethod = 'gcash';

  // ── Step navigation ───────────────────────────────────────────────────
  void _goToStep(int step) => setState(() => _currentStep = step);

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
  }

  void _onReviewContinue() => setState(() => _currentStep = 3);

  Future<int> _onPlaceOrder() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final items = ref.read(customerCartProvider);

    final double subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    // Real Lalamove-quoted fee, set by Step 1 — NOT the old
    // `subtotal >= 150 ? 0 : 10` flat rule.
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

ref.read(customerCartProvider.notifier).clearCart();

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

    final items = ref.watch(customerCartProvider);

    final double subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    // Tax removed on purpose — only item price + Lalamove shipping
    // fee are charged. `tax` stays as a param passed to Step 2/3
    // below (still 0.0) purely so those widgets' constructors don't
    // need touching, but nothing renders a Tax row anymore.
    final double tax       = 0.0;
    final double shipping = _shippingFee; // ← real Lalamove fee, not flat rate
    final double total    = subtotal + shipping;


    if (items.isEmpty) {
      return Scaffold(
        appBar: const AppTopBar(activeRoute: 'shop'),
        drawer: const AppDrawer(),
        body: const Center(
          child: Text('Your cart is empty.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      appBar: const AppTopBar(activeRoute: 'shop'),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = constraints.maxWidth >= 1024;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48 : 16,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Progress bar ─────────────────────────
                        CheckoutProgressBar(currentStep: _currentStep),
                        const SizedBox(height: 48),

                        // ── Step 1 ───────────────────────────────
                        if (_currentStep == 1)
                          CheckoutStep1Shipping(
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

                        // ── Step 2 ───────────────────────────────
                        if (_currentStep == 2)
                          CheckoutStep2Review(
                            firstName: '',
                            lastName:  '',
                            street:    street,
                            city:      city,
                            postal:    zipCode,
                            phone:     '',
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
    );
  }
}