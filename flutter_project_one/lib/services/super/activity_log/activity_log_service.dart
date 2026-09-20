import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// ACTIVITY LOG SERVICE
//
// Generic, reusable logger for admin/staff actions.
// Call `.log(...)` from any service after a write
// action succeeds (create/update/disable/etc).
//
// Usage:
//   await ActivityLogService().log(
//     action: 'Disabled customer account of Jay Galang',
//     affectedModule: 'Customer Management',
//     targetId: customerId,
//     metadata: {'reason': reason},
//   );
// ================================================

class AffectedModule {
  static const adminManagement = 'Admin Management';
  static const customerManagement = 'Customer Management';
  static const inventory = 'Inventory';
  static const orders = 'Orders';
  static const promotions = 'Promotions';
  static const feedback = 'Feedback Moderation';
  static const sales = 'Sales';
}

class ActivityLogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> log({
    required String action,
    required String affectedModule,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('ActivityLogService: no logged-in user, skipping log');
        return;
      }

      // fetch the acting user's name + role for the denormalized snapshot
      final profile = await _supabase
          .from('users')
          .select('first_name, last_name, role')
          .eq('id', currentUser.id)
          .single();

      final adminName =
          '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
      final role = profile['role'] as String? ?? 'Unknown';

            await _supabase.from('activity_log').insert({
        'admin_id': currentUser.id,
        'admin_name': adminName.isEmpty ? 'Unknown' : adminName,
        'role': role,
        'action': action,
        'affected_module': affectedModule,
        'target_id': targetId,
        'metadata': metadata,
      });
    } catch (error) {
      // Logging should never break the actual operation it's attached to.
      print('ActivityLogService error: $error');
    }
  }

  // ================================================
  // GET LOGS
  // Used by the Activity Log screen.
  // ================================================
  Future<List<Map<String, dynamic>>> getLogs({
    String? moduleFilter,
    int limit = 100,
  }) async {
    var query = _supabase.from('activity_log').select();

    if (moduleFilter != null) {
      query = query.eq('affected_module', moduleFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }
}