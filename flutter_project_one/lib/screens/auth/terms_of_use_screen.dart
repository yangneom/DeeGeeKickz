// ============================================================================
// terms_of_use_screen.dart
//
// This is the sibling screen to privacy_policy_screen.dart. It shows the
// Terms of Use for DeeGeeKickz and gets pushed onto the navigation stack
// when the user taps "Terms of Use" on the sign-up screen.
//
// It follows the exact same structure as PrivacyPolicyScreen on purpose --
// once you understand one of these two files, you already understand the
// other. Keeping the pattern identical makes the code easier to maintain.
// ============================================================================

import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DeeGeeKickz Terms of Use',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${_lastUpdated()}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),

              _sectionTitle('1. Acceptance of Terms'),
              _sectionBody(
                'By creating an account or using the DeeGeeKickz app, you '
                'agree to be bound by these Terms of Use. If you do not '
                'agree to these terms, please do not use the app.',
              ),

              _sectionTitle('2. Account Registration'),
              _sectionBody(
                'To place an order, you must create an account with '
                'accurate and complete information, including your name, '
                'email address, and phone number. You are responsible for '
                'keeping your password confidential and for all activity '
                'that happens under your account.',
              ),

              _sectionTitle('3. Orders and Payment'),
              _sectionBody(
                'All orders placed through DeeGeeKickz are subject to '
                'product availability. Prices are shown in the app at the '
                'time of purchase and may change without prior notice. '
                'Payments are processed securely through our payment '
                'partner, PayMongo. Placing an order authorizes us to '
                'charge the payment method you provide.',
              ),

              _sectionTitle('4. Order Cancellations and Returns'),
              _sectionBody(
                'Orders may be cancelled before they are marked as shipped, '
                'subject to store policy. Returns or exchanges are handled '
                'according to the return window and conditions communicated '
                'in-app or by store staff at the time of purchase.',
              ),

              _sectionTitle('5. Reserved Stock'),
              _sectionBody(
                'When you place an online order, the corresponding stock '
                'is temporarily reserved for you so it is not sold to '
                'another customer while your order is being processed. '
                'This reservation may be released if payment is not '
                'completed within the required time frame.',
              ),

              _sectionTitle('6. User Conduct'),
              _sectionBody(
                'You agree not to misuse the app, including attempting to '
                'access accounts, data, or systems that do not belong to '
                'you, or interfering with the normal operation of the app.',
              ),

              _sectionTitle('7. Account Suspension'),
              _sectionBody(
                'We reserve the right to disable or archive accounts that '
                'violate these Terms of Use or that are involved in '
                'fraudulent or abusive activity.',
              ),

              _sectionTitle('8. Limitation of Liability'),
              _sectionBody(
                'DeeGeeKickz is provided on an "as is" basis. As a student '
                'thesis project, the app and its services are provided '
                'without warranties of any kind, and we are not liable for '
                'indirect or incidental damages arising from your use of '
                'the app.',
              ),

              _sectionTitle('9. Changes to These Terms'),
              _sectionBody(
                'We may update these Terms of Use from time to time. '
                'Continued use of the app after changes are posted means '
                'you accept the updated terms.',
              ),

              _sectionTitle('10. Contact Us'),
              _sectionBody(
                'If you have questions about these Terms of Use, please '
                'reach out to us through the Support section of the app.',
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionBody(String body) {
    return Text(
      body,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Colors.black87,
      ),
    );
  }

  String _lastUpdated() {
    final now = DateTime.now();
    return '${now.month}/${now.day}/${now.year}';
  }
}