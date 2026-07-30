import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/features/analysis/data/repositories/analysis_repository.dart';

final analysisRepositoryProvider = Provider((ref) => AnalysisRepository());

// Parameters for the analysis request
class AnalysisParams {
  final String prescriptionPath;
  final String policyPath;
  AnalysisParams(this.prescriptionPath, this.policyPath);
  
  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is AnalysisParams && prescriptionPath == other.prescriptionPath && policyPath == other.policyPath;
  @override
  int get hashCode => prescriptionPath.hashCode ^ policyPath.hashCode;
}

// Uses autoDispose but keeps alive on success
final analysisJobProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, AnalysisParams>((ref, params) async {
  final repository = ref.read(analysisRepositoryProvider);
  final cancelToken = CancelToken();
  
  ref.onDispose(() {
    cancelToken.cancel("Provider disposed");
  });

  final result = await repository.startAnalysis(params.prescriptionPath, params.policyPath, cancelToken);
  
  // If successful, keep the result cached so navigating away and back doesn't re-trigger.
  ref.keepAlive();
  return result;
});
