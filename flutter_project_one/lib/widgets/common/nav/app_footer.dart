import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_links.dart';
import '../dialog/app_toast.dart';

/// DeeGee Kickz website footer (shared by every customer page).
///
/// Drop-in replacement for the old AppFooter: same class name and the
/// same `const AppFooter()` constructor, so no screen needs editing.
///
/// Contains ONLY the store's real details:
///   - phone:    0936 962 4027
///   - address:  2nd Floor Aliw Complex, Meycauayan, Philippines, 3020
///   - Facebook: https://www.facebook.com/DeeGeeKickz
/// No other social accounts, emails or opening hours are shown, because
/// the store doesn't have them.
///
/// Responsive: three columns on tablet/desktop, stacked on phones.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  // ── The store's real details (change them here, nowhere else) ──
  static const String _storeName = 'DeeGee Kickz';
  static const String _phoneDisplay = '0936 962 4027';
  // Same number in international format, for the tap-to-call link.
  static const String _phoneDial = '+639369624027';
  static const String _address =
      '2nd Floor Aliw Complex, Meycauayan, Philippines, 3020';
  static const String _facebookUrl = 'https://www.facebook.com/DeeGeeKickz';

  // ── Look ──
  static const Color _background = Colors.white;
  static const Color _heading = Color(0xFF6B7280);
  static const Color _text = Color(0xFF374151);
  static const Color _title = Color(0xFF111827);
  static const Color _link = Color(0xFF2563EB);
  static const Color _divider = Color(0xFFE5E7EB);

  Future<void> _open(BuildContext context, Uri uri) async {
    bool opened = false;
    try {
      // On the web this opens a new browser tab.
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToast.error(
        context,
        'We could not open the link. Please check your connection and try again.',
        title: 'Link unavailable',
      );
    }
  }

  Widget _sectionHeading(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _heading,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: _heading),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: onTap != null ? _link : _text,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: row,
      ),
    );
  }

  Widget _brandColumn() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _storeName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _title,
          ),
        ),
      ],
    );
  }

  Widget _contactColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('CONTACT'),
        _infoRow(
          icon: Icons.phone_outlined,
          label: _phoneDisplay,
          tooltip: 'Call $_phoneDisplay',
          onTap: () => _open(context, Uri(scheme: 'tel', path: _phoneDial)),
        ),
        const SizedBox(height: 12),
        _infoRow(
          icon: Icons.location_on_outlined,
          label: _address,
        ),
      ],
    );
  }

  Widget _socialColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('FOLLOW US'),
        _infoRow(
          icon: Icons.facebook,
          label: 'Facebook',
          tooltip: 'Open DeeGee Kickz on Facebook',
          onTap: () => _open(context, Uri.parse(_facebookUrl)),
        ),
        // Website only (never inside the installed app), and not on iPhone,
        // where there is no iOS app to download.
        if (kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) ...[
          const SizedBox(height: 20),
          _sectionHeading('GET THE APP'),
          _infoRow(
            icon: Icons.android,
            label: 'Download the app',
            tooltip: 'Download the DeeGee Kickz Android app',
            onTap: () => _open(context, Uri.parse(AppLinks.androidApk)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double sidePadding = screenWidth >= 1024
        ? 32
        : screenWidth >= 768
            ? 24
            : 16;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _background,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 40, sidePadding, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 720;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _brandColumn()),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _contactColumn(context)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _socialColumn(context)),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _brandColumn(),
                        const SizedBox(height: 28),
                        _contactColumn(context),
                        const SizedBox(height: 28),
                        _socialColumn(context),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Divider(height: 1, thickness: 1, color: _divider),
                const SizedBox(height: 16),
                Text(
                  '© ${DateTime.now().year} $_storeName. All rights reserved.',
                  style: const TextStyle(fontSize: 12, color: _heading),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}