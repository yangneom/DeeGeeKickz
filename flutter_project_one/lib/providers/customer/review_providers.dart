// ================================================
// REVIEW & FEEDBACK PROVIDERS
// Drop-in replacements for the fake data.
//
// File location:
//   lib/providers/review/review_providers.dart
// ================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/review_model.dart';
import '../../models/feedback_model.dart';
import '../../services/customer/review/review_service.dart';
import '../../../services/customer/review/feedback_service.dart';

// ============================================================
// SERVICE SINGLETONS
// ============================================================

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

// ============================================================
// CUSTOMER — PRODUCT REVIEWS
// ============================================================

// Fetches Visible reviews for ONE product.
// Usage: ref.watch(productReviewsProvider(productId))
final productReviewsProvider =
    FutureProvider.family<List<ReviewModel>, int>((ref, productId) async {
  final service = ref.watch(reviewServiceProvider);
  return service.fetchProductReviews(productId);
});

// Aggregate rating stats for a product (avg + count).
// Usage: ref.watch(productRatingStatsProvider(productId))
final productRatingStatsProvider = FutureProvider.family<
    ({double average, int count}), int>((ref, productId) async {
  final service = ref.watch(reviewServiceProvider);
  return service.fetchProductRatingStats(productId);
});

// Whether the current user already reviewed this product.
// Usage: ref.watch(hasUserReviewedProvider(productId))
final hasUserReviewedProvider =
    FutureProvider.family<bool, int>((ref, productId) async {
  final service = ref.watch(reviewServiceProvider);
  return service.hasUserReviewed(productId);
});

// ============================================================
// CUSTOMER — REVIEW SUBMISSION NOTIFIER
// Wraps submitReview / updateReview so the UI can
// observe loading + error state.
// ============================================================

class ReviewSubmitState {
  final bool isLoading;
  final String? errorMessage;
  final bool submitted;

  const ReviewSubmitState({
    this.isLoading = false,
    this.errorMessage,
    this.submitted = false,
  });

  ReviewSubmitState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? submitted,
  }) {
    return ReviewSubmitState(
      isLoading:    isLoading    ?? this.isLoading,
      errorMessage: errorMessage,       // always overwrite (null clears)
      submitted:    submitted    ?? this.submitted,
    );
  }
}

class ReviewSubmitNotifier extends Notifier<ReviewSubmitState> {
  @override
  ReviewSubmitState build() => const ReviewSubmitState();

  Future<void> submit({
    required int productId,
    required double rating,
    required String reviewText,
  }) async {
    state = state.copyWith(isLoading: true, submitted: false);

    final service = ref.read(reviewServiceProvider);
    final String? error = await service.submitReview(
      productId:  productId,
      rating:     rating,
      reviewText: reviewText,
    );

    if (error != null) {
      state = state.copyWith(isLoading: false, errorMessage: error);
    } else {
      state = state.copyWith(isLoading: false, submitted: true);
      // Invalidate so the review list auto-refreshes
      ref.invalidate(productReviewsProvider(productId));
      ref.invalidate(productRatingStatsProvider(productId));
      ref.invalidate(hasUserReviewedProvider(productId));
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final reviewSubmitProvider =
    NotifierProvider<ReviewSubmitNotifier, ReviewSubmitState>(() {
  return ReviewSubmitNotifier();
});

// ============================================================
// CUSTOMER — ADD REPLY TO THREAD
// Refreshes this product's review list on success so the new
// reply shows up immediately without a manual reload.
// ============================================================
typedef ReplySubmitFn = Future<String?> Function({
  required int feedbackId,
  required int productId,
  required String replyText,
});

final replySubmitProvider = Provider<ReplySubmitFn>((ref) {
  return ({required feedbackId, required productId, required replyText}) async {
    final service = ref.read(reviewServiceProvider);
    final String? error = await service.addReply(
      feedbackId: feedbackId,
      replyText: replyText,
    );
    if (error == null) {
      ref.invalidate(productReviewsProvider(productId));
    }
    return error;
  };
});

// ============================================================
// ADMIN — ALL FEEDBACK
// ============================================================

// Raw list — all feedback, no filter.
final feedbackProvider =
    FutureProvider<List<FeedbackModel>>((ref) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.fetchFeedback();
});

// Recent feedback for the dashboard card.
final recentFeedbackProvider =
    FutureProvider<List<FeedbackModel>>((ref) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.fetchRecentFeedback(limit: 5);
});

// ============================================================
// ADMIN — FEEDBACK FILTER STATE
// Mirrors the existing _selectedStatus + search logic
// but lifted to a provider so FeedbackScreen stays stateless.
// ============================================================

class FeedbackFilterState {
  final String searchQuery;
  final String? selectedStatus;

  const FeedbackFilterState({
    this.searchQuery  = '',
    this.selectedStatus,
  });

  FeedbackFilterState copyWith({
    String? searchQuery,
    String? Function()? selectedStatus, // nullable setter trick
  }) {
    return FeedbackFilterState(
      searchQuery:    searchQuery    ?? this.searchQuery,
      selectedStatus: selectedStatus != null
                        ? selectedStatus()
                        : this.selectedStatus,
    );
  }
}

class FeedbackFilterNotifier extends Notifier<FeedbackFilterState> {
  @override
  FeedbackFilterState build() => const FeedbackFilterState();

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatus(String? status) {
    state = state.copyWith(selectedStatus: () => status);
  }

  void clear() {
    state = const FeedbackFilterState();
  }
}

final feedbackFilterProvider =
    NotifierProvider<FeedbackFilterNotifier, FeedbackFilterState>(() {
  return FeedbackFilterNotifier();
});

// ── Derived: filtered list (replaces _applyFilters in the screen) ──
final filteredFeedbackProvider =
    Provider<AsyncValue<List<FeedbackModel>>>((ref) {
  final filter   = ref.watch(feedbackFilterProvider);
  final allAsync = ref.watch(feedbackProvider);

  return allAsync.whenData((all) {
    final query = filter.searchQuery.toLowerCase();

    return all.where((item) {
      // search
      final bool matchesSearch = query.isEmpty ||
          item.customerName.toLowerCase().contains(query) ||
          item.productName.toLowerCase().contains(query);

      // status filter
      final bool matchesStatus = filter.selectedStatus == null ||
          item.status == filter.selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  });
});

// ============================================================
// ADMIN — FEEDBACK MODERATION NOTIFIER
// Wraps saveReply + updateStatus so dialogs can
// observe loading + error state.
// ============================================================

class FeedbackModerationState {
  final bool isLoading;
  final String? errorMessage;
  final bool saved;

  const FeedbackModerationState({
    this.isLoading    = false,
    this.errorMessage,
    this.saved        = false,
  });

  FeedbackModerationState copyWith({
    bool?   isLoading,
    String? errorMessage,
    bool?   saved,
  }) {
    return FeedbackModerationState(
      isLoading:    isLoading    ?? this.isLoading,
      errorMessage: errorMessage,
      saved:        saved        ?? this.saved,
    );
  }
}

class FeedbackModerationNotifier
    extends Notifier<FeedbackModerationState> {
  @override
  FeedbackModerationState build() => const FeedbackModerationState();

  Future<void> saveReply({
    required int    feedbackId,
    required String newStatus,
    required String currentStatus,
    required String adminReply,
  }) async {
    state = state.copyWith(isLoading: true, saved: false);

    final service = ref.read(feedbackServiceProvider);
    final String? error = await service.saveReply(
      feedbackId:    feedbackId,
      adminReply:    adminReply,
      currentStatus: currentStatus,
      newStatus:     newStatus,
    );

    if (error != null) {
      state = state.copyWith(isLoading: false, errorMessage: error);
    } else {
      state = state.copyWith(isLoading: false, saved: true);
      // Refresh the admin list
      ref.invalidate(feedbackProvider);
      ref.invalidate(recentFeedbackProvider);
    }
  }

  void reset() {
    state = const FeedbackModerationState();
  }
}

final feedbackModerationProvider =
    NotifierProvider<FeedbackModerationNotifier, FeedbackModerationState>(
        () => FeedbackModerationNotifier());