import 'package:deepar_shoe_try_on_flutter/deepar_shoe_try_on_flutter.dart';
import 'package:flutter/material.dart';

/// Full-screen AR camera try-on view.
/// Loads the given .deepar shoe effect link and overlays it live on the
/// user's foot via the camera.
class TryOnScreen extends StatelessWidget {
  final String effectUrl;
  final String productName;

  const TryOnScreen({
    super.key,
    required this.effectUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            DeepARShoeTryOnPreview(link: Uri.parse(effectUrl)),

            // ── Top bar: close button + product name ──
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}