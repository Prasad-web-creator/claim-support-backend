import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/dashboard/data/models/dashboard_stats.dart';

final dashboardStatsProvider = AsyncNotifierProvider.autoDispose<DashboardStatsNotifier, DashboardStats>(() {
  return DashboardStatsNotifier();
});

class DashboardStatsNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    return _fetchStats();
  }

  Future<DashboardStats> _fetchStats() async {
    final repository = ref.read(dashboardRepositoryProvider);
    return await repository.getStats();
  }

  Future<void> fetchStats() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchStats());
  }
}
