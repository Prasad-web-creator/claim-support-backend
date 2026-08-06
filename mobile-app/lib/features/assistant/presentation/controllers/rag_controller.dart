import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/assistant/data/repositories/rag_repository.dart';

final ragControllerProvider = AsyncNotifierProvider.autoDispose<RagController, Map<String, dynamic>?>(RagController.new);

class RagController extends AsyncNotifier<Map<String, dynamic>?> {
  
  @override
  Future<Map<String, dynamic>?> build() async {
    return null;
  }

  Future<void> askQuestion({
    required String policyId,
    required String prescriptionId,
    required String question,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(ragRepositoryProvider);
      final result = await repo.queryAssistant(
        policyId: policyId,
        prescriptionId: prescriptionId,
        question: question,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

