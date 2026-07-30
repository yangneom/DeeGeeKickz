import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/customer/review_providers.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../screens/auth/login_screen.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/customer/product_detail/write_review_form.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage!.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFBA1A1A),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      ref.read(reviewSubmitProvider.notifier).clearError();
      return;
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'REVIEW SUBMITTED — THANK YOU!',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
      appBar: _ReviewAppBar(productName: productName),
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

class _ReviewAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String productName;
  const _ReviewAppBar({required this.productName});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(
          bottom:
              BorderSide(color: Color(0xFFCFC4C5), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Colors.black, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REVIEW',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.black,
                  ),
                ),
                Text(
                  productName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: Color(0xFF4C4546),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Text(
            'DEEGEEKICKZ',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}