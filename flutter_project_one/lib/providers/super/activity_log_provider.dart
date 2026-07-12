import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/super/activity_log/activity_log_service.dart';

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  return ActivityLogService();
});

final activityLogsProvider =
    NotifierProvider<ActivityLogNotifier, List<Map<String, dynamic>>>(
  ActivityLogNotifier.new,
);

class ActivityLogNotifier extends Notifier<List<Map<String, dynamic>>> {
  late final ActivityLogService _service;

  @override
  List<Map<String, dynamic>> build() {
    _service = ref.read(activityLogServiceProvider);
    return [];
  }

  Future<void> loadLogs({String? moduleFilter}) async {
    state = await _service.getLogs(moduleFilter: moduleFilter);
  }
}