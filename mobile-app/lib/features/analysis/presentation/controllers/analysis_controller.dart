import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';

final analysisRepositoryProvider = Provider((ref) => AnalysisRepository());

class AnalysisParams {
  final String prescriptionPath;
  final String? policyPath;
  final String? policyId;
  AnalysisParams({required this.prescriptionPath, this.policyPath, this.policyId});
  
  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is AnalysisParams && prescriptionPath == other.prescriptionPath && policyPath == other.policyPath && policyId == other.policyId;
  @override
  int get hashCode => prescriptionPath.hashCode ^ policyPath.hashCode ^ policyId.hashCode;
}

class AnalysisNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  CancelToken? _cancelToken;
  AnalysisParams? _params;

  AnalysisParams? get params => _params;

  @override
  AsyncValue<Map<String, dynamic>> build() {
    return const AsyncValue.loading();
  }

  Future<void> startAnalysis(AnalysisParams params) async {
    _params = params;
    _cancelToken = CancelToken();
    ref.onDispose(() => _cancelToken?.cancel());

    developer.log('[AnalysisNotifier] startAnalysis called. prescription=${params.prescriptionPath}');
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.startAnalysis(
        params.prescriptionPath,
        policyPath: params.policyPath,
        policyId: params.policyId,
        cancelToken: _cancelToken!,
      );
      developer.log('[AnalysisNotifier] startAnalysis success. status=${result['status']}');
      state = AsyncValue.data(result);
    } catch (e, st) {
      developer.log('[AnalysisNotifier] startAnalysis error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submitAnswers(String sessionId, Map<String, dynamic> answers) async {
    developer.log('[AnalysisNotifier] submitAnswers called. sessionId=$sessionId, answers=$answers');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(analysisRepositoryProvider);
      final result = await repository.submitAnswers(
        sessionId,
        answers,
        cancelToken: _cancelToken!,
      );
      developer.log('[AnalysisNotifier] submitAnswers success. status=${result['status']}');
      state = AsyncValue.data(result);
    } catch (e, st) {
      developer.log('[AnalysisNotifier] submitAnswers error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  void cancelAnalysis() {
    developer.log('[AnalysisNotifier] cancelAnalysis called.');
    _cancelToken?.cancel('User cancelled the analysis');
    state = const AsyncValue.loading(); // Reset to clean state
  }
}

final analysisJobProvider = NotifierProvider.autoDispose<AnalysisNotifier, AsyncValue<Map<String, dynamic>>>(
  AnalysisNotifier.new
);
