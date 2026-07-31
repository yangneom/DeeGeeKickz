import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'July 31, 2026';

  static const List<_PolicySection> _sections = [
    _PolicySection(
      'Information We Collect',
      'When you create an account, we collect basic details like your '
          'name, email, and phone number. When you place an order, we '
          'also collect your shipping address and payment confirmation. '
          'We never store your full card number or CVV — that\'s handled '
          'securely by our payment partner.',
    ),
    _PolicySection(
      'How We Use Your Information',
      'We use your information to create your account, process and '
          'deliver your orders, send you updates (like "Order Confirmed" '
          'or "Order Shipped"), respond to your support requests, and '
          'improve your shopping experience.',
    ),
    _PolicySection(
      'How We Share Your Information',
      'We do not sell your personal information to anyone. We only '
          'share limited information with trusted partners who help us '
          'run the app and process payments — never for advertising.',
    ),
    _PolicySection(
      'Keeping Your Data Safe',
      'Your account information is stored securely, with access limits '
          'in place so only the right people (like our support team) can '
          'see the information they actually need to help you. While we '
          'take reasonable steps to protect your data, no method of '
          'online storage is 100% secure.',
    ),
    _PolicySection(
      'Your Rights',
      'You can request to view, update, or delete your personal '
          'account information at any time through your Account '
          'settings or by contacting support — subject to certain '
          'records we\'re required to keep for order history.',
    ),
    _PolicySection(
      'Children\'s Privacy',
      'DeeGeeKickz is not directed at children under 13, and we do not '
          'knowingly collect personal information from anyone under 13.',
    ),
    _PolicySection(
      'Changes to This Policy',
      'We may update this Privacy Policy from time to time. If we make '
          'significant changes, we\'ll notify you within the app or by '
          'email.',
    ),
    _PolicySection(
      'Contact Us',
      'Questions about this Privacy Policy? Reach out to us through '
          'the Support section of the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        children: const [
                          Icon(Icons.arrow_back, size: 18, color: Color(0xFF6B7280)),
                          SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Last updated $_lastUpdated',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 28),
                    ...List.generate(
                      _sections.length,
                      (i) => _SectionBox(section: _sections[i]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection {
  final String title;
  final String body;
  const _PolicySection(this.title, this.body);
}

class _SectionBox extends StatelessWidget {
  final _PolicySection section;
  const _SectionBox({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}