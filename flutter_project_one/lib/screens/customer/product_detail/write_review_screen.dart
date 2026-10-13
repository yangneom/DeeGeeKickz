import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/customer/review_providers.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../screens/auth/login_screen.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/customer/product_detail/write_review_form.dart';
import '../../../widgets/common/dialog/app_toast.dart';
class WriteReviewScreen extends ConsumerWidget {
  final int productId;
  final String productName;

  const WriteReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  static const double _mdBreakpoint = 768;
  static const double _formMaxWidth = 680;

  Future<void> _onSubmit(
    BuildContext context,
    WidgetRef ref, {
    required double rating,
    required String title,
    required String body,
    required List<PlatformFile> photos,
  }) async {
    final String reviewText = title.trim().isNotEmpty
        ? '${title.trim()}\n\n${body.trim()}'
        : body.trim();

    // BUG FIX: photos was previously dropped here — submit() didn't
    // even accept a photos param. It now does (see review_providers.dart),
    // and uploads them to Storage before the review row is inserted.
    await ref.read(reviewSubmitProvider.notifier).submit(
          productId: productId,
          rating: rating,
          reviewText: reviewText,
          photos: photos,
        );

    final state = ref.read(reviewSubmitProvider);

    if (!context.mounted) return;

    if (state.errorMessage != null) {
      AppToast.error(
        context,
        state.errorMessage!,
        title: 'Could not submit review',
      );
      ref.read(reviewSubmitProvider.notifier).clearError();
      return;
    }

    // Shown BEFORE leaving this screen. The toast lives above the
    // navigator, so it stays on screen after the page closes.
    AppToast.success(
      context,
      'Thank you for sharing your feedback.',
      title: 'Review submitted',
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(reviewSubmitProvider);

    // Guard: redirect guests who reach this screen directly
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.value?.session != null;

    if (!isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => const LoginScreen()),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= _mdBreakpoint;
            final hPad = isDesktop ? 48.0 : 16.0;

            return SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(hPad, 32, hPad, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop
                        ? _formMaxWidth
                        : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const _SimpleBackButton(),

                      const SizedBox(height: 16),

                      const Text(
                        'WRITE A\nREVIEW',
                        style: TextStyle(
                          fontFamily: 'Archivo Narrow',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          height: 1.05,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        width: 48,
                        height: 3,
                        color: Colors.black,
                      ),

                      const SizedBox(height: 32),

                      WriteReviewForm(
                        productName: productName,
                        externalLoading:
                            submitState.isLoading,
                        onSubmit: ({
                          required double rating,
                          required String title,
                          required String body,
                          required List<PlatformFile>
                              photos,
                        }) =>
                            _onSubmit(
                          context,
                          ref,
                          rating: rating,
                          title: title,
                          body: body,
                          photos: photos,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar:
          const BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Custom AppBar ─────────────────────────────────────────────────

// ── Simple back button — no bar, no border, no logo ────────────────
class _SimpleBackButton extends StatelessWidget {
  const _SimpleBackButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(4),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.black, size: 22),
            SizedBox(width: 6),
            Text(
              'BACK',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}