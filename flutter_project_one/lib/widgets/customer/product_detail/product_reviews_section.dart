import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../models/review_model.dart';
import '../../../providers/customer/review_providers.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../screens/customer/product_detail/write_review_screen.dart';
import '../../../screens/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../common/dialog/app_toast.dart';
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

  RealtimeChannel? _repliesChannel;
  RealtimeChannel? _newFeedbackChannel;
  late final dynamic _reviewService; // captured once — safe to reuse in dispose()

  @override
  void initState() {
    super.initState();
    _reviewService = ref.read(reviewServiceProvider);
    _repliesChannel = _reviewService.subscribeToFeedbackReplies(() {
      if (!mounted) return;
      ref.invalidate(productReviewsProvider(widget.productId));
    });
    _newFeedbackChannel = _reviewService.subscribeToNewFeedback(widget.productId, () {
      if (!mounted) return;
      ref.invalidate(productReviewsProvider(widget.productId));
      ref.invalidate(productRatingStatsProvider(widget.productId));
    });
  }

  @override
  void dispose() {
    if (_repliesChannel != null) _reviewService.unsubscribe(_repliesChannel!);
    if (_newFeedbackChannel != null) _reviewService.unsubscribe(_newFeedbackChannel!);
    super.dispose();
  }

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

  // BUG FIX: previously read `ref.read(hasUserReviewedProvider(...)).value`
  // synchronously — `.value` on a FutureProvider is null until it resolves,
  // so a fast tap on "Write a Review" could sail through the duplicate
  // check before the provider ever finished loading (defaulting to
  // `false`). This is now `async` and awaits the provider's `.future`,
  // which returns the resolved value (or reuses it if already cached) —
  // no window where an unresolved future is silently treated as "false".
    Future<void> _openWriteReview(BuildContext context) async {
    // Captured synchronously, BEFORE any await — this is what the
    // debugger's confirmed root cause requires. context.mounted only
    // proves THIS widget's element still exists; it does NOT
    // guarantee ScaffoldMessenger.of(context)'s upward ancestor
    // lookup will still succeed if navigation elsewhere tore down
    // the Scaffold while this method's earlier await was in flight.
    // Grabbing the state once, while the tree is still guaranteed
    // stable, sidesteps that lookup entirely.
    // (No Scaffold lookup needed any more: toasts live above the navigator.)
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
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text(
                  'SIGN IN TO LEAVE A REVIEW',
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

        // BUG FIX: await the real resolved value instead of trusting a
    // possibly-null cached `.value`. Also show a lightweight loading
    // state isn't strictly necessary here since this resolves fast
    // once cached, but the await guarantees correctness on first tap.
    bool hasReviewed;
    try {
      if (!mounted) return;
      hasReviewed =
          await ref.read(hasUserReviewedProvider(widget.productId).future);
    } catch (e) {
      // If this widget got disposed WHILE ref.read()'s future was
      // still resolving, the read itself can throw before ever
      // reaching a mounted check placed only after it — this catch
      // is what actually stops that specific case from crashing.
      print('_openWriteReview hasUserReviewedProvider read error: $e');
      return;
    }

       if (!mounted) return;

    if (hasReviewed) {
      AppToast.info(
        context,
        'You have already reviewed this product.',
        title: 'Already reviewed',
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
                      productId: widget.productId,
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
                      productId: widget.productId,
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
  final int productId;
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
    required this.productId,
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
            productId: productId,
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
  final int productId;
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
    required this.productId,
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
          productId: productId,
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
  final int productId;
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
    required this.productId,
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
          ...reviews.map((r) => _ReviewCard(review: r, productId: productId)),

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

class _ReviewCard extends ConsumerStatefulWidget {
  final ReviewModel review;
  final int productId;
  const _ReviewCard({required this.review, required this.productId});

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _expanded = false;
  bool _showReplyBox = false;
  bool _submittingReply = false;
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submittingReply = true);

    final submitReply = ref.read(replySubmitProvider);
    final String? error = await submitReply(
      feedbackId: widget.review.id,
      productId: widget.productId,
      replyText: text,
    );

    if (!mounted) return;
    setState(() => _submittingReply = false);

    if (error != null) {
      AppToast.error(context, error, title: 'Could not send reply');
      return;
    }

    _replyController.clear();
    setState(() => _showReplyBox = false);
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final date =
        '${_monthName(review.createdAt.month)} '
        '${review.createdAt.day}, ${review.createdAt.year}';

    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.value?.session != null;

    final replies = review.replies;
    final bool hasMultiple = replies.length > 1;
    final List<FeedbackReply> visibleReplies =
        _expanded || !hasMultiple ? replies : [replies.last];

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

          // ── Photo / video gallery ────────────────────────────
          // BUG FIX: review.imageUrls was already on the model but
          // never rendered anywhere on this card — this was the
          // missing display step, separate from the upload/parse
          // fixes made earlier.
          _ReviewMediaRow(urls: review.imageUrls),

          // ── Reply thread ──────────────────────────────────
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...visibleReplies.map((reply) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: reply.isStaff
                        ? const Color(0xFFF3F3F4)
                        : const Color(0xFFFAFAFA),
                    border: Border.all(
                      color: reply.isStaff
                          ? const Color(0xFFCFC4C5)
                          : const Color(0xFFE2E2E2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply.isStaff
                            ? 'STORE REPLY'
                            : '${reply.authorName.toUpperCase()} REPLIED',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reply.replyText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF4C4546),
                        ),
                      ),
                    ],
                  ),
                )),
            if (hasMultiple)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _expanded
                        ? 'HIDE REPLIES'
                        : 'VIEW ALL ${replies.length} REPLIES',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.underline,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],

          // ── Reply composer ──────────────────────────────────
          const SizedBox(height: 4),
          if (!_showReplyBox)
            GestureDetector(
              onTap: () {
                if (!isLoggedIn) {
                  AppToast.info(
                    context,
                    'Please sign in to reply to this review.',
                    title: 'Sign in needed',
                  );
                  return;
                }
                setState(() => _showReplyBox = true);
              },
              child: const Text(
                'REPLY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.underline,
                  color: Color(0xFF4C4546),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _replyController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFFCFC4C5)),
                    filled: true,
                    fillColor: const Color(0xFFF3F3F4),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _submittingReply ? null : _submitReply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        color: Colors.black,
                        child: _submittingReply
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SEND',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _submittingReply
                          ? null
                          : () => setState(() {
                                _showReplyBox = false;
                                _replyController.clear();
                              }),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Color(0xFF4C4546),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Media gallery (photos + videos) ──────────────────────────────

bool _isVideoUrl(String url) {
  final String lower = url.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.3gp');
}

class _ReviewMediaRow extends StatelessWidget {
  final List<String> urls;
  const _ReviewMediaRow({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final String url = urls[i];
            final bool isVideo = _isVideoUrl(url);

            return GestureDetector(
              onTap: () => showDialog(
                context: context,
                barrierColor: Colors.black,
                builder: (_) =>
                    _MediaViewerDialog(urls: urls, startIndex: i),
              ),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFEEEEEE),
                child: isVideo
                    // No lightweight way to grab a video's first frame
                    // without an extra thumbnail-generation dependency
                    // — a play icon in the grid is enough to signal
                    // "tap to watch"; full playback happens in the
                    // fullscreen viewer.
                    ? const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Color(0xFF4C4546), size: 30),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFFCFC4C5),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Fullscreen viewer — swipeable across all media in the review ──

class _MediaViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int startIndex;
  const _MediaViewerDialog({required this.urls, required this.startIndex});

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  late final PageController _pageController =
      PageController(initialPage: widget.startIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            itemBuilder: (context, i) {
              final String url = widget.urls[i];
              return _isVideoUrl(url)
                  ? _InlineVideoPlayer(url: url)
                  : InteractiveViewer(
                      child: Center(
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    );
            },
          ),
          Positioned(
            top: 40,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline video player — used inside the fullscreen viewer ───────

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  const _InlineVideoPlayer({required this.url});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Could not play this video.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        ),
      );
    }
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 64),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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