import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_links.dart';
import '../../common/dialog/app_toast.dart';
import '../../../providers/auth/auth_provider.dart';

/// "Get the app" section for the customer WEBSITE home page.
///
/// Who sees what:
///   - inside the installed app ......... nothing (kIsWeb is false)
///   - logged-in customer on the website  nothing here; they still have the
///                                        "Download the app" link in the footer
///   - guest on a desktop browser ....... QR code + install steps
///   - guest on an Android phone ........ "Download for Android" button + steps
///   - guest on an iPhone ............... a short note (there is no iOS app)
class AppDownloadSection extends ConsumerWidget {
  const AppDownloadSection({super.key});

  static const double _mdBreakpoint = 768;

  static const List<String> _steps = [
    'Download the app file (APK).',
    'Open it. If Android asks, allow installs from this source.',
    'Tap Install, then open DeeGee Kickz.',
  ];

  Future<void> _download(BuildContext context) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppLinks.androidApk),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToast.error(
        context,
        'The download could not be started. Please check your connection and try again.',
        title: 'Download failed',
      );
    }
  }

  Widget _stepsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HOW TO INSTALL (ANDROID)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _steps[i],
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _downloadButton(BuildContext context, {bool fullWidth = false}) {
    final Widget button = ElevatedButton.icon(
      onPressed: () => _download(context),
      icon: const Icon(Icons.android, size: 18),
      label: const Text(
        'Download for Android',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  // Desktop: the QR code, for scanning with a phone.
  Widget _qrPanel(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: QrImageView(
            data: AppLinks.androidApk,
            version: QrVersions.auto,
            size: 150,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Scan with your Android phone',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
        ),

      ],
    );
  }

  Widget _iosNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'The app is available for Android. On iPhone, you can keep '
              'shopping right here on the website.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The installed app never shows this: it is for website visitors only.
    if (!kIsWeb) return const SizedBox.shrink();

    // Logged-in customers don't get the big banner (they have the footer
    // link). currentSession is read synchronously so the section doesn't
    // flash on screen for someone who is already signed in.
    final Session? session = ref.watch(authStateProvider).value?.session ??
        Supabase.instance.client.auth.currentSession;
    if (session != null) return const SizedBox.shrink();

    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPad = screenWidth >= _mdBreakpoint ? 48.0 : 16.0;

    final TargetPlatform platform = defaultTargetPlatform;
    final bool isAndroid = platform == TargetPlatform.android;
    final bool isIos = platform == TargetPlatform.iOS;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 640;

                final Widget textBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GET THE APP',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Shop, track your orders and get updates right from your phone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!isIos) _stepsList(),
                    if (isAndroid) ...[
                      const SizedBox(height: 12),
                      _downloadButton(context, fullWidth: !isWide),
                    ],
                    if (isIos) _iosNote(),
                  ],
                );

                // Phones (Android or iPhone) never show the QR: a phone
                // can't scan its own screen.
                final bool showQr = !isAndroid && !isIos;

                if (isWide && showQr) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: textBlock),
                      const SizedBox(width: 40),
                      _qrPanel(context),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    if (showQr) ...[
                      const SizedBox(height: 24),
                      Center(child: _qrPanel(context)),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}