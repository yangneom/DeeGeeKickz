import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';

/// "Profile Information" card — full name, email, contact number.
/// Matches the HTML mockup section with an Edit button top-right.
class ProfileInfoSection extends StatelessWidget {
  final CustomerAccount account;

  const ProfileInfoSection({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return _SectionCard(
      title: 'Profile Information',
      actionLabel: 'Edit',
      onAction: () {
        // TODO: open edit profile dialog/sheet
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isDesktop) {
            // 2-column grid on desktop
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoField(
                        label: 'Full Name',
                        value: account.fullName,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _InfoField(
                        label: 'Email Address',
                        value: account.email,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoField(
                        label: 'Contact Number',
                        value: account.phone,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            );
          }

          // Single-column on mobile
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoField(label: 'Full Name', value: account.fullName),
              const SizedBox(height: 16),
              _InfoField(label: 'Email Address', value: account.email),
              const SizedBox(height: 16),
              _InfoField(label: 'Contact Number', value: account.phone),
            ],
          );
        },
      ),
    );
  }
}

// ─── Reusable label + value field ────────────────────────────────────────────

class _InfoField extends StatelessWidget {
  final String label;
  final String value;

  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: Color(0xFF656464), // on-secondary-container
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

// ─── Shared section card shell ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final padding = isDesktop ? 48.0 : 16.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white, // surface-container-lowest
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),

          // Content
          child,
        ],
      ),
    );
  }
}