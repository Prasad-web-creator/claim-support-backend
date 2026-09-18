import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/analysis_controller.dart';

class MultiAnalysisParams {
  final String prescriptionPath;
  final List<String> policyIds;

  MultiAnalysisParams({required this.prescriptionPath, required this.policyIds});
}

/// Drives a multi-policy analysis: start, per-policy clarification, per-policy retry.
///
/// The backend answers with the full session state on every call, so the
/// notifier simply replaces its state with the latest snapshot.
class MultiAnalysisNotifier extends Notifier<AsyncValue<MultiAnalysisSession>> {
  CancelToken? _cancelToken;
  MultiAnalysisParams? _params;

  MultiAnalysisParams? get params => _params;

  @override
  AsyncValue<MultiAnalysisSession> build() => const AsyncValue.loading();

  Future<void> startAnalysis(MultiAnalysisParams params) async {
    _params = params;
    _cancelToken = CancelToken();
    ref.onDispose(() => _cancelToken?.cancel());

    developer.log(
      '[MultiAnalysis] start prescription=${params.prescriptionPath} '
      'policies=${params.policyIds.length}',
    );
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.startMultiAnalysis(
        params.prescriptionPath,
        params.policyIds,
        cancelToken: _cancelToken!,
      );
      final session = MultiAnalysisSession.fromJson(result);
      developer.log('[MultiAnalysis] status=${session.status} '
          'settled=${session.completedCount}/${session.policyCount}');
      state = AsyncValue.data(session);
    } catch (e, st) {
      developer.log('[MultiAnalysis] start error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Answer one policy's clarification questions. Other policies keep their results.
  Future<void> submitPolicyAnswers(String policyId, Map<String, dynamic> answers) async {
    final current = state.asData?.value;
    if (current == null) return;

    _cancelToken = CancelToken();
    developer.log('[MultiAnalysis] answering policy=$policyId');
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.submitPolicyAnswers(
        current.sessionId,
        policyId,
        answers,
        cancelToken: _cancelToken!,
      );
      state = AsyncValue.data(MultiAnalysisSession.fromJson(result));
    } catch (e, st) {
      developer.log('[MultiAnalysis] answer error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Retry a single failed policy. Successful policies are untouched.
  Future<void> retryPolicy(String policyId) async {
    final current = state.asData?.value;
    if (current == null) return;

    _cancelToken = CancelToken();
    developer.log('[MultiAnalysis] retrying policy=$policyId');
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.retryPolicy(
        current.sessionId,
        policyId,
        cancelToken: _cancelToken!,
      );
      state = AsyncValue.data(MultiAnalysisSession.fromJson(result));
    } catch (e, st) {
      developer.log('[MultiAnalysis] retry error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Re-read the session, e.g. after the user returns to the screen.
  Future<void> refreshSession(String sessionId) async {
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.fetchMultiAnalysis(sessionId);
      state = AsyncValue.data(MultiAnalysisSession.fromJson(result));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void cancelAnalysis() {
    developer.log('[MultiAnalysis] cancelled by user');
    _cancelToken?.cancel('User cancelled the analysis');
    state = const AsyncValue.loading();
  }
}

final multiAnalysisJobProvider =
    NotifierProvider.autoDispose<MultiAnalysisNotifier, AsyncValue<MultiAnalysisSession>>(
  MultiAnalysisNotifier.new,
);
