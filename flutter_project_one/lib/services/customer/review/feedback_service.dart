// ================================================
// FEEDBACK SERVICE
// Admin-facing Supabase operations.
// Operates on the same `feedback` table but exposes
// ALL rows (not just Visible) and adds moderation tools.
//
// BUG FIX this round — saveReply():
//   The activity-log branch was `if (reply) {...} else if (status
//   changed) {...}`, so a save that included BOTH a new reply AND
//   a status change only ever logged the reply — the status change
//   was silently dropped from the human-readable Activity Log feed
//   (the feedback_moderation audit table still had both, so nothing
//   was lost functionally, just under-reported in the log). The two
//   conditions are now independent `if` blocks so both log entries
//   fire when both things happened.
// ================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/feedback_model.dart';
import '../../super/activity_log/activity_log_service.dart';

class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

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
  // Fetch a lightweight label (product name + reviewer)
  // for the log entry, so Super Admin sees "review of
  // Nike Air Force One by Angel Tuazon" rather than a
  // bare feedback ID.
  // ================================================
  Future<String> _labelForFeedback(int feedbackId) async {
    try {
      final row = await _supabase
          .from('feedback')
          .select('product(product_name), users(first_name, last_name)')
          .eq('feedback_id', feedbackId)
          .single();

      final productName =
          row['product']?['product_name']?.toString() ?? 'a product';
      final firstName = row['users']?['first_name']?.toString() ?? '';
      final lastName = row['users']?['last_name']?.toString() ?? '';
      final reviewer = '$firstName $lastName'.trim();

      return reviewer.isNotEmpty
          ? 'review of $productName by $reviewer'
          : 'review of $productName';
    } catch (_) {
      return 'review #$feedbackId';
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

      // 2. Write audit log (feedback_moderation table)
      await _supabase.from('feedback_moderation').insert({
        'review_id':  feedbackId,
        'admin_id':   adminId,
        'old_status': oldStatus,
        'new_status': newStatus,
      });

      // 3. Write to the global Activity Log too, so Super Admin
      // sees this alongside every other module.
      final label = await _labelForFeedback(feedbackId);
      await _activityLog.log(
        action: 'Changed status of $label from $oldStatus to $newStatus',
        affectedModule: AffectedModule.feedback,
        targetId: feedbackId.toString(),
        metadata: {
          'old_status': oldStatus,
          'new_status': newStatus,
        },
      );

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
      final String trimmedReply = adminReply.trim();
      final bool statusChanged = resolvedStatus != currentStatus;

      // 1. Update feedback row
      await _supabase
          .from('feedback')
          .update({
            'admin_reply': trimmedReply.isEmpty ? null : trimmedReply,
            'status':      resolvedStatus,
          })
          .eq('feedback_id', feedbackId);

      // 2. Write audit log (feedback_moderation table)
      await _supabase.from('feedback_moderation').insert({
        'review_id':   feedbackId,
        'admin_id':    adminId,
        'old_status':  currentStatus,
        'new_status':  resolvedStatus,
        'admin_reply': trimmedReply.isEmpty ? null : trimmedReply,
        'replied_at':  trimmedReply.isNotEmpty
                         ? DateTime.now().toIso8601String()
                         : null,
      });

      // 2b. Append to the public reply thread (feedback_replies).
      // This is additive — feedback.admin_reply above still holds
      // the latest reply for any older code reading that single
      // field, while feedback_replies is the new full thread.
      if (trimmedReply.isNotEmpty) {
        await _supabase.from('feedback_replies').insert({
          'feedback_id': feedbackId,
          'author_id':   adminId,
          'reply_text':  trimmedReply,
        });
      }

      // 3. Write to the global Activity Log.
      // BUG FIX: these are now independent `if` blocks instead of
      // if/else-if, so a save that both replies AND changes status
      // logs BOTH entries instead of only the reply.
      final String label = (trimmedReply.isNotEmpty || statusChanged)
          ? await _labelForFeedback(feedbackId)
          : '';

      if (trimmedReply.isNotEmpty) {
        final preview = trimmedReply.length > 80
            ? '${trimmedReply.substring(0, 80)}...'
            : trimmedReply;

        await _activityLog.log(
          action: 'Replied to $label: "$preview"',
          affectedModule: AffectedModule.feedback,
          targetId: feedbackId.toString(),
          metadata: {
            'admin_reply': trimmedReply,
            'status': resolvedStatus,
          },
        );
      }

      if (statusChanged) {
        await _activityLog.log(
          action:
              'Changed status of $label from $currentStatus to $resolvedStatus',
          affectedModule: AffectedModule.feedback,
          targetId: feedbackId.toString(),
          metadata: {
            'old_status': currentStatus,
            'new_status': resolvedStatus,
          },
        );
      }

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