import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';
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
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
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

  // ── Mock cart items ───────────────────────────────────────────────────
  final List<CustomerCartItem> _items = List.from(mockCustomerCartItems);

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get _tax => _subtotal * 0.08;
  double get _shipping => _subtotal >= 150 ? 0.0 : 10.0;
  double get _total => _subtotal + _tax + _shipping;

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

  void _onPlaceOrder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ORDER PLACED — PayMongo integration coming soon.',
          style: TextStyle(fontFamily: 'Inter', letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                            items: _items,
                            subtotal: _subtotal,
                            shipping: _shipping,
                            tax: _tax,
                            total: _total,
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
                            items: _items,
                            subtotal: _subtotal,
                            shipping: _shipping,
                            tax: _tax,
                            total: _total,
                            onContinue: _onReviewContinue,
                            onEditShipping: () => _goToStep(1),
                          ),

                        if (_currentStep == 3)
                          CheckoutStep3Payment(
                            selectedMethod: paymentMethod,
                            onMethodChanged: (v) =>
                                setState(() => paymentMethod = v),
                            items: _items,
                            subtotal: _subtotal,
                            shipping: _shipping,
                            tax: _tax,
                            total: _total,
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