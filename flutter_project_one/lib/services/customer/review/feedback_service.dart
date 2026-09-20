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


  // Persistent broadcast channel — used to notify customer screens
  // when a review's status changes, since Realtime's normal
  // postgres_changes events are silently dropped for UPDATEs that
  // move a row OUT of what the subscriber's RLS policy allows them
  // to see (e.g. Visible -> Hidden). Broadcast isn't RLS-filtered,
  // so it works for exactly this "row becomes invisible" case.
  RealtimeChannel? _statusBroadcastChannel;

  RealtimeChannel _ensureStatusBroadcastChannel() {
    _statusBroadcastChannel ??= _supabase.channel('feedback_status_broadcast')
      ..subscribe();
    return _statusBroadcastChannel!;
  }

  Future<void> _broadcastStatusChange(int feedbackId) async {
    try {
      await _ensureStatusBroadcastChannel().sendBroadcastMessage(
        event: 'status_changed',
        payload: {'feedback_id': feedbackId},
      );
    } catch (error) {
      print('_broadcastStatusChange error: $error');
    }
  }

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
        user_public_profile (
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
      user_public_profile (
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
  // SAVE REPLY
  // Admin writes a public reply to a review. Status can no longer
  // be changed here — moderation-by-hiding was intentionally
  // removed so a review can't be suppressed just for being negative.
  // The status column itself is left alone in the DB (unused, not
  // dropped), and feedback_moderation's old_status/new_status audit
  // columns are still populated (with the same, unchanged value) so
  // that table's schema doesn't need touching either.
  //
  // Returns null on success, error string on failure.
  // ================================================
  Future<String?> saveReply({
    required int feedbackId,
    required String adminReply,
  }) async {
    try {
      final String trimmedReply = adminReply.trim();
      if (trimmedReply.isEmpty) return null; // nothing to save

      final String? adminId = _supabase.auth.currentUser?.id;

      // Current status is only read to satisfy feedback_moderation's
      // audit columns — it's never changed.
      final row = await _supabase
          .from('feedback')
          .select('status')
          .eq('feedback_id', feedbackId)
          .single();
      final String currentStatus = row['status'] as String? ?? 'Visible';

      // 1. Update feedback row (reply text only)
      await _supabase
          .from('feedback')
          .update({'admin_reply': trimmedReply})
          .eq('feedback_id', feedbackId);

      // 2. Write audit log (feedback_moderation table)
      await _supabase.from('feedback_moderation').insert({
        'review_id':   feedbackId,
        'admin_id':    adminId,
        'old_status':  currentStatus,
        'new_status':  currentStatus,
        'admin_reply': trimmedReply,
        'replied_at':  DateTime.now().toIso8601String(),
      });

      // 3. Append to the public reply thread (feedback_replies).
      if (adminId != null) {
        try {
          await _supabase.from('feedback_replies').insert({
            'feedback_id': feedbackId,
            'author_id':   adminId,
            'reply_text':  trimmedReply,
          });
        } catch (insertError) {
          print('saveReply: feedback_replies insert failed: $insertError');
        }

        try {
          await _supabase.rpc('notify_customer_feedback_reply', params: {
            'p_feedback_id': feedbackId,
            'p_reply_text': trimmedReply,
            'p_replier_id': adminId,
          });
        } catch (notifyError) {
          print('saveReply: customer notification failed: $notifyError');
        }
      }

      // 4. Global Activity Log entry.
      final String label = await _labelForFeedback(feedbackId);
      final String preview = trimmedReply.length > 80
          ? '${trimmedReply.substring(0, 80)}...'
          : trimmedReply;

      await _activityLog.log(
        action: 'Replied to $label: "$preview"',
        affectedModule: AffectedModule.feedback,
        targetId: feedbackId.toString(),
        metadata: {'admin_reply': trimmedReply},
      );

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

    // ── Realtime: any change to feedback or feedback_replies ────────
  // Broad on purpose — Feedback Management shows every status, and
  // a reply from ANY source (customer, other customer, admin) should
  // refresh the list for every admin currently viewing it, not just
  // whoever happened to submit the change.
  RealtimeChannel subscribeToFeedbackChanges(void Function() onChange) {
  return _supabase
      .channel('admin_feedback_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'feedback',
                callback: (payload) {
          onChange();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'feedback',
               callback: (payload) {
          onChange();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'feedback_replies',
        callback: (payload) {
          onChange();
        },
      )
      .subscribe();}

void unsubscribe(RealtimeChannel channel) {
  _supabase.removeChannel(channel);
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