// ================================================
// FEEDBACK SERVICE
// Admin-facing Supabase operations.
// Operates on the same `feedback` table but exposes
// ALL rows (not just Visible) and adds moderation tools.
// ================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/feedback_model.dart';

class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── SELECT helper ─────────────────────────────────────────────
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
  // FETCH ALL FEEDBACK (admin: no status filter)
  // ================================================
  Future<List<FeedbackModel>> fetchFeedback() async {
    try {
      final List<dynamic> response = await _supabase
          .from('feedback')
          .select(_selectWithJoins)
          .order('created_at', ascending: false);

      return response
          .map((row) =>
              FeedbackModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchFeedback error: $error');
      return [];
    }
  }

  // ================================================
  // FETCH BY STATUS
  // Pass null to get all statuses.
  // ================================================
  Future<List<FeedbackModel>> fetchByStatus(String? status) async {
    try {
      var query = _supabase
          .from('feedback')
          .select(_selectWithJoins);

      if (status != null) {
        query = query.eq('status', status) as dynamic;
      }

      final List<dynamic> response = await (query as dynamic)
          .order('created_at', ascending: false);

      return response
          .map((row) =>
              FeedbackModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchByStatus error: $error');
      return [];
    }
  }

  // ================================================
  // UPDATE STATUS
  // Admin changes Visible / Flagged / Hidden.
  // Also writes an audit row to feedback_moderation.
  //
  // Returns null on success, error string on failure.
  // ================================================
  Future<String?> updateStatus({
    required int feedbackId,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      final String? adminId = _supabase.auth.currentUser?.id;

      // 1. Update the main row
      await _supabase
          .from('feedback')
          .update({'status': newStatus})
          .eq('feedback_id', feedbackId);

      // 2. Write audit log
      await _supabase.from('feedback_moderation').insert({
        'review_id':  feedbackId,
        'admin_id':   adminId,
        'old_status': oldStatus,
        'new_status': newStatus,
      });

      return null;
    } catch (error) {
      print('updateStatus error: $error');
      return error.toString();
    }
  }

  // ================================================
  // SAVE REPLY
  // Admin writes a public reply to a review.
  // Also records the action in feedback_moderation.
  //
  // Pass newStatus if status also changed in the same save.
  // Returns null on success, error string on failure.
  // ================================================
  Future<String?> saveReply({
    required int feedbackId,
    required String adminReply,
    required String currentStatus,
    String? newStatus,         // pass if status changed too
  }) async {
    try {
      final String? adminId = _supabase.auth.currentUser?.id;
      final String resolvedStatus = newStatus ?? currentStatus;

      // 1. Update feedback row
      await _supabase
          .from('feedback')
          .update({
            'admin_reply': adminReply.trim().isEmpty ? null : adminReply.trim(),
            'status':      resolvedStatus,
          })
          .eq('feedback_id', feedbackId);

      // 2. Write audit log
      await _supabase.from('feedback_moderation').insert({
        'review_id':   feedbackId,
        'admin_id':    adminId,
        'old_status':  currentStatus,
        'new_status':  resolvedStatus,
        'admin_reply': adminReply.trim().isEmpty ? null : adminReply.trim(),
        'replied_at':  adminReply.trim().isNotEmpty
                         ? DateTime.now().toIso8601String()
                         : null,
      });

      return null;
    } catch (error) {
      print('saveReply error: $error');
      return error.toString();
    }
  }

  // ================================================
  // FETCH RECENT FEEDBACK
  // For the dashboard RecentFeedbackCard.
  // Returns up to [limit] most-recent rows.
  // ================================================
  Future<List<FeedbackModel>> fetchRecentFeedback({int limit = 5}) async {
    try {
      final List<dynamic> response = await _supabase
          .from('feedback')
          .select(_selectWithJoins)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map((row) =>
              FeedbackModel.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('fetchRecentFeedback error: $error');
      return [];
    }
  }

  // ================================================
  // SEARCH FEEDBACK
  // Client-side text search is handled in the provider
  // (mirrors the existing _applyFilters logic).
  // This method is kept for a future server-side FTS upgrade.
  // ================================================
  Future<List<FeedbackModel>> searchFeedback(String query) async {
    // For now, fetch all and let the provider filter.
    return fetchFeedback();
  }
}