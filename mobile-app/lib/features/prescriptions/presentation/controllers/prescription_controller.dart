import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/providers.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/core/models/pagination_response.dart';

class PrescriptionNotifier extends AsyncNotifier<PaginationResponse<Prescription>> {
  int _currentPage = 1;
  String _currentSearch = '';

  static const int _limit = 10;

  @override
  Future<PaginationResponse<Prescription>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return _fetchPrescriptions();
  }

  Future<PaginationResponse<Prescription>> _fetchPrescriptions() async {
    final repository = ref.read(prescriptionRepositoryProvider);
    return await repository.getPrescriptions(page: _currentPage, limit: _limit, search: _currentSearch);
  }

  Future<void> fetchPrescriptions({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchPrescriptions());
    } else {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchPrescriptions());
    }
  }

  Timer? _debounceTimer;

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _currentSearch = query;
      _currentPage = 1;
      fetchPrescriptions();
    });
  }

  Future<void> loadNextPage() async {
    final currentState = state.value;
    if (currentState != null && currentState.hasNextPage) {
      _currentPage++;
      try {
        final newResponse = await _fetchPrescriptions();
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

  Future<void> createPrescription(Map<String, dynamic> data) async {
    final repository = ref.read(prescriptionRepositoryProvider);
    await repository.createPrescription(data);
    await fetchPrescriptions(isRefresh: true);
  }
  Future<void> deletePrescription(String id) async {
    try {
      final repository = ref.read(prescriptionRepositoryProvider);
      await repository.deletePrescription(id);
      await fetchPrescriptions(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }
}

final prescriptionProvider = AsyncNotifierProvider<PrescriptionNotifier, PaginationResponse<Prescription>>(() {
  return PrescriptionNotifier();
});
