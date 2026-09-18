import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AnalysisRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> startAnalysis(String prescriptionPath, {String? policyPath, String? policyId, required CancelToken cancelToken}) async {
    try {
      final Map<String, dynamic> requestData = {
        'prescriptionPath': prescriptionPath,
      };
      if (policyPath != null) requestData['policyPath'] = policyPath;
      if (policyId != null) requestData['policyId'] = policyId;

      final response = await _dio.post(
        '/analysis/start',
        data: requestData,
        cancelToken: cancelToken,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(message: 'Analysis failed: Unexpected status code ${response.statusCode}');
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Analysis cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Analysis failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(message: 'Failed to start analysis: $e', originalException: e, stackTrace: st);
    }
  }

  /// Analyze one prescription against several policies in a single session.
  Future<Map<String, dynamic>> startMultiAnalysis(
    String prescriptionPath,
    List<String> policyIds, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/start-multi',
        data: {
          'prescriptionPath': prescriptionPath,
          'policyIds': policyIds,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(message: 'Analysis failed: Unexpected status code ${response.statusCode}');
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Analysis cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? e.response?.data?['message'] ?? 'Analysis failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(message: 'Failed to start analysis: $e', originalException: e, stackTrace: st);
    }
  }

  /// Current state of a multi-policy session (safe to call repeatedly).
  Future<Map<String, dynamic>> fetchMultiAnalysis(String sessionId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get('/analysis/multi/$sessionId', cancelToken: cancelToken);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Failed to load analysis',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Answer clarification questions for ONE policy of a multi-policy session.
  Future<Map<String, dynamic>> submitPolicyAnswers(
    String sessionId,
    String policyId,
    Map<String, dynamic> answers, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/multi/$sessionId/$policyId/answer',
        data: {'answers': answers},
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Submission cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Submission failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  /// Retry a single failed policy without re-running the others.
  Future<Map<String, dynamic>> retryPolicy(
    String sessionId,
    String policyId, {
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/analysis/multi/$sessionId/$policyId/retry',
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['detail'] ?? 'Retry failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Map<String, dynamic>> submitAnswers(String sessionId, Map<String, dynamic> answers, {required CancelToken cancelToken}) async {
    try {
      final response = await _dio.post(
        '/analysis/$sessionId/answer',
        data: {'answers': answers},
        cancelToken: cancelToken,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(message: 'Submission failed: Unexpected status code ${response.statusCode}');
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Submission cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Submission failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(message: 'Failed to submit answers: $e', originalException: e, stackTrace: st);
    }
  }
}
