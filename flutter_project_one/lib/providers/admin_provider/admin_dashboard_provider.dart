import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/admin/dashboard/admin_dashboard_service.dart';

final adminDashboardServiceProvider = Provider<AdminDashboardService>((ref) {
  return AdminDashboardService();
});

// AutoDispose + family-less FutureProvider — refetches each time the
// screen is (re)watched after invalidation. Call
// ref.invalidate(adminDashboardDataProvider) after actions elsewhere
// (e.g. approving/rejecting an order) if you want the dashboard to
// reflect it immediately next time it's viewed.
final adminDashboardDataProvider =
    FutureProvider.autoDispose<AdminDashboardData>((ref) async {
  final service = ref.watch(adminDashboardServiceProvider);
  return service.getDashboardData();
});