// ================================================
// REVIEW SERVICE
// Customer-facing Supabase operations for the
// `feedback` table.
//
// Naming note: the table is called `feedback` in Supabase
// but the customer-facing concept is "review".
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
    )
  ''';

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
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'You must be logged in to submit a review.';

      // Prevent duplicate reviews (one per customer per product)
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

      return null; // success
    } catch (error) {
      print('submitReview error: $error');
      return error.toString();
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