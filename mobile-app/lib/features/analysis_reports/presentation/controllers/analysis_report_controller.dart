import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

class AnalysisReportNotifier extends AsyncNotifier<PaginationResponse<AnalysisReport>> {
  int _currentPage = 1;
  String _currentSearch = '';

  static const int _limit = 10;

  @override
  Future<PaginationResponse<AnalysisReport>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return _fetchAnalysisReports();
  }

  Future<PaginationResponse<AnalysisReport>> _fetchAnalysisReports() async {
    final repository = ref.read(analysisReportRepositoryProvider);
    return await repository.getAnalysisReports(page: _currentPage, limit: _limit, search: _currentSearch);
  }

  Future<void> fetchAnalysisReports({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchAnalysisReports());
    } else {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchAnalysisReports());
    }
  }

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _currentSearch = query;
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
}

final analysisReportProvider = AsyncNotifierProvider<AnalysisReportNotifier, PaginationResponse<AnalysisReport>>(() {
  return AnalysisReportNotifier();
});
