import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/review_model.dart';
import '../../../providers/customer/review_providers.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../screens/customer/product_detail/write_review_screen.dart';
import '../../../screens/auth/login_screen.dart';

class ProductReviewsSection extends ConsumerStatefulWidget {
  final int productId;
  final String productName;

  const ProductReviewsSection({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState
    extends ConsumerState<ProductReviewsSection> {
  static const double _mdBreakpoint = 768;

  int? _selectedStarFilter;
  _SortOption _sort = _SortOption.mostRecent;
  int _visibleCount = 2;

  List<ReviewModel> _applyFilterSort(List<ReviewModel> all) {
    var list = [...all];

    if (_selectedStarFilter != null) {
      list = list
          .where((r) => r.rating.round() == _selectedStarFilter)
          .toList();
    }

    switch (_sort) {
      case _SortOption.highestRating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortOption.lowestRating:
        list.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case _SortOption.mostRecent:
        break;
    }

    return list;
  }

  Map<int, int> _starCounts(List<ReviewModel> reviews) {
    final counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final star = r.rating.round().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return counts;
  }

  void _openWriteReview(BuildContext context) {
    final authState = ref.read(authStateProvider);
    final isLoggedIn = authState.value?.session != null;

    if (!isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIGN IN TO REVIEW',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only registered customers can leave a review. '
                  'Please sign in or create an account to share '
                  'your experience.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF4C4546),
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Text(
                      'SIGN IN',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFCFC4C5)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Check if already reviewed
    final hasReviewed =
        ref.read(hasUserReviewedProvider(widget.productId)).value ??
            false;

    if (hasReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reviewed this product.'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          productId: widget.productId,
          productName: widget.productName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync =
        ref.watch(productReviewsProvider(widget.productId));
    final statsAsync =
        ref.watch(productRatingStatsProvider(widget.productId));

    // Auth state for button label
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.value?.session != null;

    return reviewsAsync.when(
      loading: () => const _LoadingSection(),
      error: (e, _) => _ErrorSection(message: e.toString()),
      data: (allReviews) {
        final filtered = _applyFilterSort(allReviews);
        final visible = filtered.take(_visibleCount).toList();
        final hasMore = _visibleCount < filtered.length;
        final starCounts = _starCounts(allReviews);

        final double avgRating = statsAsync.value?.average ??
            (allReviews.isEmpty
                ? 0.0
                : allReviews.fold(
                        0.0, (s, r) => s + r.rating) /
                    allReviews.length);
        final int reviewCount =
            statsAsync.value?.count ?? allReviews.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= _mdBreakpoint;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFCFC4C5)),
                ),
              ),
              child: isDesktop
                  ? _DesktopLayout(
                      avgRating: avgRating,
                      reviewCount: reviewCount,
                      starCounts: starCounts,
                      selectedStar: _selectedStarFilter,
                      sort: _sort,
                      reviews: visible,
                      hasMore: hasMore,
                      isLoggedIn: isLoggedIn,
                      onStarFilter: (s) => setState(
                          () => _selectedStarFilter = s),
                      onSort: (s) => setState(() => _sort = s),
                      onLoadMore: () =>
                          setState(() => _visibleCount += 2),
                      onWriteReview: () =>
                          _openWriteReview(context),
                    )
                  : _MobileLayout(
                      avgRating: avgRating,
                      reviewCount: reviewCount,
                      starCounts: starCounts,
                      selectedStar: _selectedStarFilter,
                      sort: _sort,
                      reviews: visible,
                      hasMore: hasMore,
                      isLoggedIn: isLoggedIn,
                      onStarFilter: (s) => setState(
                          () => _selectedStarFilter = s),
                      onSort: (s) => setState(() => _sort = s),
                      onLoadMore: () =>
                          setState(() => _visibleCount += 2),
                      onWriteReview: () =>
                          _openWriteReview(context),
                    ),
            );
          },
        );
      },
    );
  }
}

// ── Loading / error ───────────────────────────────────────────────

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
          child: CircularProgressIndicator(color: Colors.black)),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String message;
  const _ErrorSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Text(
        'Could not load reviews.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Color(0xFF4C4546),
        ),
      ),
    );
  }
}

// ── Desktop layout ────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ReviewModel> reviews;
  final bool hasMore;
  final bool isLoggedIn;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;
  final VoidCallback onWriteReview;

  const _DesktopLayout({
    required this.avgRating,
    required this.reviewCount,
    required this.starCounts,
    required this.selectedStar,
    required this.sort,
    required this.reviews,
    required this.hasMore,
    required this.isLoggedIn,
    required this.onStarFilter,
    required this.onSort,
    required this.onLoadMore,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: _RatingSummary(
            avgRating: avgRating,
            reviewCount: reviewCount,
            isLoggedIn: isLoggedIn,
            onWriteReview: onWriteReview,
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: _ReviewsList(
            reviewCount: reviewCount,
            starCounts: starCounts,
            selectedStar: selectedStar,
            sort: sort,
            reviews: reviews,
            hasMore: hasMore,
            onStarFilter: onStarFilter,
            onSort: onSort,
            onLoadMore: onLoadMore,
          ),
        ),
      ],
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ReviewModel> reviews;
  final bool hasMore;
  final bool isLoggedIn;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;
  final VoidCallback onWriteReview;

  const _MobileLayout({
    required this.avgRating,
    required this.reviewCount,
    required this.starCounts,
    required this.selectedStar,
    required this.sort,
    required this.reviews,
    required this.hasMore,
    required this.isLoggedIn,
    required this.onStarFilter,
    required this.onSort,
    required this.onLoadMore,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RatingSummary(
          avgRating: avgRating,
          reviewCount: reviewCount,
          isLoggedIn: isLoggedIn,
          onWriteReview: onWriteReview,
        ),
        const SizedBox(height: 32),
        _ReviewsList(
          reviewCount: reviewCount,
          starCounts: starCounts,
          selectedStar: selectedStar,
          sort: sort,
          reviews: reviews,
          hasMore: hasMore,
          onStarFilter: onStarFilter,
          onSort: onSort,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }
}

// ── Rating summary panel ──────────────────────────────────────────

class _RatingSummary extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final bool isLoggedIn;
  final VoidCallback onWriteReview;

  const _RatingSummary({
    required this.avgRating,
    required this.reviewCount,
    required this.isLoggedIn,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CUSTOMER\nREVIEWS',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            height: 1.1,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 64,
                fontWeight: FontWeight.w700,
                height: 1,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarRow(rating: avgRating, size: 20),
                const SizedBox(height: 4),
                Text(
                  'Based on $reviewCount Reviews',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF4C4546),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: onWriteReview,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isLoggedIn
                  ? Colors.black
                  : Colors.transparent,
              border: Border.all(color: Colors.black),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLoggedIn) ...[
                  const Icon(Icons.lock_outline,
                      size: 14, color: Colors.black),
                  const SizedBox(width: 6),
                ],
                Text(
                  isLoggedIn
                      ? 'WRITE A REVIEW'
                      : 'SIGN IN TO REVIEW',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: isLoggedIn
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reviews list ──────────────────────────────────────────────────

class _ReviewsList extends StatelessWidget {
  final int reviewCount;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ReviewModel> reviews;
  final bool hasMore;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;

  const _ReviewsList({
    required this.reviewCount,
    required this.starCounts,
    required this.selectedStar,
    required this.sort,
    required this.reviews,
    required this.hasMore,
    required this.onStarFilter,
    required this.onSort,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Star filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All Reviews',
                isActive: selectedStar == null,
                onTap: () => onStarFilter(null),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (i) {
                final star = 5 - i;
                final count = starCounts[star] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: '$star Stars ($count)',
                    isActive: selectedStar == star,
                    onTap: () => onStarFilter(star),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Sort row
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Color(0xFFCFC4C5))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $reviewCount Reviews',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Sort by: ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  DropdownButton<_SortOption>(
                    value: sort,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _SortOption.mostRecent,
                        child: Text('Most Recent'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.highestRating,
                        child: Text('Highest Rating'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.lowestRating,
                        child: Text('Lowest Rating'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) onSort(v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No reviews match this filter.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Color(0xFF4C4546),
              ),
            ),
          )
        else
          ...reviews.map((r) => _ReviewCard(review: r)),

        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onLoadMore,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFCFC4C5)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'LOAD MORE REVIEWS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Review card ───────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final date =
        '${_monthName(review.createdAt.month)} '
        '${review.createdAt.day}, ${review.createdAt.year}';

    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFFE2E2E2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StarRow(rating: review.rating, size: 16),
                  const SizedBox(height: 4),
                  Text(
                    review.customerName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                  if (review.verifiedPurchase) ...[
                    const SizedBox(height: 2),
                    const Text(
                      '✓ VERIFIED PURCHASE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Color(0xFF4C9A4C),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                date,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF4C4546),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.reviewText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF4C4546),
            ),
          ),
          if (review.adminReply != null &&
              review.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F4),
                border: Border.all(
                    color: const Color(0xFFCFC4C5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STORE REPLY',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.adminReply!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }
}

// ── Shared helpers ────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half
              ? Icons.star_half
              : (filled ? Icons.star : Icons.star_border),
          size: size,
          color: Colors.black,
        );
      }),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          border: Border.all(
            color: isActive
                ? Colors.black
                : const Color(0xFFCFC4C5),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

enum _SortOption { mostRecent, highestRating, lowestRating }