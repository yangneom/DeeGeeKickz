import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ================================================
// MFA QR VIEW
//
// Draws the QR code for the authenticator app from the provisioning address that
// Supabase itself returned for this enrolment (totp.uri). Nothing is invented or
// rebuilt by hand.
//
// The QR code contains the account's setup secret, so this widget never prints
// it, and it is drawn on a plain white card with a quiet border (scanners need
// that).
//
// If the QR code cannot be drawn, a clear message and a "Try again" button are
// shown instead of a blank box; [onRetry] asks for a fresh setup.
//
// It lives in its own file so the one place that depends on the QR package is
// easy to find.
// ================================================
class MfaQrView extends StatelessWidget {
  final String data;
  final double size;
  final VoidCallback onRetry;

  const MfaQrView({
    super.key,
    required this.data,
    required this.onRetry,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        semanticsLabel: 'QR code for your authenticator app',
        errorStateBuilder: (BuildContext context, Object? error) {
          return SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 28, color: Color(0xFFDC2626)),
                const SizedBox(height: 8),
                const Text(
                  'We couldn\'t draw the QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}