import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ragRepositoryProvider = Provider<RagRepository>((ref) => RagRepository());

class RagRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> queryAssistant({
    required String policyId,
    required String prescriptionId,
    required String question,
  }) async {
    try {
      final response = await _dio.post('/rag/query', data: {
        'policyId': policyId,
        'prescriptionId': prescriptionId,
        'question': question,
      });
      return response.data;
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to query AI Assistant: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
