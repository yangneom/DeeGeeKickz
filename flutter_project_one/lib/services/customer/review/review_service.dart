// ================================================
// REVIEW SERVICE
// Customer-facing Supabase operations for the
// `feedback` table.
//
// Naming note: the table is called `feedback` in Supabase
// but the customer-facing concept is "review".
//
// BUG FIX — submitReview():
//   Now that the DB has a unique (user_id, product_id) constraint,
//   a raced double-submit (double-tap, or a retry after a timeout
//   that actually succeeded) will hit the insert AFTER the
//   pre-check passes, and Postgres will reject it with error code
//   23505 (unique_violation). Caught specifically and returns the
//   same friendly "already reviewed" message as the pre-check does.
//
// BUG FIX — _notifyStaffNewFeedback() / _notifyStaffFeedbackReply():
//   Both used to do 2-3 sequential network calls (name/product
//   lookup, then staff lookup, then insert) before anything
//   committed. If the browser switched accounts mid-sequence
//   (common during rapid admin/customer testing), the request got
//   cut off with no error and no notification ever written.
//   Both are now single RPC calls — the whole lookup+insert
//   sequence runs atomically on the server in one request, so a
//   fast account switch on the client can no longer interrupt it.
// ================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/review_model.dart';

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── SELECT helper — joins user + product names ─────────────
  static const String _selectWithJoins = '''
    feedback_id,
    user_id,
    product_id,
    rating,
    comment_message,
    image_urls,
    verified_purchase,
    status,
    admin_reply,
    created_at,
    updated_at,
    users (
      first_name,
      last_name
    ),
    product (
      product_name
    ),
    feedback_replies (
      reply_id,
      reply_text,
      created_at,
      users (
        first_name,
        last_name,
        role
      )
    )
  ''';

  // ── Realtime: new replies on any review (used to refresh whichever
  // product page is currently open, since feedback_replies has no
  // product_id column to filter on directly) ──
  RealtimeChannel subscribeToFeedbackReplies(void Function() onInsert) {
    return _supabase
        .channel('feedback_replies:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feedback_replies',
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  // ── Realtime: new reviews for THIS product specifically ──
  RealtimeChannel subscribeToNewFeedback(int productId, void Function() onInsert) {
    return _supabase
        .channel('feedback:product:$productId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feedback',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: productId,
          ),
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _supabase.removeChannel(channel);
  }

  // ================================================
  // FETCH PRODUCT REVIEWS
  // Returns only Visible reviews for customers.
  // ================================================
  Future<List<ReviewModel>> fetchProductReviews(int productId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('feedback')
          .select(_selectWithJoins)
          .eq('product_id', productId)
          .eq('status', 'Visible')
          .order('created_at', ascending: false);

      return response
          .map((row) => ReviewModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchProductReviews error: $error');
      return [];
    }
  }

  // ================================================
  // SUBMIT REVIEW
  // Phase 1: any logged-in customer can submit.
  // Phase 2: check for a delivered order first.
  //
  // Returns null on success, error string on failure.
  // ================================================
  Future<String?> submitReview({
    required int productId,
    required double rating,
    required String reviewText,
    List<String> imageUrls = const [],   // phase 2
  }) async {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 'You must be logged in to submit a review.';

    try {
      // Prevent duplicate reviews (one per customer per product).
      // This pre-check is still useful for the common case (instant
      // feedback without waiting on a failed insert), but it can't
      // close the race on its own — see the 23505 catch below, which
      // is what actually guarantees correctness now that the DB has
      // a unique constraint on (user_id, product_id).
      final existing = await _supabase
          .from('feedback')
          .select('feedback_id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        return 'You have already reviewed this product.';
      }

      await _supabase.from('feedback').insert({
        'user_id':         userId,
        'product_id':      productId,
        'rating':          rating.round(),
        'comment_message': reviewText.trim(),
        'image_urls':      imageUrls,
        'verified_purchase': false,        // phase 2
        'status':          'Visible',
      });
    } on PostgrestException catch (error) {
      // BUG FIX: a raced double-submit lands here once the DB unique
      // constraint is in place — return the same friendly message
      // the pre-check above gives, instead of a raw Postgres error.
      if (error.code == '23505') {
        return 'You have already reviewed this product.';
      }
      print('submitReview error: $error');
      return error.message;
    } catch (error) {
      print('submitReview error: $error');
      return error.toString();
    }

    // Fire-and-forget: notify staff. Never let a notification
    // failure make the review submission look like it failed.
    await _notifyStaffNewFeedback(
      productId: productId,
      rating: rating.round(),
    );

    return null; // success
  }

  // ================================================
  // ADD REPLY
  // Any logged-in user (staff via the admin dialog, or a
  // customer via the product page) can append a reply.
  // ================================================
  Future<String?> addReply({
    required int feedbackId,
    required String replyText,
  }) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'You must be logged in to reply.';

      final String trimmed = replyText.trim();
      if (trimmed.isEmpty) return 'Reply cannot be empty.';

      await _supabase.from('feedback_replies').insert({
        'feedback_id': feedbackId,
        'author_id':   userId,
        'reply_text':  trimmed,
      });

      // Fire-and-forget: notify staff. Never let a notification
      // failure make the reply look like it failed to post — the
      // reply itself already committed successfully above.
      // Fire-and-forget: notify staff (always) AND the original
      // reviewer, if someone other than them just replied. Neither
      // failure should make the reply look like it failed to post.
      await _notifyStaffFeedbackReply(
        feedbackId: feedbackId,
        replyText: trimmed,
      );
      await _notifyCustomerFeedbackReply(
        feedbackId: feedbackId,
        replyText: trimmed,
        replierId: userId,
      );

      return null;
    } catch (error) {
      print('addReply error: $error');
      return error.toString();
    }
  }

  // ================================================
  // NOTIFY STAFF — NEW FEEDBACK
  // Recipient: Admin + Super Admin (both have a feedback screen).
  //
  // Single RPC call — see file header for why.
  // ================================================
  Future<void> _notifyStaffNewFeedback({
    required int productId,
    required int rating,
  }) async {
    print('🔔🔔🔔 _notifyStaffNewFeedback CALLED for product #$productId 🔔🔔🔔');
    try {
      await _supabase.rpc('notify_staff_new_feedback', params: {
        'p_product_id': productId,
        'p_rating': rating,
      });
      print('🔔 Feedback RPC completed successfully');
    } catch (error) {
      print('_notifyStaffNewFeedback error: $error');
    }
  }

  // ================================================
  // NOTIFY STAFF — REPLY POSTED ON A REVIEW
  // Recipient: Admin + Super Admin — Super Admin has full feedback
  // moderation access (updateStatus, saveReply in FeedbackService),
  // so they should see reply activity too, not just new submissions.
  //
  // Single RPC call — see file header for why.
  // ================================================
  Future<void> _notifyStaffFeedbackReply({
    required int feedbackId,
    required String replyText,
  }) async {
    print('🔔🔔🔔 _notifyStaffFeedbackReply CALLED for feedback #$feedbackId 🔔🔔🔔');
    try {
      await _supabase.rpc('notify_staff_feedback_reply', params: {
        'p_feedback_id': feedbackId,
        'p_reply_text': replyText,
      });
      print('🔔 Reply RPC completed successfully');
    } catch (error) {
      print('_notifyStaffFeedbackReply error: $error');
    }
  }

  Future<void> _notifyCustomerFeedbackReply({
    required int feedbackId,
    required String replyText,
    required String replierId,
  }) async {
    try {
      await _supabase.rpc('notify_customer_feedback_reply', params: {
        'p_feedback_id': feedbackId,
        'p_reply_text': replyText,
        'p_replier_id': replierId,
      });
    } catch (error) {
      print('_notifyCustomerFeedbackReply error: $error');
    }
  }

  // ================================================
  // UPDATE REVIEW
  // Customer can edit their own review text / rating.
  // Status changes are admin-only (FeedbackService).
  // ================================================
  Future<String?> updateReview({
    required int reviewId,
    required double rating,
    required String reviewText,
  }) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not authenticated.';

      await _supabase
          .from('feedback')
          .update({
            'rating':          rating.round(),
            'comment_message': reviewText.trim(),
          })
          .eq('feedback_id', reviewId)
          .eq('user_id', userId); // safety: own row only

      return null;
    } catch (error) {
      print('updateReview error: $error');
      return error.toString();
    }
  }

  // ================================================
  // DELETE REVIEW
  // Customer can remove their own review.
  // ================================================
  Future<String?> deleteReview(int reviewId) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not authenticated.';

      await _supabase
          .from('feedback')
          .delete()
          .eq('feedback_id', reviewId)
          .eq('user_id', userId); // safety: own row only

      return null;
    } catch (error) {
      print('deleteReview error: $error');
      return error.toString();
    }
  }

  // ================================================
  // FETCH SINGLE REVIEW BY ID
  // Used internally / for edit prefill.
  // ================================================
  Future<ReviewModel?> fetchReviewById(int reviewId) async {
    try {
      final row = await _supabase
          .from('feedback')
          .select(_selectWithJoins)
          .eq('feedback_id', reviewId)
          .single();

      return ReviewModel.fromSupabase(row as Map<String, dynamic>);
    } catch (error) {
      print('fetchReviewById error: $error');
      return null;
    }
  }

  // ================================================
  // CHECK IF CURRENT USER ALREADY REVIEWED
  // Used to show / hide the "Write a Review" button.
  // ================================================
  Future<bool> hasUserReviewed(int productId) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final existing = await _supabase
          .from('feedback')
          .select('feedback_id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return existing != null;
    } catch (error) {
      print('hasUserReviewed error: $error');
      return false;
    }
  }

  // ================================================
  // COMPUTE AGGREGATE STATS FOR A PRODUCT
  // Average rating + count — used by ProductDetail header.
  // ================================================
  Future<({double average, int count})> fetchProductRatingStats(
      int productId) async {
    try {
      final List<dynamic> rows = await _supabase
          .from('feedback')
          .select('rating')
          .eq('product_id', productId)
          .eq('status', 'Visible');

      if (rows.isEmpty) return (average: 0.0, count: 0);

      final double sum = rows.fold(
        0.0,
        (acc, r) => acc + (r['rating'] as num).toDouble(),
      );

      return (average: sum / rows.length, count: rows.length);
    } catch (error) {
      print('fetchProductRatingStats error: $error');
      return (average: 0.0, count: 0);
    }
  }
}