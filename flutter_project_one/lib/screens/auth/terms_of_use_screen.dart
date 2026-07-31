import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  static const String _lastUpdated = 'July 31, 2026';

  static const List<_TermsSection> _sections = [
    _TermsSection(
      'Accepting These Terms',
      'By creating an account or using the DeeGeeKickz app, you agree '
          'to these Terms of Use. If you don\'t agree, please don\'t use '
          'the app.',
    ),
    _TermsSection(
      'Creating an Account',
      'To place an order, you\'ll need to create an account with '
          'accurate information — your name, email, and phone number. '
          'Keep your password to yourself, and you\'re responsible for '
          'anything that happens under your account.',
    ),
    _TermsSection(
      'Orders and Payment',
      'Orders depend on what\'s in stock. Prices shown at checkout may '
          'change without notice. Payments are processed securely '
          'through our payment partner, and placing an order means '
          'you\'re authorizing that charge.',
    ),
    _TermsSection(
      'Cancellations and Returns',
      'You can cancel an order before it\'s shipped. Returns and '
          'exchanges follow the return window and conditions shown in '
          'the app or shared by our support team.',
    ),
    _TermsSection(
      'Reserved Stock',
      'When you place an order, we hold that item for you while your '
          'order is being processed. If payment isn\'t completed in '
          'time, the item may become available to other customers '
          'again.',
    ),
    _TermsSection(
      'Using the App Responsibly',
      'Please don\'t misuse the app — this includes trying to access '
          'accounts or data that aren\'t yours, or interfering with how '
          'the app normally works.',
    ),
    _TermsSection(
      'Account Suspension',
      'We may disable or suspend accounts that violate these terms or '
          'are involved in fraudulent or abusive activity.',
    ),
    _TermsSection(
      'No Warranties',
      'DeeGeeKickz is a student thesis project, provided as-is without '
          'warranties. We\'re not liable for indirect or incidental '
          'damages from using the app.',
    ),
    _TermsSection(
      'Changes to These Terms',
      'We may update these Terms of Use from time to time. Continuing '
          'to use the app after changes are posted means you accept the '
          'updated terms.',
    ),
    _TermsSection(
      'Contact Us',
      'Questions about these Terms of Use? Reach out to us through the '
          'Support section of the app.',
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
                      'Terms of Use',
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

class _TermsSection {
  final String title;
  final String body;
  const _TermsSection(this.title, this.body);
}

class _SectionBox extends StatelessWidget {
  final _TermsSection section;
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