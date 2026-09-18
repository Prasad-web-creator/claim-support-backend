import 'dart:async';

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
/// `/analysis/start-multi` returns as soon as the session exists, so the screen
/// gets a real list of policies immediately. From there the notifier polls
/// `/analysis/multi/{id}`, and every update it publishes is a state the backend
/// has actually reached — the progress shown is recorded work, never a timer.
class MultiAnalysisNotifier extends Notifier<AsyncValue<MultiAnalysisSession>> {
  /// How often the session is re-read while work is in flight.
  static const Duration _pollInterval = Duration(seconds: 2);

  /// Transient network hiccups should not kill a running analysis; only a
  /// sustained run of failures is treated as a real error.
  static const int _maxConsecutivePollFailures = 5;

  CancelToken? _cancelToken;
  MultiAnalysisParams? _params;
  bool _disposed = false;
  bool _polling = false;

  MultiAnalysisParams? get params => _params;

  @override
  AsyncValue<MultiAnalysisSession> build() {
    ref.onDispose(() {
      _disposed = true;
      _cancelToken?.cancel();
    });
    return const AsyncValue.loading();
  }

  Future<void> startAnalysis(MultiAnalysisParams params) async {
    _params = params;
    _cancelToken = CancelToken();

    developer.log(
      '[MultiAnalysis] start prescription=${params.prescriptionPath} '
      'policies=${params.policyIds.length}',
    );
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      // Returns once the session is created; the analysis itself runs on the
      // server and is followed through polling below.
      final result = await repository.startMultiAnalysis(
        params.prescriptionPath,
        params.policyIds,
        cancelToken: _cancelToken!,
      );
      if (_disposed) return;

      final session = MultiAnalysisSession.fromJson(result);
      developer.log('[MultiAnalysis] session=${session.sessionId} '
          'policies=${session.policyCount} — following progress');
      state = AsyncValue.data(session);
      unawaited(_followProgress(session.sessionId));
    } catch (e, st) {
      developer.log('[MultiAnalysis] start error: $e');
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  /// Re-read the session until the backend has no work left in flight.
  ///
  /// Each successful read replaces the state, so the UI's step counts, stage
  /// labels and per-policy statuses are always the server's real ones.
  Future<void> _followProgress(String sessionId) async {
    if (_polling || sessionId.isEmpty) return;
    _polling = true;
    var consecutiveFailures = 0;

    try {
      while (!_disposed) {
        final current = state.asData?.value;
        if (current != null && !current.isWorking) break;

        await Future<void>.delayed(_pollInterval);
        if (_disposed) break;

        try {
          final repository = ref.read(analysisRepositoryProvider);
          final result = await repository.fetchMultiAnalysis(sessionId);
          if (_disposed) break;

          consecutiveFailures = 0;
          final session = MultiAnalysisSession.fromJson(result);
          state = AsyncValue.data(session);

          if (!session.isWorking) {
            developer.log('[MultiAnalysis] session=$sessionId settled '
                'status=${session.status} '
                '${session.completedCount}/${session.policyCount} finished');
            break;
          }
        } catch (e, st) {
          consecutiveFailures++;
          developer.log('[MultiAnalysis] poll failed ($consecutiveFailures): $e');
          if (consecutiveFailures >= _maxConsecutivePollFailures) {
            // Only give up the screen entirely if there is nothing to show.
            if (state.asData?.value == null && !_disposed) {
              state = AsyncValue.error(e, st);
            }
            break;
          }
        }
      }
    } finally {
      _polling = false;
    }
  }

  /// Answer one policy's clarification questions. Other policies keep their results.
  Future<void> submitPolicyAnswers(String policyId, Map<String, dynamic> answers) async {
    final current = state.asData?.value;
    if (current == null) return;

    _cancelToken = CancelToken();
    developer.log('[MultiAnalysis] answering policy=$policyId');

    // Reflect the restart straight away, then let polling report the real
    // stages as the server works through them. The other policies' results stay
    // on screen throughout.
    state = AsyncValue.data(current.withPolicyRestarted(policyId, 'reanalyzing'));
    unawaited(_followProgress(current.sessionId));

    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.submitPolicyAnswers(
        current.sessionId,
        policyId,
        answers,
        cancelToken: _cancelToken!,
      );
      if (!_disposed) state = AsyncValue.data(MultiAnalysisSession.fromJson(result));
    } catch (e, st) {
      developer.log('[MultiAnalysis] answer error: $e');
      if (!_disposed && state.asData?.value == null) state = AsyncValue.error(e, st);
    }
  }

  /// Retry a single failed policy. Successful policies are untouched.
  Future<void> retryPolicy(String policyId) async {
    final current = state.asData?.value;
    if (current == null) return;

    _cancelToken = CancelToken();
    developer.log('[MultiAnalysis] retrying policy=$policyId');

    state = AsyncValue.data(current.withPolicyRestarted(policyId, 'queued'));
    unawaited(_followProgress(current.sessionId));

    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.retryPolicy(
        current.sessionId,
        policyId,
        cancelToken: _cancelToken!,
      );
      if (!_disposed) state = AsyncValue.data(MultiAnalysisSession.fromJson(result));
    } catch (e, st) {
      developer.log('[MultiAnalysis] retry error: $e');
      if (!_disposed && state.asData?.value == null) state = AsyncValue.error(e, st);
    }
  }

  /// Re-read the session, e.g. after the user returns to the screen.
  Future<void> refreshSession(String sessionId) async {
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.fetchMultiAnalysis(sessionId);
      if (_disposed) return;
      final session = MultiAnalysisSession.fromJson(result);
      state = AsyncValue.data(session);
      if (session.isWorking) unawaited(_followProgress(sessionId));
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
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
