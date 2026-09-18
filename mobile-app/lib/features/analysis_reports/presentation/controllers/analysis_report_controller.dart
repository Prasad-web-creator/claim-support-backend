import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

/// Drives the Coverage Analysis Reports list.
///
/// Each item is an analysis *group*: a multi-policy analysis carries all of its
/// policy results, a single-policy analysis is a group of one.
class AnalysisReportNotifier extends AsyncNotifier<PaginationResponse<AnalysisReportGroup>> {
  int _currentPage = 1;

  static const int _limit = 10;

  @override
  Future<PaginationResponse<AnalysisReportGroup>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return _fetchAnalysisReports();
  }

  Future<PaginationResponse<AnalysisReportGroup>> _fetchAnalysisReports() async {
    final repository = ref.read(analysisReportRepositoryProvider);
    return await repository.getAnalysisReportGroups(page: _currentPage, limit: _limit);
  }

  Future<void> fetchAnalysisReports({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchAnalysisReports());
  }

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _currentPage = 1;
      fetchAnalysisReports();
    });
  }

  Future<void> loadNextPage() async {
    final currentState = state.value;
    if (currentState != null && currentState.hasNextPage) {
      _currentPage++;
      try {
        final newResponse = await _fetchAnalysisReports();
        state = AsyncData(PaginationResponse(
          docs: [...currentState.docs, ...newResponse.docs],
          totalDocs: newResponse.totalDocs,
          limit: newResponse.limit,
          totalPages: newResponse.totalPages,
          page: newResponse.page,
          hasPrevPage: newResponse.hasPrevPage,
          hasNextPage: newResponse.hasNextPage,
        ));
      } catch (err, stack) {
        state = AsyncError(err, stack);
      }
    }
  }

  /// Delete one analysis group (and every report inside it).
  Future<void> deleteReport(String groupId) async {
    try {
      final repository = ref.read(analysisReportRepositoryProvider);
      await repository.deleteAnalysisGroup(groupId);
      await fetchAnalysisReports(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteReports(List<String> groupIds) async {
    if (groupIds.isEmpty) return;
    try {
      final repository = ref.read(analysisReportRepositoryProvider);
      await repository.deleteBatchAnalysisGroups(groupIds);
      await fetchAnalysisReports(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }
}

final analysisReportProvider =
    AsyncNotifierProvider.autoDispose<AnalysisReportNotifier, PaginationResponse<AnalysisReportGroup>>(() {
  return AnalysisReportNotifier();
});
