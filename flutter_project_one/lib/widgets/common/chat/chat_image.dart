import 'package:flutter/material.dart';

// ================================================
// CHAT IMAGE
//
// One clickable picture for BOTH chat screens (the customer's support chat and
// the admin Messages screen), so a photo behaves the same whoever sent it:
// click or tap it and it opens large.
//
// The viewer
//   - shows the WHOLE photo, never cropped, fitted to any screen size
//   - can be pinched or scrolled to zoom
//   - closes with the Close button, a click on the dark area around the
//     photo, or Escape on a keyboard
// ================================================

/// The picture inside a chat bubble. Opens the viewer when clicked.
class ChatImage extends StatelessWidget {
  final String url;
  final double width;

  const ChatImage({super.key, required this.url, this.width = 240});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View photo',
      child: Tooltip(
        message: 'View photo',
        child: Stack(
          children: [
            Image.network(
              url,
              key: ValueKey(url),
              width: width,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: width,
                  height: 180,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: width,
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFEEEEEE),
                child: const Icon(Icons.broken_image_outlined,
                    color: Color(0xFF9CA3AF)),
              ),
            ),
            // The whole picture is the button: hand cursor, a soft tint on
            // hover, and reachable with the keyboard.
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showChatImageViewer(context, url),
                  hoverColor: Colors.black.withOpacity(0.08),
                  focusColor: Colors.black.withOpacity(0.10),
                  splashColor: Colors.black.withOpacity(0.12),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [url] in the large viewer.
Future<void> showChatImageViewer(BuildContext context, String url) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close photo',
    barrierColor: Colors.black.withOpacity(0.9),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, __) => _ChatImageViewer(url: url),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _ChatImageViewer extends StatelessWidget {
  final String url;

  const _ChatImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // A click anywhere on the dark area (outside the photo) closes it.
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                  child: Center(
                    child: GestureDetector(
                      // Taps ON the photo do nothing (so zooming and panning
                      // never close it by accident).
                      onTap: () {},
                      child: Semantics(
                        image: true,
                        label: 'Photo, enlarged',
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            url,
                            key: ValueKey(url),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined,
                                        size: 40, color: Colors.white70),
                                    SizedBox(height: 8),
                                    Text(
                                      'We couldn\'t load this photo.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  // Takes focus first, so Escape works straight away.
                  autofocus: true,
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}