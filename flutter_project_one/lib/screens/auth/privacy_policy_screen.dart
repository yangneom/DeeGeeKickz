// ============================================================================
// privacy_policy_screen.dart
//
// This is a simple, static screen that displays the Privacy Policy for the
// DeeGeeKickz shoe store app. It gets pushed onto the navigation stack
// whenever the user taps the "Privacy Policy" link on the sign-up screen.
//
// WHY StatelessWidget?
// This screen doesn't need to change anything while it's on screen (no
// setState(), no user input, no timers) -- it just shows text. So we use
// StatelessWidget instead of StatefulWidget. StatefulWidget is only needed
// when a widget has to "remember" and update its own data over time.
// ============================================================================

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  // "const" constructor -- this tells Flutter that this widget never
  // changes its own properties, so Flutter can reuse the same instance
  // instead of rebuilding it, which is a small performance optimization.
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold gives us the basic screen "skeleton": an AppBar on top and
    // a body underneath. Almost every full screen in Flutter starts here.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        // elevation: 0 removes the little shadow line under the AppBar so
        // it looks flat/clean, matching the minimal style of the sign-up
        // screen in the mockup.
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      // SafeArea makes sure our content doesn't get hidden behind notches,
      // status bars, or rounded corners on different phones.
      body: SafeArea(
        // SingleChildScrollView lets the user scroll if the text is longer
        // than the screen. Without this, long text would just overflow
        // and Flutter would show a red/yellow "overflow" error.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // crossAxisAlignment.start makes all children (text blocks)
            // align to the left, instead of centering them.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DeeGeeKickz Privacy Policy',
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

              // Each _sectionTitle + _sectionBody pair below is just a
              // reusable pattern: a bold heading, then a paragraph of
              // regular text underneath it. Building it this way means
              // if you want to add a new section later, you just copy
              // one of these pairs and change the words.
              _sectionTitle('1. Information We Collect'),
              _sectionBody(
                'When you create a DeeGeeKickz account, we collect the '
                'information you provide directly, such as your first name, '
                'last name, email address, and phone number. When you place '
                'an order, we also collect your shipping address and '
                'payment confirmation details processed through our '
                'payment partner (PayMongo). We do not store your full '
                'card number or CVV on our own servers.',
              ),

              _sectionTitle('2. How We Use Your Information'),
              _sectionBody(
                'We use the information you provide to create and manage '
                'your account, process and deliver your shoe orders, send '
                'order status updates (such as confirmation, packed, '
                'shipped, and delivered notifications), respond to your '
                'support requests, and improve the overall shopping '
                'experience in the app.',
              ),

              _sectionTitle('3. How We Share Your Information'),
              _sectionBody(
                'We do not sell your personal information to third '
                'parties. We may share limited information with trusted '
                'service providers who help us operate the app, such as '
                'our database provider (Supabase) and our payment '
                'processor (PayMongo), solely for the purpose of running '
                'DeeGeeKickz.',
              ),

              _sectionTitle('4. Data Storage and Security'),
              _sectionBody(
                'Your account information is stored securely using '
                'Supabase, with access controls (Row Level Security) in '
                'place so that customers, cashiers, admins, and super '
                'admins can only see the data that is relevant to their '
                'role. While we take reasonable steps to protect your '
                'data, no method of electronic storage is 100% secure.',
              ),

              _sectionTitle('5. Your Rights'),
              _sectionBody(
                'You may request to view, update, or delete your personal '
                'account information at any time by contacting store '
                'support or through your Account settings, subject to '
                'certain records we are required to keep for order and '
                'payment history.',
              ),

              _sectionTitle('6. Children\'s Privacy'),
              _sectionBody(
                'DeeGeeKickz is not directed at children under the age of '
                '13, and we do not knowingly collect personal information '
                'from children under 13.',
              ),

              _sectionTitle('7. Changes to This Policy'),
              _sectionBody(
                'We may update this Privacy Policy from time to time. If '
                'we make significant changes, we will notify you within '
                'the app or by email.',
              ),

              _sectionTitle('8. Contact Us'),
              _sectionBody(
                'If you have any questions about this Privacy Policy, '
                'please reach out to us through the Support section of '
                'the app.',
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // A small helper function that returns a bold section heading Widget.
  // Pulling this out into its own function avoids repeating the same
  // TextStyle code eight times in the build() method above.
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

  // Another small helper, this time for the regular paragraph text under
  // each heading.
  Widget _sectionBody(String body) {
    return Text(
      body,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5, // line height -- makes paragraphs easier to read
        color: Colors.black87,
      ),
    );
  }

  // Just formats today's date as a simple placeholder "last updated" date.
  // In a real app you'd likely hardcode this to whenever you actually last
  // changed the policy, rather than always showing "today".
  String _lastUpdated() {
    final now = DateTime.now();
    return '${now.month}/${now.day}/${now.year}';
  }
}