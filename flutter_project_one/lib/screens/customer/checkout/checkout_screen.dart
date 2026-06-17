import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/customer/order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  ConsumerState<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState
    extends ConsumerState<CheckoutScreen> {
  // ── Step tracker ─────────────────────────────────────────────────────
  int _currentStep = 1;

  // ── Shared state passed between steps ────────────────────────────────
  String firstName = '';
  String lastName = '';
  String street = '';
  String city = '';
  String postal = '';
  String phone = '';
  String country = 'Philippines';
  String paymentMethod = 'gcash';

  // ── Step navigation ───────────────────────────────────────────────────
  void _goToStep(int step) => setState(() => _currentStep = step);

  void _onShippingContinue({
    required String fn,
    required String ln,
    required String st,
    required String ct,
    required String ps,
    required String ph,
    required String co,
  }) {
    setState(() {
      firstName = fn;
      lastName = ln;
      street = st;
      city = ct;
      postal = ps;
      phone = ph;
      country = co;
      _currentStep = 2;
    });
  }

  void _onReviewContinue() => setState(() => _currentStep = 3);

Future<void> _onPlaceOrder() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final items = ref.read(customerCartProvider);

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    final shipping = subtotal >= 150 ? 0.0 : 10.0;

    final total = subtotal + shipping;

    final service = OrderService();

    final orderId = await service.createOrder(
      userId: user.id,

      street: street,
      city: city,
      postal: postal,
      country: country,

      items: items,

      subtotal: subtotal,
      shipping: shipping,
      total: total,
    );

    ref.read(customerCartProvider.notifier).clearCart();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #$orderId placed successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to place order: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(customerCartProvider);

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    final tax = subtotal * 0.08;
    final shipping = subtotal >= 150 ? 0.0 : 10.0;
    final total = subtotal + tax + shipping;

    if (items.isEmpty) {
      return Scaffold(
        appBar: const AppTopBar(activeRoute: 'shop'),
        drawer: const AppDrawer(),
        body: const Center(
          child: Text(
            'Your cart is empty.',
          ),
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
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

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
                        // ── Progress bar ───────────────────────────
                        CheckoutProgressBar(currentStep: _currentStep),
                        const SizedBox(height: 48),

                        // ── Active step ────────────────────────────
                        if (_currentStep == 1)
                          CheckoutStep1Shipping(
                            initialFirstName: firstName,
                            initialLastName: lastName,
                            initialStreet: street,
                            initialCity: city,
                            initialPostal: postal,
                            initialPhone: phone,
                            initialCountry: country,
                            items: items,
                            subtotal: subtotal,
                            shipping: shipping,
                            tax: tax,
                            total: total,
                            onContinue: _onShippingContinue,
                          ),

                        if (_currentStep == 2)
                          CheckoutStep2Review(
                            firstName: firstName,
                            lastName: lastName,
                            street: street,
                            city: city,
                            postal: postal,
                            phone: phone,
                            country: country,
                            items: items,
                            subtotal: subtotal,
                            shipping: shipping,
                            tax: tax,
                            total: total,
                            onContinue: _onReviewContinue,
                            onEditShipping: () => _goToStep(1),
                          ),

                        if (_currentStep == 3)
                          CheckoutStep3Payment(
                            selectedMethod: paymentMethod,
                            onMethodChanged: (v) =>
                                setState(() => paymentMethod = v),
                            items: items,
                            subtotal: subtotal,
                            shipping: shipping,
                            tax: tax,
                            total: total,
                            onPlaceOrder: _onPlaceOrder,
                            onBack: () => _goToStep(2),
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