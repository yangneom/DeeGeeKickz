import 'package:flutter/material.dart';

import '../../../models/product_detail_model.dart';
import '../../../screens/customer/product_detail/write_review_screen.dart';

/// Customer reviews section.
/// - Overall rating summary (left on desktop, top on mobile)
/// - Star filter chips (horizontal scroll on mobile)
/// - Sort dropdown
/// - Review cards
/// - Load more button
class ProductReviewsSection extends StatefulWidget {
  final ProductDetailModel product;

  const ProductReviewsSection({super.key, required this.product});

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  static const double _mdBreakpoint = 768;

  int? _selectedStarFilter; // null = all
  _SortOption _sort = _SortOption.mostRecent;
  int _visibleCount = 2;

  List<ProductReview> get _filteredReviews {
    var list = widget.product.reviews;
    if (_selectedStarFilter != null) {
      list = list
          .where((r) => r.rating.round() == _selectedStarFilter)
          .toList();
    }
    switch (_sort) {
      case _SortOption.highestRating:
        list = [...list]..sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortOption.lowestRating:
        list = [...list]..sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case _SortOption.mostRecent:
        break;
    }
    return list;
  }

  Map<int, int> get _starCounts {
    final counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in widget.product.reviews) {
      final star = r.rating.round().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return counts;
  }

  void _openWriteReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(product: widget.product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _filteredReviews;
    final visible = reviews.take(_visibleCount).toList();
    final hasMore = _visibleCount < reviews.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _mdBreakpoint;

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
                  product: widget.product,
                  starCounts: _starCounts,
                  selectedStar: _selectedStarFilter,
                  sort: _sort,
                  reviews: visible,
                  hasMore: hasMore,
                  onStarFilter: (s) =>
                      setState(() => _selectedStarFilter = s),
                  onSort: (s) => setState(() => _sort = s),
                  onLoadMore: () => setState(() => _visibleCount += 2),
                  onWriteReview: () => _openWriteReview(context),
                )
              : _MobileLayout(
                  product: widget.product,
                  starCounts: _starCounts,
                  selectedStar: _selectedStarFilter,
                  sort: _sort,
                  reviews: visible,
                  hasMore: hasMore,
                  onStarFilter: (s) =>
                      setState(() => _selectedStarFilter = s),
                  onSort: (s) => setState(() => _sort = s),
                  onLoadMore: () => setState(() => _visibleCount += 2),
                  onWriteReview: () => _openWriteReview(context),
                ),
        );
      },
    );
  }
}

// ── Desktop layout ───────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final ProductDetailModel product;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ProductReview> reviews;
  final bool hasMore;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;
  final VoidCallback onWriteReview;

  const _DesktopLayout({
    required this.product,
    required this.starCounts,
    required this.selectedStar,
    required this.sort,
    required this.reviews,
    required this.hasMore,
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
            product: product,
            starCounts: starCounts,
            onWriteReview: onWriteReview,
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: _ReviewsList(
            product: product,
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

// ── Mobile layout ────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final ProductDetailModel product;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ProductReview> reviews;
  final bool hasMore;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;
  final VoidCallback onWriteReview;

  const _MobileLayout({
    required this.product,
    required this.starCounts,
    required this.selectedStar,
    required this.sort,
    required this.reviews,
    required this.hasMore,
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
          product: product,
          starCounts: starCounts,
          onWriteReview: onWriteReview,
        ),
        const SizedBox(height: 32),
        _ReviewsList(
          product: product,
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

// ── Rating summary panel ─────────────────────────────────────────

class _RatingSummary extends StatelessWidget {
  final ProductDetailModel product;
  final Map<int, int> starCounts;
  final VoidCallback onWriteReview;

  const _RatingSummary({
    required this.product,
    required this.starCounts,
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
              product.rating.toStringAsFixed(1),
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
                _StarRow(rating: product.rating, size: 20),
                const SizedBox(height: 4),
                Text(
                  'Based on ${product.reviewCount} Reviews',
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

        // ── Write a Review button — now wired ────────────────
        GestureDetector(
          onTap: onWriteReview,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: const Text(
              'WRITE A REVIEW',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reviews list ─────────────────────────────────────────────────

class _ReviewsList extends StatelessWidget {
  final ProductDetailModel product;
  final Map<int, int> starCounts;
  final int? selectedStar;
  final _SortOption sort;
  final List<ProductReview> reviews;
  final bool hasMore;
  final ValueChanged<int?> onStarFilter;
  final ValueChanged<_SortOption> onSort;
  final VoidCallback onLoadMore;

  const _ReviewsList({
    required this.product,
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
              bottom: BorderSide(color: Color(0xFFCFC4C5)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${product.reviewCount} Reviews',
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

        // Review cards
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

        // Load more
        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onLoadMore,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCFC4C5)),
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

// ── Review card ──────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ProductReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E2E2)),
        ),
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
                    review.reviewer.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Text(
                review.date,
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
            review.title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.body,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF4C4546),
            ),
          ),
          if (review.photoUrl != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 80,
              height: 80,
              child: Image.network(
                review.photoUrl!,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.7),
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFEEEEEE)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────

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
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.black : const Color(0xFFCFC4C5),
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