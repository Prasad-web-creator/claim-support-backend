import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

final policiesProvider = AsyncNotifierProvider.autoDispose<PoliciesNotifier, PaginationResponse<Policy>>(() {
  return PoliciesNotifier();
});

class PoliciesNotifier extends AsyncNotifier<PaginationResponse<Policy>> {
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _limit = 10;

  @override
  Future<PaginationResponse<Policy>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return _fetchPolicies();
  }

  Future<PaginationResponse<Policy>> _fetchPolicies() async {
    final repository = ref.read(policyRepositoryProvider);
    return await repository.getPolicies(page: _currentPage, limit: _limit, search: _searchQuery);
  }

  Future<void> fetchPolicies({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchPolicies());
    } else {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchPolicies());
    }
  }

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query;
      _currentPage = 1;
      fetchPolicies();
    });
  }

  Future<void> loadNextPage() async {
    final currentState = state.value;
    if (currentState != null && currentState.hasNextPage) {
      _currentPage++;
      try {
        final newResponse = await _fetchPolicies();
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

  Future<void> deletePolicy(String id) async {
    try {
      final repository = ref.read(policyRepositoryProvider);
      await repository.deletePolicy(id);
      fetchPolicies(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePolicies(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final repository = ref.read(policyRepositoryProvider);
      await repository.deleteBatchPolicies(ids);
      fetchPolicies(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }
}
